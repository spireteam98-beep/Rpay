const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

function accountNumber(userId) {
  const compact = String(userId).replace(/-/g, '').slice(0, 12).toUpperCase();
  return `KF${compact}`;
}

async function ensureAccount(userId) {
  const existing = (
    await pool.query(
      `SELECT id, account_name, account_number, currency, status, created_at
         FROM virtual_accounts WHERE user_id = $1 LIMIT 1`,
      [userId],
    )
  ).rows[0];
  if (existing) return existing;

  const user = (await pool.query('SELECT full_name FROM users WHERE id = $1', [userId])).rows[0];
  const inserted = await pool.query(
    `INSERT INTO virtual_accounts (user_id, account_name, account_number, currency)
     VALUES ($1,$2,$3,'USD')
     RETURNING id, account_name, account_number, currency, status, created_at`,
    [userId, user.full_name, accountNumber(userId)],
  );
  return inserted.rows[0];
}

router.get('/account', async (req, res, next) => {
  try {
    res.json({ account: await ensureAccount(req.userId) });
  } catch (err) {
    next(err);
  }
});

router.get('/statement', async (req, res, next) => {
  try {
    const account = await ensureAccount(req.userId);
    const txs = await pool.query(
      `SELECT id, title, rail, status, posted_at
         FROM ledger_transactions
        WHERE user_id = $1
        ORDER BY posted_at DESC
        LIMIT 100`,
      [req.userId],
    );
    res.json({ account, transactions: txs.rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
