const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const { payoutToMpesa } = require('../services/paystackTransfers');

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

/** Releases a withdrawal hold back to the customer's balance when Paystack
 * rejects the transfer outright (bad number, insufficient Paystack balance,
 * etc.) — runs in its own transaction since the original hold has already
 * committed by the time the payout attempt fails. */
async function refundFailedWithdrawal(userId, movement, amountUsd, reason) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE users SET kes_balance = kes_balance + $1 WHERE id = $2', [
      movement.amount_kes,
      userId,
    ]);
    await ledger.postWithClient(
      client,
      userId,
      { title: `${movement.rail} withdrawal failed`, rail: movement.rail },
      [
        { accountName: 'Mobile money payout clearing', direction: 'debit', amountUsd, memo: reason },
        { accountName: 'Customer KES wallet', direction: 'credit', amountUsd, memo: `${movement.amount_kes} KES released` },
      ],
    );
    await client.query(
      `UPDATE mobile_money_movements SET status = 'FAILED', admin_note = $1, updated_at = now() WHERE id = $2`,
      [reason, movement.id],
    );
    await client.query('COMMIT');
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    throw err;
  } finally {
    client.release();
  }
}

/**
 * M-Pesa withdrawals go straight to Paystack — no admin approval step, same
 * as Wayaki-to-Wayaki P2P transfers (routes/transfers.js), gated by balance
 * plus the same KYC-tier daily limit check P2P already uses instead of a
 * human review. Other rails (EVC Plus, Zaad, Sahal) have no automated payout
 * provider wired up yet, so they still queue for manual admin payout via
 * POST /admin/mobile-money/:id/complete-withdrawal.
 */
router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const rail = cleanRail(req.body?.rail);
    const amountKes = cleanAmount(req.body?.amountKes);
    const phone = String(req.body?.phone || '').trim();
    if (!phone) return res.status(400).json({ error: 'Payout phone is required' });
    const amountUsd = Number((amountKes / config.kesPerUsd).toFixed(2));

    await client.query('BEGIN');
    const user = (
      await client.query('SELECT full_name, kes_balance FROM users WHERE id = $1 FOR UPDATE', [
        req.userId,
      ])
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }
    if (Number(user.kes_balance) < amountKes) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Not enough KES balance' });
    }

    const limit = await compliance.checkUserLimit(client, req.userId, amountUsd, `${rail} withdrawal`);
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Withdrawal requires compliance review' });
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
    const movement = inserted.rows[0];
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

    if (rail !== 'M-Pesa') {
      return res.status(202).json({
        movement,
        message: 'Withdrawal queued for manual mobile-money payout.',
      });
    }

    const reference = `wd_${String(movement.id).replace(/-/g, '')}_${Date.now()}`;
    try {
      const transfer = await payoutToMpesa({
        name: user.full_name,
        phone,
        amountKes,
        reference,
        reason: `Wayaki ${rail} withdrawal`,
      });
      const status = transfer.status === 'otp' ? 'PENDING_OTP' : 'PROCESSING';
      await pool.query(
        `UPDATE mobile_money_movements SET status = $1, reference = $2, updated_at = now() WHERE id = $3`,
        [status, reference, movement.id],
      );
      return res.status(202).json({
        movement: { ...movement, status, reference },
        message:
          status === 'PENDING_OTP'
            ? 'Withdrawal submitted but is waiting on a Paystack confirmation step — contact support.'
            : 'Withdrawal is on its way to your M-Pesa number.',
      });
    } catch (err) {
      await refundFailedWithdrawal(req.userId, movement, amountUsd, err.message);
      return res.status(502).json({
        error: `Could not send to M-Pesa: ${err.message}. Your balance has been refunded.`,
      });
    }
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
