const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { signToken, requireAuth } = require('../middleware/auth');
const custody = require('../services/custody');

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

/** POST /auth/signup { fullName, email, phone, password } */
router.post('/signup', async (req, res, next) => {
  try {
    const { fullName, email, phone, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const cleanPhone = normalizePhone(phone);

    if (!fullName || !cleanEmail || !cleanPhone || !password || String(password).length < 8) {
      return res.status(400).json({
        error: 'fullName, email, phone and a password of 8+ characters are required',
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

    const hash = await bcrypt.hash(String(password), 10);
    const inserted = await pool.query(
      `INSERT INTO users (full_name, email, phone, password_hash)
       VALUES ($1,$2,$3,$4) RETURNING id, wallet_index`,
      [String(fullName).trim(), cleanEmail, cleanPhone, hash],
    );
    const user = inserted.rows[0];

    // Provision the custodial wallet at signup — the roadmap promise:
    // one signup ⇒ crypto wallet + domestic wallet + bank account.
    const ethAddress = custody.addressFor(user.wallet_index);
    await pool.query('UPDATE users SET eth_address = $1 WHERE id = $2', [ethAddress, user.id]);

    res.status(201).json({ token: signToken(user.id), ethAddress });
  } catch (err) {
    next(err);
  }
});

/** POST /auth/login { email, password } */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const cleanEmail = normalizeEmail(email);
    const result = await pool.query(
      'SELECT id, password_hash FROM users WHERE LOWER(email) = LOWER($1)',
      [cleanEmail],
    );
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Incorrect email or password' });
    }
    const ok = await bcrypt.compare(String(password || ''), result.rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: 'Incorrect email or password' });
    res.json({ token: signToken(result.rows[0].id) });
  } catch (err) {
    next(err);
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
      `SELECT id, full_name, email, phone, kyc_tier, phone_verified, eth_address, created_at
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
