const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');

const router = express.Router();
router.use(requireAuth);

function cleanCurrency(value) {
  const currency = String(value || 'KES').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw new Error('currency must be KES or USD');
  return currency;
}

function balanceColumn(currency) {
  return currency === 'KES' ? 'kes_balance' : 'usd_balance';
}

/** POST /bills/pay — pay a biller (KPLC, water, DSTV, etc.) from the wallet. */
router.post('/pay', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const billerName = String(req.body?.billerName || '').trim();
    const accountNumber = String(req.body?.accountNumber || '').trim();
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    if (!billerName) return res.status(400).json({ error: 'Biller is required' });
    if (!accountNumber) return res.status(400).json({ error: 'Account number is required' });
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }

    await client.query('BEGIN');
    const amountUsd = compliance.toUsd(amount, currency);
    const limit = await compliance.checkUserLimit(
      client,
      req.userId,
      amountUsd,
      `Bill payment to ${billerName}`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Payment requires compliance review' });
    }

    const column = balanceColumn(currency);
    const payer = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        req.userId,
      ])
    ).rows[0];
    if (Number(payer.balance) < amount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${currency} balance` });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      amount,
      req.userId,
    ]);
    const payment = await client.query(
      `INSERT INTO bill_payments (user_id, biller_name, account_number, currency, amount)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [req.userId, billerName, accountNumber, currency, amount],
    );

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Paid ${billerName}`, rail: 'Bill payment' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd, memo: accountNumber },
        { accountName: 'Bill payments clearing', direction: 'credit', amountUsd, memo: payment.rows[0].id },
      ],
    );
    await client.query('COMMIT');

    res.status(201).json({ payment: payment.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /bills/me — the user's recent bill payments. */
router.get('/me', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, biller_name, account_number, currency, amount, status, created_at
         FROM bill_payments WHERE user_id = $1
        ORDER BY created_at DESC LIMIT 50`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
