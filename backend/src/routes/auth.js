const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { signToken, requireAuth } = require('../middleware/auth');
const custody = require('../services/custody');
const config = require('../config');
const email = require('../services/email');

const router = express.Router();

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function normalizePhone(phone) {
  return String(phone || '').trim();
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function accountNumber(userId) {
  return `KF${String(userId).replace(/-/g, '').slice(0, 12).toUpperCase()}`;
}

/**
 * Sends the email OTP and only persists it once delivery succeeds. Never
 * throws — a Resend/domain failure must not take down signup or login,
 * since the account (or the login attempt) is otherwise valid; callers get
 * back `sent: false` plus the reason and can surface or retry it.
 */
async function createAndSendEmailOtp(userId, cleanEmail, fullName, purpose = 'email_verify') {
  if (!config.resendApiKey) {
    return { sent: false, warning: 'RESEND_API_KEY not configured' };
  }
  const code = email.generateOtp();
  const expiresAt = new Date(Date.now() + config.emailOtpTtlMinutes * 60 * 1000);
  try {
    await email.sendEmailOtp({ to: cleanEmail, code, name: fullName });
  } catch (err) {
    return { sent: false, warning: err.message || 'Email delivery failed' };
  }
  await pool.query(
    `INSERT INTO email_otps (user_id, email, code_hash, purpose, expires_at)
     VALUES ($1,$2,$3,$4,$5)`,
    [userId, cleanEmail, email.hashCode(code), purpose, expiresAt],
  );
  return { sent: true, expiresInMinutes: config.emailOtpTtlMinutes };
}

/** POST /auth/signup { fullName, email, phone } — sign-in is email + code, no password. */
router.post('/signup', async (req, res, next) => {
  try {
    const { fullName, email, phone } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const cleanPhone = normalizePhone(phone);

    if (!fullName || !cleanEmail || !cleanPhone) {
      return res.status(400).json({
        error: 'fullName, email and phone are required',
      });
    }

    if (!isEmail(cleanEmail)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }

    const existing = await pool.query(
      'SELECT email, phone FROM users WHERE LOWER(email) = LOWER($1) OR phone = $2',
      [cleanEmail, cleanPhone],
    );
    if (existing.rows.length > 0) {
      const row = existing.rows[0];
      const field = row.email && row.email.toLowerCase() === cleanEmail ? 'email' : 'phone';
      return res.status(409).json({ error: `An account with this ${field} already exists` });
    }

    const inserted = await pool.query(
      `INSERT INTO users (full_name, email, phone)
       VALUES ($1,$2,$3) RETURNING id, wallet_index`,
      [String(fullName).trim(), cleanEmail, cleanPhone],
    );
    const user = inserted.rows[0];

    // Provision the custodial wallet at signup — the roadmap promise:
    // one signup ⇒ crypto wallet + domestic wallet + bank account.
    const ethAddress = custody.addressFor(user.wallet_index);
    await pool.query('UPDATE users SET eth_address = $1 WHERE id = $2', [ethAddress, user.id]);
    await pool.query(
      `INSERT INTO virtual_accounts (user_id, account_name, account_number, currency)
       VALUES ($1,$2,$3,'USD')
       ON CONFLICT (account_number) DO NOTHING`,
      [user.id, String(fullName).trim(), accountNumber(user.id)],
    );
    const emailVerification = await createAndSendEmailOtp(user.id, cleanEmail, fullName);

    res.status(201).json({
      token: signToken(user.id),
      ethAddress,
      emailVerification,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/login { email, password } — legacy path, kept only for accounts
 * that still carry a password_hash from before sign-in switched to email
 * codes. New accounts have no password_hash, so this always rejects them.
 */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const result = await pool.query(
      'SELECT id, password_hash FROM users WHERE LOWER(email) = LOWER($1)',
      [cleanEmail],
    );
    if (result.rows.length === 0 || !result.rows[0].password_hash) {
      return res.status(401).json({ error: 'Incorrect email or password' });
    }
    const ok = await bcrypt.compare(String(password || ''), result.rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: 'Incorrect email or password' });
    res.json({ token: signToken(result.rows[0].id) });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/login/request-otp { email } — sends a 6-digit sign-in code. */
router.post('/login/request-otp', async (req, res, next) => {
  try {
    const cleanEmail = normalizeEmail(req.body?.email);
    if (!isEmail(cleanEmail)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }

    const user = (
      await pool.query('SELECT id, full_name FROM users WHERE LOWER(email) = LOWER($1)', [
        cleanEmail,
      ])
    ).rows[0];
    if (!user) {
      return res.status(404).json({ error: 'No account found with this email' });
    }

    const result = await createAndSendEmailOtp(user.id, cleanEmail, user.full_name, 'login');
    if (!result.sent) return res.status(503).json(result);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/** POST /auth/login/verify-otp { email, code } — exchanges a sign-in code for a session. */
router.post('/login/verify-otp', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const cleanEmail = normalizeEmail(req.body?.email);
    const code = String(req.body?.code || '').trim();
    if (!isEmail(cleanEmail) || !/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: 'Enter the email and 6-digit code' });
    }

    await client.query('BEGIN');
    const user = (
      await client.query('SELECT id FROM users WHERE LOWER(email) = LOWER($1) FOR UPDATE', [
        cleanEmail,
      ])
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No account found with this email' });
    }

    const otp = (
      await client.query(
        `SELECT id, code_hash, attempts, expires_at
           FROM email_otps
          WHERE user_id = $1
            AND LOWER(email) = LOWER($2)
            AND purpose = 'login'
            AND consumed_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1
          FOR UPDATE`,
        [user.id, cleanEmail],
      )
    ).rows[0];
    if (!otp) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No active code. Request a new one.' });
    }
    if (new Date(otp.expires_at).getTime() < Date.now()) {
      await client.query('ROLLBACK');
      return res.status(410).json({ error: 'Code has expired. Request a new one.' });
    }
    if (Number(otp.attempts) >= 5) {
      await client.query('ROLLBACK');
      return res.status(429).json({ error: 'Too many attempts. Request a new code.' });
    }

    const ok = email.hashCode(code) === otp.code_hash;
    if (!ok) {
      await client.query('UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
      await client.query('COMMIT');
      return res.status(400).json({ error: 'Incorrect code' });
    }

    await client.query('UPDATE email_otps SET consumed_at = now() WHERE id = $1', [otp.id]);
    await client.query('UPDATE users SET email_verified = TRUE WHERE id = $1', [user.id]);
    await client.query('COMMIT');
    res.json({ token: signToken(user.id) });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /auth/verify-phone { code } — sandbox: any 6 digits pass. */
router.post('/verify-phone', requireAuth, async (req, res, next) => {
  try {
    const { code } = req.body || {};
    if (!/^\d{6}$/.test(String(code || ''))) {
      return res.status(400).json({ error: 'Enter the 6-digit code' });
    }
    await pool.query('UPDATE users SET phone_verified = TRUE WHERE id = $1', [req.userId]);
    res.json({ verified: true });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/request-email-otp - sends a 6-digit email verification code. */
router.post('/request-email-otp', requireAuth, async (req, res, next) => {
  try {
    const user = (
      await pool.query('SELECT id, full_name, email, email_verified FROM users WHERE id = $1', [
        req.userId,
      ])
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.email_verified) return res.json({ sent: false, verified: true });

    const result = await createAndSendEmailOtp(user.id, user.email, user.full_name);
    if (!result.sent) return res.status(503).json(result);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/** POST /auth/verify-email { code } - verifies the latest unconsumed email OTP. */
router.post('/verify-email', requireAuth, async (req, res, next) => {
  const client = await pool.connect();
  try {
    const code = String(req.body?.code || '').trim();
    if (!/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: 'Enter the 6-digit email code' });
    }

    await client.query('BEGIN');
    const user = (
      await client.query('SELECT id, email FROM users WHERE id = $1 FOR UPDATE', [req.userId])
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }

    const otp = (
      await client.query(
        `SELECT id, code_hash, attempts, expires_at
           FROM email_otps
          WHERE user_id = $1
            AND LOWER(email) = LOWER($2)
            AND purpose = 'email_verify'
            AND consumed_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1
          FOR UPDATE`,
        [req.userId, user.email],
      )
    ).rows[0];
    if (!otp) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No active email code. Request a new one.' });
    }
    if (new Date(otp.expires_at).getTime() < Date.now()) {
      await client.query('ROLLBACK');
      return res.status(410).json({ error: 'Email code has expired' });
    }
    if (Number(otp.attempts) >= 5) {
      await client.query('ROLLBACK');
      return res.status(429).json({ error: 'Too many attempts. Request a new code.' });
    }

    const ok = email.hashCode(code) === otp.code_hash;
    if (!ok) {
      await client.query('UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
      await client.query('COMMIT');
      return res.status(400).json({ error: 'Incorrect email code' });
    }

    await client.query('UPDATE email_otps SET consumed_at = now() WHERE id = $1', [otp.id]);
    await client.query('UPDATE users SET email_verified = TRUE WHERE id = $1', [req.userId]);
    await client.query('COMMIT');
    res.json({ verified: true });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /auth/kyc — sandbox approval; raises tier immediately. */
router.post('/kyc', requireAuth, async (req, res, next) => {
  try {
    await pool.query('UPDATE users SET kyc_tier = 2 WHERE id = $1', [req.userId]);
    res.json({ kycTier: 2 });
  } catch (err) {
    next(err);
  }
});

/** GET /auth/me */
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT id, full_name, email, phone, kyc_tier, phone_verified, eth_address,
              usd_balance, kes_balance, role, email_verified, created_at
         FROM users WHERE id = $1`,
      [req.userId],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
