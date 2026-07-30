const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { signToken, requireAuth } = require('../middleware/auth');
const custody = require('../services/custody');
const config = require('../config');
const email = require('../services/email');
const { creditAgentCommission } = require('../services/commission');

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
  return `WY${String(userId).replace(/-/g, '').slice(0, 12).toUpperCase()}`;
}

/**
 * Records a login/logout event for the admin sessions dashboard. Best-effort
 * — never lets a logging failure block the actual sign-in/out it's
 * recording, so this always runs fire-and-forget from the caller's
 * perspective (no `await` needed, but callers do await it since the insert
 * itself is fast and this keeps errors from becoming unhandled rejections).
 */
async function logLoginEvent(userId, eventType, method, req) {
  try {
    await pool.query(
      `INSERT INTO login_events (user_id, event_type, method, ip_address, user_agent)
       VALUES ($1,$2,$3,$4,$5)`,
      [
        userId,
        eventType,
        method,
        req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || null,
        req.headers['user-agent'] || null,
      ],
    );
  } catch (_) {
    // Never block a real login/logout over a logging failure.
  }
}

/**
 * Verifies a Telegram Mini App `initData` payload per Telegram's documented
 * algorithm (https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app):
 * HMAC-SHA256 the sorted "key=value" pairs (everything but `hash`) using a
 * secret derived from the bot token, and compare. Also rejects stale data
 * (a replayed initData string older than 24h) and returns the parsed
 * Telegram user object on success, or null on any failure.
 */
function verifyTelegramInitData(initData) {
  if (!config.telegramBotToken || !initData) return null;
  try {
    const params = new URLSearchParams(initData);
    const hash = params.get('hash');
    if (!hash) return null;
    params.delete('hash');

    const dataCheckString = Array.from(params.entries())
      .map(([key, value]) => `${key}=${value}`)
      .sort()
      .join('\n');

    const secretKey = crypto
      .createHmac('sha256', 'WebAppData')
      .update(config.telegramBotToken)
      .digest();
    const computedHash = crypto
      .createHmac('sha256', secretKey)
      .update(dataCheckString)
      .digest('hex');

    if (computedHash !== hash) return null;

    const authDate = Number(params.get('auth_date') || '0');
    const ONE_DAY_SECONDS = 24 * 60 * 60;
    if (!authDate || Date.now() / 1000 - authDate > ONE_DAY_SECONDS) return null;

    const userJson = params.get('user');
    if (!userJson) return null;
    const tgUser = JSON.parse(userJson);
    if (!tgUser?.id) return null;
    return tgUser;
  } catch (_) {
    return null;
  }
}

/**
 * Sends the email OTP. Never throws — a Resend/domain failure must not take
 * down signup or login, since the account (or the login attempt) is
 * otherwise valid; callers get back `sent: false` plus the reason and can
 * surface or retry it. Every attempt is persisted either way (delivery_status
 * 'sent' or 'failed') so admin/support can see "this user never actually got
 * a code" instead of it vanishing — previously a failed send left no row at
 * all.
 */
async function createAndSendEmailOtp(userId, cleanEmail, fullName, purpose = 'email_verify') {
  const expiresAt = new Date(Date.now() + config.emailOtpTtlMinutes * 60 * 1000);

  if (!config.resendApiKey) {
    const reason = 'RESEND_API_KEY not configured';
    await pool.query(
      `INSERT INTO email_otps (user_id, email, code_hash, purpose, expires_at, delivery_status, failure_reason)
       VALUES ($1,$2,$3,$4,$5,'failed',$6)`,
      [userId, cleanEmail, '', purpose, expiresAt, reason],
    );
    return { sent: false, warning: reason };
  }

  const code = email.generateOtp();
  try {
    await email.sendEmailOtp({ to: cleanEmail, code, name: fullName });
  } catch (err) {
    const reason = err.message || 'Email delivery failed';
    await pool.query(
      `INSERT INTO email_otps (user_id, email, code_hash, purpose, expires_at, delivery_status, failure_reason)
       VALUES ($1,$2,$3,$4,$5,'failed',$6)`,
      [userId, cleanEmail, email.hashCode(code), purpose, expiresAt, reason],
    );
    return { sent: false, warning: reason };
  }
  await pool.query(
    `INSERT INTO email_otps (user_id, email, code_hash, purpose, expires_at)
     VALUES ($1,$2,$3,$4,$5)`,
    [userId, cleanEmail, email.hashCode(code), purpose, expiresAt],
  );
  return { sent: true, expiresInMinutes: config.emailOtpTtlMinutes };
}

/**
 * POST /auth/signup { fullName, email, phone, password } — password is the
 * primary credential (Apple App Review rejected OTP-only signup/login as
 * the sole auth method); email OTP still runs right after to verify the
 * address, and email-code sign-in remains available as an alternative to
 * the password on /auth/login/request-otp.
 */
router.post('/signup', async (req, res, next) => {
  try {
    const { fullName, email, phone, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const cleanPhone = normalizePhone(phone);
    const cleanPassword = String(password || '');

    if (!fullName || !cleanEmail || !cleanPhone || !cleanPassword) {
      return res.status(400).json({
        error: 'fullName, email, phone and password are required',
      });
    }

    if (!isEmail(cleanEmail)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }

    if (cleanPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
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

    // Agent-assisted onboarding: a valid referral code links the new
    // customer to the agent and pays a flat onboarding commission.
    const agentCode = String(req.body?.agentCode || '').trim();
    let referringAgent = null;
    if (agentCode) {
      referringAgent = (
        await pool.query("SELECT * FROM agents WHERE agent_code = $1 AND status = 'ACTIVE'", [
          agentCode,
        ])
      ).rows[0];
    }

    const passwordHash = await bcrypt.hash(cleanPassword, 10);
    const inserted = await pool.query(
      `INSERT INTO users (full_name, email, phone, password_hash, referred_by_agent_id)
       VALUES ($1,$2,$3,$4,$5) RETURNING id, wallet_index`,
      [String(fullName).trim(), cleanEmail, cleanPhone, passwordHash, referringAgent?.id || null],
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

    if (referringAgent) {
      const ONBOARDING_COMMISSION_USD = 1;
      await creditAgentCommission(pool, referringAgent, 'onboarding', 'USD', ONBOARDING_COMMISSION_USD, user.id);
    }

    const emailVerification = await createAndSendEmailOtp(user.id, cleanEmail, fullName);
    await logLoginEvent(user.id, 'login', 'signup', req);

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
 * POST /auth/telegram { initData } — sign in (or silently create an
 * account for) the Telegram user opening this app as a Mini App inside
 * Telegram. `initData` is the raw string Telegram's WebApp JS SDK exposes
 * as `Telegram.WebApp.initData`; it's re-verified here server-side rather
 * than trusted from the client. New accounts get the same wallet + virtual
 * account provisioning as /auth/signup, minus email/phone (which Telegram
 * doesn't hand over) — phone gets a synthetic 'tg:<id>' placeholder since
 * the column is NOT NULL UNIQUE.
 */
router.post('/telegram', async (req, res, next) => {
  try {
    if (!config.telegramBotToken) {
      return res.status(503).json({ error: 'Telegram sign-in is not configured' });
    }

    const tgUser = verifyTelegramInitData(String(req.body?.initData || ''));
    if (!tgUser) {
      return res.status(401).json({ error: 'Invalid or expired Telegram sign-in data' });
    }

    const telegramId = String(tgUser.id);
    const existing = (
      await pool.query(
        'SELECT id, deletion_requested_at, status FROM users WHERE telegram_id = $1',
        [telegramId],
      )
    ).rows[0];

    if (existing) {
      if (existing.deletion_requested_at) {
        return res.status(403).json({ error: 'This account has been deleted' });
      }
      if (existing.status === 'SUSPENDED') {
        return res.status(403).json({ error: 'This account has been suspended. Contact support.' });
      }
      await pool.query(
        'UPDATE users SET telegram_username = $1, telegram_photo_url = $2 WHERE id = $3',
        [tgUser.username || null, tgUser.photo_url || null, existing.id],
      );
      await logLoginEvent(existing.id, 'login', 'telegram', req);
      return res.json({ token: signToken(existing.id), isNewUser: false });
    }

    const fullName =
      [tgUser.first_name, tgUser.last_name].filter(Boolean).join(' ').trim() ||
      `Telegram User ${telegramId}`;
    const syntheticPhone = `tg:${telegramId}`;

    const inserted = await pool.query(
      `INSERT INTO users (full_name, phone, telegram_id, telegram_username, telegram_photo_url)
       VALUES ($1,$2,$3,$4,$5) RETURNING id, wallet_index`,
      [fullName, syntheticPhone, telegramId, tgUser.username || null, tgUser.photo_url || null],
    );
    const user = inserted.rows[0];

    const ethAddress = custody.addressFor(user.wallet_index);
    await pool.query('UPDATE users SET eth_address = $1 WHERE id = $2', [ethAddress, user.id]);
    await pool.query(
      `INSERT INTO virtual_accounts (user_id, account_name, account_number, currency)
       VALUES ($1,$2,$3,'USD')
       ON CONFLICT (account_number) DO NOTHING`,
      [user.id, fullName, accountNumber(user.id)],
    );

    await logLoginEvent(user.id, 'login', 'telegram', req);
    res.status(201).json({ token: signToken(user.id), ethAddress, isNewUser: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/login { email, password } — primary sign-in method now that
 * every new account sets a password at signup. Accounts created before
 * password signup existed have no password_hash and always reject here;
 * /auth/login/request-otp remains available as an alternative for them
 * (and for anyone who prefers a one-time code).
 */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const result = await pool.query(
      'SELECT id, password_hash, deletion_requested_at, status FROM users WHERE LOWER(email) = LOWER($1)',
      [cleanEmail],
    );
    if (result.rows.length === 0 || !result.rows[0].password_hash) {
      return res.status(401).json({ error: 'Incorrect email or password' });
    }
    if (result.rows[0].deletion_requested_at) {
      return res.status(403).json({ error: 'This account has been deleted' });
    }
    if (result.rows[0].status === 'SUSPENDED') {
      return res.status(403).json({ error: 'This account has been suspended. Contact support.' });
    }
    const ok = await bcrypt.compare(String(password || ''), result.rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: 'Incorrect email or password' });
    await logLoginEvent(result.rows[0].id, 'login', 'password', req);
    res.json({ token: signToken(result.rows[0].id) });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/login/request-otp { email } — sends a 4-digit sign-in code. */
router.post('/login/request-otp', async (req, res, next) => {
  try {
    const cleanEmail = normalizeEmail(req.body?.email);
    if (!isEmail(cleanEmail)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }

    const user = (
      await pool.query(
        'SELECT id, full_name, deletion_requested_at, status FROM users WHERE LOWER(email) = LOWER($1)',
        [cleanEmail],
      )
    ).rows[0];
    if (!user) {
      return res.status(404).json({ error: 'No account found with this email' });
    }
    if (user.deletion_requested_at) {
      return res.status(403).json({ error: 'This account has been deleted' });
    }
    if (user.status === 'SUSPENDED') {
      return res.status(403).json({ error: 'This account has been suspended. Contact support.' });
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
    if (!isEmail(cleanEmail) || !/^\d{4}$/.test(code)) {
      return res.status(400).json({ error: 'Enter the email and 4-digit code' });
    }

    await client.query('BEGIN');
    const user = (
      await client.query(
        'SELECT id, deletion_requested_at, status FROM users WHERE LOWER(email) = LOWER($1) FOR UPDATE',
        [cleanEmail],
      )
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No account found with this email' });
    }
    if (user.deletion_requested_at) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'This account has been deleted' });
    }
    if (user.status === 'SUSPENDED') {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'This account has been suspended. Contact support.' });
    }

    const otp = (
      await client.query(
        `SELECT id, code_hash, attempts, expires_at
           FROM email_otps
          WHERE user_id = $1
            AND LOWER(email) = LOWER($2)
            AND purpose = 'login'
            AND consumed_at IS NULL
            AND delivery_status = 'sent'
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
    await logLoginEvent(user.id, 'login', 'otp', req);
    res.json({ token: signToken(user.id) });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /auth/verify-phone { code } — sandbox: any 4 digits pass. */
router.post('/verify-phone', requireAuth, async (req, res, next) => {
  try {
    const { code } = req.body || {};
    if (!/^\d{4}$/.test(String(code || ''))) {
      return res.status(400).json({ error: 'Enter the 4-digit code' });
    }
    await pool.query('UPDATE users SET phone_verified = TRUE WHERE id = $1', [req.userId]);
    res.json({ verified: true });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/request-email-otp - sends a 4-digit email verification code. */
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
    if (!/^\d{4}$/.test(code)) {
      return res.status(400).json({ error: 'Enter the 4-digit email code' });
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
            AND delivery_status = 'sent'
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

/**
 * POST /auth/logout — records a logout event for the admin sessions
 * dashboard. JWTs aren't revoked server-side (this app has no token
 * blocklist), so this is purely an audit signal, not what actually ends the
 * session — the client discarding its token (AuthService.signOut()) is what
 * does that.
 */
router.post('/logout', requireAuth, async (req, res, next) => {
  try {
    await logLoginEvent(req.userId, 'logout', 'app', req);
    res.json({ loggedOut: true });
  } catch (err) {
    next(err);
  }
});

/** GET /auth/me */
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT id, full_name, email, phone, kyc_tier, phone_verified, eth_address,
              usd_balance, kes_balance, role, email_verified, created_at,
              username, wallet_id_type,
              (pin_hash IS NOT NULL) AS has_pin,
              (password_hash IS NOT NULL) AS has_password
         FROM users WHERE id = $1`,
      [req.userId],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

/**
 * PATCH /auth/profile { fullName } — updates the display name only. No
 * re-verification needed since it isn't a login credential or lookup key.
 */
router.patch('/profile', requireAuth, async (req, res, next) => {
  try {
    const fullName = String(req.body?.fullName || '').trim();
    if (!fullName) {
      return res.status(400).json({ error: 'Full name is required' });
    }
    await pool.query('UPDATE users SET full_name = $1 WHERE id = $2', [fullName, req.userId]);
    res.json({ fullName });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/email/change { newEmail } — starts an email change: sends a
 * code to the *new* address (purpose 'email_change') rather than switching
 * immediately, so the account can't be pointed at an email the user
 * doesn't actually control. The old email keeps working until confirmed.
 */
router.post('/email/change', requireAuth, async (req, res, next) => {
  try {
    const newEmail = normalizeEmail(req.body?.newEmail);
    if (!isEmail(newEmail)) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }
    const existing = await pool.query(
      'SELECT id FROM users WHERE LOWER(email) = $1 AND id != $2',
      [newEmail, req.userId],
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'An account with this email already exists' });
    }
    const user = (
      await pool.query('SELECT full_name FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    const result = await createAndSendEmailOtp(req.userId, newEmail, user.full_name, 'email_change');
    if (!result.sent) return res.status(503).json(result);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/email/change/confirm { code } — verifies the code sent to the
 * pending new email (matched by purpose='email_change', not by the old
 * email still on the account) and, on success, switches users.email over.
 */
router.post('/email/change/confirm', requireAuth, async (req, res, next) => {
  try {
    const code = String(req.body?.code || '').trim();
    const otp = (
      await pool.query(
        `SELECT id, email, code_hash, attempts, expires_at
           FROM email_otps
          WHERE user_id = $1
            AND purpose = 'email_change'
            AND consumed_at IS NULL
            AND delivery_status = 'sent'
          ORDER BY created_at DESC
          LIMIT 1`,
        [req.userId],
      )
    ).rows[0];
    if (!otp) return res.status(404).json({ error: 'No pending email change. Start again.' });
    if (new Date(otp.expires_at).getTime() < Date.now()) {
      return res.status(410).json({ error: 'Code has expired. Start again.' });
    }
    if (Number(otp.attempts) >= 5) {
      return res.status(429).json({ error: 'Too many attempts. Start again.' });
    }
    if (email.hashCode(code) !== otp.code_hash) {
      await pool.query('UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
      return res.status(400).json({ error: 'Incorrect code' });
    }

    await pool.query('UPDATE email_otps SET consumed_at = now() WHERE id = $1', [otp.id]);
    await pool.query(
      'UPDATE users SET email = $1, email_verified = TRUE WHERE id = $2',
      [otp.email, req.userId],
    );
    res.json({ email: otp.email });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/password/change { currentPassword?, newPassword } — sets or
 * changes the login password. `currentPassword` is required only when one
 * is already set (accounts created via Telegram/OTP-only may have none).
 */
router.post('/password/change', requireAuth, async (req, res, next) => {
  try {
    const newPassword = String(req.body?.newPassword || '');
    const currentPassword = String(req.body?.currentPassword || '');
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const existing = (
      await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (existing?.password_hash) {
      const ok = currentPassword && (await bcrypt.compare(currentPassword, existing.password_hash));
      if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, req.userId]);
    res.json({ set: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/delete-account — user-initiated deletion (App Store Guideline
 * 5.1.1(v): must be reachable in-app, not only via emailing support). Blocks
 * the account from signing in again immediately; financial/KYC records are
 * retained for the compliance period described in the privacy policy rather
 * than hard-deleted on the spot.
 */
router.post('/delete-account', requireAuth, async (req, res, next) => {
  try {
    await pool.query('UPDATE users SET deletion_requested_at = now() WHERE id = $1', [
      req.userId,
    ]);
    res.json({ requested: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/pin — set the 4-digit transaction PIN checked before a
 * transfer goes through. If a PIN already exists, the caller must supply
 * the current one to change it; first-time set needs no `currentPin`.
 */
router.post('/pin', requireAuth, async (req, res, next) => {
  try {
    const pin = String(req.body?.pin || '').trim();
    const currentPin = String(req.body?.currentPin || '').trim();
    if (!/^\d{4}$/.test(pin)) {
      return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
    }

    const existing = (
      await pool.query('SELECT pin_hash FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (existing?.pin_hash) {
      const ok = currentPin && (await bcrypt.compare(currentPin, existing.pin_hash));
      if (!ok) return res.status(401).json({ error: 'Current PIN is incorrect' });
    }

    const hash = await bcrypt.hash(pin, 10);
    await pool.query('UPDATE users SET pin_hash = $1 WHERE id = $2', [hash, req.userId]);
    res.json({ set: true });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/pin/verify — check a PIN against the stored hash. */
router.post('/pin/verify', requireAuth, async (req, res, next) => {
  try {
    const pin = String(req.body?.pin || '').trim();
    const user = (
      await pool.query('SELECT pin_hash FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (!user?.pin_hash) return res.json({ verified: false, hasPin: false });

    const verified = await bcrypt.compare(pin, user.pin_hash);
    res.json({ verified, hasPin: true });
  } catch (err) {
    next(err);
  }
});

const USERNAME_PATTERN = /^[a-z0-9_]{3,20}$/;

/**
 * GET /auth/wallet-id/check-username?value=foo — live availability check
 * used by the Wallet ID setup screen while the user is typing.
 */
router.get('/wallet-id/check-username', requireAuth, async (req, res, next) => {
  try {
    const value = String(req.query?.value || '').trim().toLowerCase();
    if (!USERNAME_PATTERN.test(value)) {
      return res.json({ available: false, reason: '3-20 characters: letters, numbers, underscore' });
    }
    const existing = await pool.query(
      'SELECT id FROM users WHERE LOWER(username) = $1 AND id != $2',
      [value, req.userId],
    );
    res.json({ available: existing.rows.length === 0 });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/wallet-id { type, username? } — sets which identifier (phone,
 * email, or a custom handle) this user hands out to receive money. `type`
 * 'username' requires `username` and claims it (case-insensitive unique).
 */
router.post('/wallet-id', requireAuth, async (req, res, next) => {
  try {
    const type = String(req.body?.type || '').trim().toLowerCase();
    if (!['phone', 'email', 'username'].includes(type)) {
      return res.status(400).json({ error: 'type must be phone, email or username' });
    }

    if (type === 'username') {
      const username = String(req.body?.username || '').trim().toLowerCase();
      if (!USERNAME_PATTERN.test(username)) {
        return res.status(400).json({
          error: 'Username must be 3-20 characters: letters, numbers, underscore',
        });
      }
      const existing = await pool.query(
        'SELECT id FROM users WHERE LOWER(username) = $1 AND id != $2',
        [username, req.userId],
      );
      if (existing.rows.length > 0) {
        return res.status(409).json({ error: 'That username is taken' });
      }
      await pool.query(
        'UPDATE users SET username = $1, wallet_id_type = $2 WHERE id = $3',
        [username, type, req.userId],
      );
    } else {
      await pool.query('UPDATE users SET wallet_id_type = $1 WHERE id = $2', [type, req.userId]);
    }

    res.json({ set: true, type });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
