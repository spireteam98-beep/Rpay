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
      `SELECT id, type, rail, phone, amount_kes, reference, status, admin_note,
              source_currency, locked_rate_kes_per_usd, agent_reference, created_at, updated_at
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
 * GET /mobile-money/fx-offers?amountUsd=10 — the customer-facing
 * marketplace listing for USD-sourced M-Pesa/Till: every active agent's
 * live rate, sorted best-for-the-customer first (highest KES per USD).
 * `amountUsd`, when given, filters out offers whose min/max don't cover
 * it — same rate schedule POST /withdrawals validates against at order
 * time.
 */
router.get('/fx-offers', async (req, res, next) => {
  try {
    const amountUsd = Number(req.query?.amountUsd);
    const hasAmount = Number.isFinite(amountUsd) && amountUsd > 0;
    const rows = await pool.query(
      `SELECT o.id, o.rate_kes_per_usd, o.min_usd, o.max_usd,
              a.id AS agent_id, a.business_name, a.agent_code
         FROM agent_fx_offers o
         JOIN agents a ON a.id = o.agent_id
        WHERE o.direction = 'AGENT_PROVIDES_KES' AND o.active = TRUE
          AND a.status = 'ACTIVE' AND a.can_provide_kes = TRUE
          AND ($1::numeric IS NULL OR ($1 >= o.min_usd AND $1 <= o.max_usd))
        ORDER BY o.rate_kes_per_usd DESC
        LIMIT 50`,
      [hasAmount ? amountUsd : null],
    );
    res.json({ referenceRateKesPerUsd: config.kesPerUsd, offers: rows.rows });
  } catch (err) {
    next(err);
  }
});

/**
 * KES-sourced M-Pesa (phone) and M-Pesa Till withdrawals go straight to
 * Paystack — no approval step, same as Wayaki-to-Wayaki P2P transfers
 * (routes/transfers.js), gated by balance plus the same KYC-tier daily
 * limit check P2P already uses instead of a human review. That's reliable
 * because Paystack top-ups are the only thing that actually fund
 * Paystack's own payable balance.
 *
 * USD-sourced M-Pesa/Till withdrawals go through the agent FX marketplace
 * instead (GET /fx-offers above, routes/agents.js mobile-money-queue
 * endpoints) — Stripe/Waafi money never reaches Paystack's balance, so an
 * automated Paystack call here would just fail unpredictably. The
 * customer picks a specific agent's rate offer (`fxOfferId`), which locks
 * in that agent and rate for this order; the agent accepts and sends the
 * real M-Pesa/Till payment themselves, off their own float. Settlement
 * (routes/agents.js .../complete) is a direct swap — the agent's margin
 * is baked into the rate they set, not a separate fee.
 *
 * Other rails (EVC Plus, Zaad, Sahal) have no automated or agent payout
 * wired up yet, so they still queue for manual admin payout via
 * POST /admin/mobile-money/:id/complete-withdrawal.
 *
 * `amount` is always in `sourceCurrency` (default 'KES') — never
 * pre-converted by the client. For the KES-sourced Paystack path this
 * endpoint alone derives amountKes/amountUsd using this server's own
 * config.kesPerUsd (never the client's, to avoid stale-rate round-trip
 * drift); for the agent-fulfilled path amountKes is derived from the
 * picked offer's locked rate instead.
 */
router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const rail = cleanRail(req.body?.rail);
    const sourceCurrency = cleanSourceCurrency(req.body?.sourceCurrency);
    const amount = cleanAmount(req.body?.amount);
    const isTill = rail === 'M-Pesa Till';
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

    const isAgentFulfilled = AUTO_PAYOUT_RAILS.includes(rail) && sourceCurrency === 'USD';

    let amountKes;
    let amountUsd;
    let agentId = null;
    let fxOfferId = null;
    let lockedRate = null;

    if (isAgentFulfilled) {
      fxOfferId = String(req.body?.fxOfferId || '').trim();
      if (!fxOfferId) {
        return res.status(400).json({ error: 'Pick an agent rate offer first' });
      }
      const offer = (
        await pool.query(
          `SELECT o.*, a.status AS agent_status, a.can_provide_kes
             FROM agent_fx_offers o JOIN agents a ON a.id = o.agent_id
            WHERE o.id = $1`,
          [fxOfferId],
        )
      ).rows[0];
      if (
        !offer ||
        offer.direction !== 'AGENT_PROVIDES_KES' ||
        !offer.active ||
        offer.agent_status !== 'ACTIVE' ||
        !offer.can_provide_kes
      ) {
        return res.status(404).json({ error: 'That rate offer is no longer available' });
      }
      if (amount < Number(offer.min_usd) || amount > Number(offer.max_usd)) {
        return res.status(400).json({
          error: `This agent accepts $${offer.min_usd}-$${offer.max_usd} — enter an amount in that range`,
        });
      }
      lockedRate = Number(offer.rate_kes_per_usd);
      amountKes = Number((amount * lockedRate).toFixed(2));
      amountUsd = amount;
      agentId = offer.agent_id;
    } else {
      amountKes = sourceCurrency === 'USD' ? Number((amount * config.kesPerUsd).toFixed(2)) : amount;
      amountUsd = sourceCurrency === 'USD' ? amount : Number((amount / config.kesPerUsd).toFixed(2));
    }

    // No separate fee — for the agent-fulfilled path the agent's margin is
    // already baked into the rate they offered, so the customer is only
    // ever debited the raw amount they asked to send.
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
    const status = isAgentFulfilled ? 'PENDING_AGENT' : 'PENDING_PAYOUT';
    const inserted = await client.query(
      `INSERT INTO mobile_money_movements
        (user_id, type, rail, phone, amount_kes, status, source_currency,
         agent_id, agent_fx_offer_id, locked_rate_kes_per_usd)
       VALUES ($1,'WITHDRAWAL',$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, type, rail, phone, amount_kes, status, locked_rate_kes_per_usd, created_at`,
      [req.userId, rail, phone, amountKes, status, sourceCurrency, agentId, fxOfferId, lockedRate],
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
        {
          accountName: isAgentFulfilled ? 'Agent payout clearing' : 'Mobile money payout clearing',
          direction: 'credit',
          amountUsd,
          memo: phone,
        },
      ],
    );
    await client.query('COMMIT');

    if (isAgentFulfilled) {
      return res.status(202).json({
        movement,
        message: `Sent to the agent — you'll be notified once they confirm and send your ${isTill ? 'Till payment' : 'M-Pesa'}.`,
      });
    }

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
