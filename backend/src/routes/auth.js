const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { signToken, requireAuth } = require('../middleware/auth');
const custody = require('../services/custody');

const router = express.Router();

/** POST /auth/signup { fullName, phone, password } */
router.post('/signup', async (req, res, next) => {
  try {
    const { fullName, phone, password } = req.body || {};
    if (!fullName || !phone || !password || String(password).length < 8) {
      return res.status(400).json({
        error: 'fullName, phone and a password of 8+ characters are required',
      });
    }

    const existing = await pool.query('SELECT id FROM users WHERE phone = $1', [phone.trim()]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'An account with this phone already exists' });
    }

    const hash = await bcrypt.hash(String(password), 10);
    const inserted = await pool.query(
      `INSERT INTO users (full_name, phone, password_hash)
       VALUES ($1,$2,$3) RETURNING id, wallet_index`,
      [String(fullName).trim(), String(phone).trim(), hash],
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

/** POST /auth/login { phone, password } */
router.post('/login', async (req, res, next) => {
  try {
    const { phone, password } = req.body || {};
    const result = await pool.query(
      'SELECT id, password_hash FROM users WHERE phone = $1',
      [String(phone || '').trim()],
    );
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Incorrect phone or password' });
    }
    const ok = await bcrypt.compare(String(password || ''), result.rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: 'Incorrect phone or password' });
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
      `SELECT id, full_name, phone, kyc_tier, phone_verified, eth_address, created_at
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
