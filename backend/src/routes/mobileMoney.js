const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const { payoutToMpesa, payoutToTill } = require('../services/paystackTransfers');

const router = express.Router();
router.use(requireAuth);

const SUPPORTED_RAILS = ['EVC Plus', 'Zaad', 'Sahal', 'M-Pesa', 'M-Pesa Till'];
const AUTO_PAYOUT_RAILS = ['M-Pesa', 'M-Pesa Till'];

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
    throw new Error('A positive amount is required');
  }
  return Number(value.toFixed(2));
}

function cleanSourceCurrency(value) {
  const currency = String(value || 'KES').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) {
    throw new Error('sourceCurrency must be KES or USD');
  }
  return currency;
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
 * committed by the time the payout attempt fails. Refunds to whichever
 * wallet the hold was actually drawn from (KES or USD), not always KES —
 * the M-Pesa payout amount is always KES, but the source wallet debited
 * for it can be either. */
async function refundFailedWithdrawal(userId, movement, sourceCurrency, debitAmount, amountUsd, reason) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const balanceColumn = sourceCurrency === 'USD' ? 'usd_balance' : 'kes_balance';
    await client.query(`UPDATE users SET ${balanceColumn} = ${balanceColumn} + $1 WHERE id = $2`, [
      debitAmount,
      userId,
    ]);
    await ledger.postWithClient(
      client,
      userId,
      { title: `${movement.rail} withdrawal failed`, rail: movement.rail },
      [
        { accountName: 'Mobile money payout clearing', direction: 'debit', amountUsd, memo: reason },
        {
          accountName: `Customer ${sourceCurrency} wallet`,
          direction: 'credit',
          amountUsd,
          memo: `${debitAmount} ${sourceCurrency} released`,
        },
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
 * M-Pesa (phone) and M-Pesa Till withdrawals go straight to Paystack — no
 * admin approval step, same as Wayaki-to-Wayaki P2P transfers
 * (routes/transfers.js), gated by balance plus the same KYC-tier daily
 * limit check P2P already uses instead of a human review. Other rails
 * (EVC Plus, Zaad, Sahal) have no automated payout provider wired up yet,
 * so they still queue for manual admin payout via
 * POST /admin/mobile-money/:id/complete-withdrawal.
 *
 * `amount` is always in `sourceCurrency` (default 'KES') — never
 * pre-converted by the client. This endpoint alone derives amountKes (what
 * actually lands on M-Pesa — Paystack only sends KES) and amountUsd from it
 * using this server's own config.kesPerUsd. That's deliberate: if the
 * client converted USD->KES itself using a cached/stale rate, converting
 * back here to check the balance wouldn't round-trip exactly, and a real
 * $3.00 balance could come back needing $3.02 — a false "not enough
 * balance" purely from rate drift between client and server.
 */
router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const rail = cleanRail(req.body?.rail);
    const sourceCurrency = cleanSourceCurrency(req.body?.sourceCurrency);
    const amount = cleanAmount(req.body?.amount);
    const isTill = rail === 'M-Pesa Till';
    // M-Pesa/Till payouts draw from Paystack's real account balance
    // (source: 'balance' in paystackTransfers.js), regardless of which
    // gateway funded the customer's wallet (Stripe, Waafi, or Paystack
    // itself). Stripe/Waafi settle into separate real-money accounts with
    // no automatic bridge into Paystack, so this can fail at Paystack even
    // when the in-app balance looks sufficient — refundFailedWithdrawal
    // below returns the hold to the customer if that happens. Allowed
    // deliberately: keeping Paystack's real balance funded to cover this is
    // an operator responsibility, not something this endpoint enforces.
    // Reuses the `phone` column as a generic "payout destination" field —
    // a till number, not a phone, when rail is 'M-Pesa Till'.
    const phone = String((isTill ? req.body?.tillNumber : req.body?.phone) || '').trim();
    if (!phone) {
      return res.status(400).json({
        error: isTill ? 'Till number is required' : 'Payout phone is required',
      });
    }
    if (isTill && !/^\d{5,7}$/.test(phone)) {
      return res.status(400).json({ error: 'Enter a valid 5-7 digit till number' });
    }
    const amountKes =
      sourceCurrency === 'USD' ? Number((amount * config.kesPerUsd).toFixed(2)) : amount;
    const amountUsd =
      sourceCurrency === 'USD' ? amount : Number((amount / config.kesPerUsd).toFixed(2));
    // What actually gets debited from the source wallet — always just
    // `amount`, since it's already in sourceCurrency.
    const debitAmount = amount;
    const balanceColumn = sourceCurrency === 'USD' ? 'usd_balance' : 'kes_balance';

    await client.query('BEGIN');
    const user = (
      await client.query(
        `SELECT full_name, ${balanceColumn} AS balance FROM users WHERE id = $1 FOR UPDATE`,
        [req.userId],
      )
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }
    if (Number(user.balance) < debitAmount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${sourceCurrency} balance` });
    }

    const limit = await compliance.checkUserLimit(client, req.userId, amountUsd, `${rail} withdrawal`);
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Withdrawal requires compliance review' });
    }

    await client.query(`UPDATE users SET ${balanceColumn} = ${balanceColumn} - $1 WHERE id = $2`, [
      debitAmount,
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
        {
          accountName: `Customer ${sourceCurrency} wallet`,
          direction: 'debit',
          amountUsd,
          memo: `${debitAmount} ${sourceCurrency} held for ${amountKes} KES payout`,
        },
        { accountName: 'Mobile money payout clearing', direction: 'credit', amountUsd, memo: phone },
      ],
    );
    await client.query('COMMIT');

    if (!AUTO_PAYOUT_RAILS.includes(rail)) {
      return res.status(202).json({
        movement,
        message: 'Withdrawal queued for manual mobile-money payout.',
      });
    }

    const reference = `wd_${String(movement.id).replace(/-/g, '')}_${Date.now()}`;
    try {
      const transfer = isTill
        ? await payoutToTill({
            name: user.full_name,
            tillNumber: phone,
            amountKes,
            reference,
            reason: `Wayaki ${rail} withdrawal`,
          })
        : await payoutToMpesa({
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
            : isTill
              ? 'Payment is on its way to the till.'
              : 'Withdrawal is on its way to your M-Pesa number.',
      });
    } catch (err) {
      await refundFailedWithdrawal(req.userId, movement, sourceCurrency, debitAmount, amountUsd, err.message);
      // Paystack's own wording ("Your balance is not enough to fulfil this
      // request") refers to its account balance, not the customer's — that
      // distinction is meaningless to a customer and reads as a raw error
      // dump, so swap in something clear instead of passing it through.
      const insufficientFunds = /balance.*not enough|insufficient/i.test(err.message || '');
      const reason = insufficientFunds
        ? "our payment processor couldn't complete this payout right now"
        : err.message;
      return res.status(502).json({
        error: `Could not send to the ${isTill ? 'till' : 'M-Pesa number'}: ${reason}. Your balance has been refunded.`,
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
