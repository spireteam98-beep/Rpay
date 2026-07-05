const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');

const router = express.Router();
router.use(requireAuth);

const SUPPORTED_RAILS = ['EVC Plus', 'Zaad', 'Sahal', 'M-Pesa'];

function cleanRail(rail) {
  const value = String(rail || '').trim();
  if (!SUPPORTED_RAILS.includes(value)) {
    throw new Error(`Unsupported rail. Supported: ${SUPPORTED_RAILS.join(', ')}`);
  }
  return value;
}

function cleanAmount(amount) {
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error('A positive amountKes is required');
  }
  return Number(value.toFixed(2));
}

router.get('/rails', (_req, res) => {
  res.json({ rails: SUPPORTED_RAILS, currency: 'KES', kesPerUsd: config.kesPerUsd });
});

router.get('/movements', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, type, rail, phone, amount_kes, reference, status, admin_note, created_at, updated_at
         FROM mobile_money_movements
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.post('/deposits', async (req, res, next) => {
  try {
    const rail = cleanRail(req.body?.rail);
    const amountKes = cleanAmount(req.body?.amountKes);
    const reference = String(req.body?.reference || '').trim();
    const phone = String(req.body?.phone || '').trim();

    if (!reference) {
      return res.status(400).json({ error: 'Payment reference is required for admin approval' });
    }

    const inserted = await pool.query(
      `INSERT INTO mobile_money_movements (user_id, type, rail, phone, amount_kes, reference)
       VALUES ($1,'DEPOSIT',$2,$3,$4,$5)
       RETURNING id, type, rail, amount_kes, reference, status, created_at`,
      [req.userId, rail, phone || null, amountKes, reference],
    );

    res.status(202).json({
      movement: inserted.rows[0],
      message: 'Deposit submitted. Your KES wallet will be credited after admin approval.',
    });
  } catch (err) {
    next(err);
  }
});

router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const rail = cleanRail(req.body?.rail);
    const amountKes = cleanAmount(req.body?.amountKes);
    const phone = String(req.body?.phone || '').trim();
    if (!phone) return res.status(400).json({ error: 'Payout phone is required' });

    await client.query('BEGIN');
    const user = (
      await client.query('SELECT kes_balance FROM users WHERE id = $1 FOR UPDATE', [req.userId])
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }
    if (Number(user.kes_balance) < amountKes) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Not enough KES balance' });
    }

    await client.query('UPDATE users SET kes_balance = kes_balance - $1 WHERE id = $2', [
      amountKes,
      req.userId,
    ]);
    const inserted = await client.query(
      `INSERT INTO mobile_money_movements (user_id, type, rail, phone, amount_kes, status)
       VALUES ($1,'WITHDRAWAL',$2,$3,$4,'PENDING_PAYOUT')
       RETURNING id, type, rail, phone, amount_kes, status, created_at`,
      [req.userId, rail, phone, amountKes],
    );
    const amountUsd = Number((amountKes / config.kesPerUsd).toFixed(2));
    await ledger.postWithClient(
      client,
      req.userId,
      { title: `${rail} withdrawal hold`, rail, status: 'Pending' },
      [
        { accountName: 'Customer KES wallet', direction: 'debit', amountUsd, memo: `${amountKes} KES held` },
        { accountName: 'Mobile money payout clearing', direction: 'credit', amountUsd, memo: phone },
      ],
    );
    await client.query('COMMIT');

    res.status(202).json({
      movement: inserted.rows[0],
      message: 'Withdrawal queued for manual mobile-money payout.',
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
