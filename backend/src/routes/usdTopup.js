const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const notify = require('../services/notify');

const router = express.Router();
router.use(requireAuth);

async function ownAgentRow(client, userId) {
  const rows = await client.query('SELECT * FROM agents WHERE user_id = $1', [userId]);
  return rows.rows[0] || null;
}

/**
 * Reverse side of the FX marketplace (routes/agents.js / mobileMoney.js
 * handle AGENT_PROVIDES_KES): here the agent provides USD — credits the
 * customer's Wayaki wallet — in exchange for real KES the customer sends
 * the agent directly (M-Pesa/cash), outside the app. Modeled on Binance
 * P2P's actual escrow mechanics: the seller's asset (here, the agent's USD)
 * is reserved the moment the order is created, not just checked-and-debited
 * at the end — so a customer who starts paying is guaranteed the USD is
 * really available, and an agent can't overcommit the same float across
 * several simultaneous orders. status flow: PENDING_PAYMENT (escrowed,
 * customer hasn't paid yet; buyer and seller can chat, see
 * .../messages below) -> PROOF_SUBMITTED (customer sent KES, uploaded
 * proof) -> RELEASED (agent verified receipt, escrow pays out to the
 * customer) or REJECTED (bad/missing proof, escrow refunds the agent,
 * customer can resubmit) or CANCELLED (customer backed out, escrow
 * refunds the agent).
 */

/**
 * GET /usd-topup/offers?amountUsd=10 — active AGENT_PROVIDES_USD offers,
 * cheapest-for-the-customer first (lowest KES per USD, since here the
 * customer is paying KES to receive USD — the mirror image of the sort in
 * GET /mobile-money/fx-offers, where the customer instead wants the most
 * KES per USD they give up).
 */
router.get('/offers', async (req, res, next) => {
  try {
    const amountUsd = Number(req.query?.amountUsd);
    const hasAmount = Number.isFinite(amountUsd) && amountUsd > 0;
    const rows = await pool.query(
      `SELECT o.id, o.rate_kes_per_usd, o.min_usd, o.max_usd,
              a.id AS agent_id, a.business_name, a.agent_code
         FROM agent_fx_offers o
         JOIN agents a ON a.id = o.agent_id
        WHERE o.direction = 'AGENT_PROVIDES_USD' AND o.active = TRUE
          AND a.status = 'ACTIVE' AND a.can_provide_usd = TRUE
          AND ($1::numeric IS NULL OR ($1 >= o.min_usd AND $1 <= o.max_usd))
        ORDER BY o.rate_kes_per_usd ASC
        LIMIT 50`,
      [hasAmount ? amountUsd : null],
    );
    res.json({ referenceRateKesPerUsd: config.kesPerUsd, offers: rows.rows });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /usd-topup/orders { agentFxOfferId, amountUsd } — customer opens an
 * order against a specific agent's posted rate. The agent's USD is escrowed
 * (debited into a pending state) right here, Binance-style — if they don't
 * have enough available, the order is refused outright rather than letting
 * the customer pay and find out later.
 */
router.post('/orders', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const agentFxOfferId = String(req.body?.agentFxOfferId || '').trim();
    const amountUsd = Number(req.body?.amountUsd);
    if (!agentFxOfferId) return res.status(400).json({ error: 'agentFxOfferId is required' });
    if (!Number.isFinite(amountUsd) || amountUsd <= 0) {
      return res.status(400).json({ error: 'A positive amountUsd is required' });
    }

    const offer = (
      await client.query(
        `SELECT o.*, a.status AS agent_status, a.can_provide_usd, a.user_id AS agent_user_id,
                a.business_name, a.agent_code, a.phone
           FROM agent_fx_offers o JOIN agents a ON a.id = o.agent_id
          WHERE o.id = $1`,
        [agentFxOfferId],
      )
    ).rows[0];
    if (
      !offer ||
      offer.direction !== 'AGENT_PROVIDES_USD' ||
      !offer.active ||
      offer.agent_status !== 'ACTIVE' ||
      !offer.can_provide_usd
    ) {
      return res.status(404).json({ error: 'That rate offer is no longer available' });
    }
    if (amountUsd < Number(offer.min_usd) || amountUsd > Number(offer.max_usd)) {
      return res.status(400).json({
        error: `This agent accepts $${offer.min_usd}-$${offer.max_usd} — enter an amount in that range`,
      });
    }
    if (offer.agent_user_id === req.userId) {
      return res.status(400).json({ error: "You can't buy from your own agent offer" });
    }

    const limit = await compliance.checkUserLimit(pool, req.userId, amountUsd, 'USD top-up via agent');
    if (!limit.allowed) {
      return res.status(403).json({ error: 'This order requires compliance review' });
    }

    await client.query('BEGIN');
    const escrowed = await client.query(
      `UPDATE users SET usd_balance = usd_balance - $1
        WHERE id = $2 AND usd_balance >= $1
        RETURNING usd_balance`,
      [amountUsd, offer.agent_user_id],
    );
    if (escrowed.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This agent no longer has enough USD available — try another offer' });
    }

    const lockedRate = Number(offer.rate_kes_per_usd);
    const amountKes = Number((amountUsd * lockedRate).toFixed(2));
    const inserted = await client.query(
      `INSERT INTO agent_usd_topup_orders
        (customer_id, agent_id, agent_fx_offer_id, amount_usd, amount_kes, locked_rate_kes_per_usd)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING *`,
      [req.userId, offer.agent_id, offer.id, amountUsd, amountKes, lockedRate],
    );
    await client.query('COMMIT');
    res.status(201).json({
      order: inserted.rows[0],
      agent: { businessName: offer.business_name, agentCode: offer.agent_code, phone: offer.phone },
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /usd-topup/orders/mine — the customer's own order history. */
router.get('/orders/mine', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT o.*, a.business_name AS agent_name, a.agent_code, a.phone AS agent_phone
         FROM agent_usd_topup_orders o
         JOIN agents a ON a.id = o.agent_id
        WHERE o.customer_id = $1
        ORDER BY o.created_at DESC
        LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** GET /usd-topup/orders/assigned — orders assigned to the caller's agent profile. */
router.get('/orders/assigned', async (req, res, next) => {
  try {
    const agent = await ownAgentRow(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });
    const status = String(req.query.status || '').trim().toUpperCase();
    const params = [agent.id];
    let where = 'WHERE o.agent_id = $1';
    if (status) {
      where += ' AND o.status = $2';
      params.push(status);
    }
    const rows = await pool.query(
      `SELECT o.*, u.full_name AS customer_name, u.email AS customer_email
         FROM agent_usd_topup_orders o
         JOIN users u ON u.id = o.customer_id
         ${where}
        ORDER BY o.created_at DESC
        LIMIT 100`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** Resolves the order and checks the caller is either the customer or the
 * assigned agent's owner — shared by the detail/chat routes below. */
async function loadAuthorizedOrder(client, orderId, userId) {
  const order = (
    await client.query(
      `SELECT o.*, a.business_name AS agent_name, a.agent_code, a.phone AS agent_phone,
              a.user_id AS agent_user_id, u.full_name AS customer_name
         FROM agent_usd_topup_orders o
         JOIN agents a ON a.id = o.agent_id
         JOIN users u ON u.id = o.customer_id
        WHERE o.id = $1`,
      [orderId],
    )
  ).rows[0];
  if (!order) return { order: null, authorized: false };
  return { order, authorized: order.customer_id === userId || order.agent_user_id === userId };
}

/** GET /usd-topup/orders/:id — detail view, visible to the customer or the assigned agent. */
router.get('/orders/:id', async (req, res, next) => {
  try {
    const { order, authorized } = await loadAuthorizedOrder(pool, req.params.id, req.userId);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (!authorized) return res.status(403).json({ error: 'Not your order' });
    res.json(order);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /usd-topup/orders/:id/messages — the order's chat, visible to the
 * customer or the assigned agent (Binance-style: buyer and seller can
 * message each other while an order is open, e.g. to coordinate payment
 * details or share extra proof).
 */
router.get('/orders/:id/messages', async (req, res, next) => {
  try {
    const { order, authorized } = await loadAuthorizedOrder(pool, req.params.id, req.userId);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (!authorized) return res.status(403).json({ error: 'Not your order' });
    const rows = await pool.query(
      `SELECT m.id, m.sender_id, m.body, m.created_at,
              (m.sender_id = $2) AS from_me
         FROM agent_usd_topup_order_messages m
        WHERE m.order_id = $1
        ORDER BY m.created_at ASC
        LIMIT 500`,
      [req.params.id, req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /usd-topup/orders/:id/messages { body } — send a chat message on this order. */
router.post('/orders/:id/messages', async (req, res, next) => {
  try {
    const body = String(req.body?.body || '').trim();
    if (!body) return res.status(400).json({ error: 'Message body is required' });
    if (body.length > 2000) return res.status(400).json({ error: 'Message is too long' });

    const { order, authorized } = await loadAuthorizedOrder(pool, req.params.id, req.userId);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (!authorized) return res.status(403).json({ error: 'Not your order' });

    const inserted = await pool.query(
      `INSERT INTO agent_usd_topup_order_messages (order_id, sender_id, body)
       VALUES ($1,$2,$3)
       RETURNING id, sender_id, body, created_at`,
      [req.params.id, req.userId, body],
    );

    const recipientId = order.customer_id === req.userId ? order.agent_user_id : order.customer_id;
    notify.notifyUser(recipientId, {
      title: 'New order message',
      body: body.length > 120 ? `${body.slice(0, 117)}...` : body,
    });

    res.status(201).json({ ...inserted.rows[0], from_me: true });
  } catch (err) {
    next(err);
  }
});

/** POST /usd-topup/orders/:id/proof { proofImage, reference } — customer uploads payment proof. */
router.post('/orders/:id/proof', async (req, res, next) => {
  try {
    const proofImage = String(req.body?.proofImage || '').trim();
    const reference = String(req.body?.reference || '').trim() || null;
    if (!proofImage) return res.status(400).json({ error: 'proofImage is required' });

    const updated = await pool.query(
      `UPDATE agent_usd_topup_orders
          SET status = 'PROOF_SUBMITTED', payment_proof = $1, payment_reference = $2, updated_at = now()
        WHERE id = $3 AND customer_id = $4 AND status IN ('PENDING_PAYMENT','REJECTED')
        RETURNING *`,
      [proofImage, reference, req.params.id, req.userId],
    );
    if (updated.rows.length === 0) {
      return res.status(409).json({ error: 'Order not found or not awaiting proof' });
    }
    res.json({ order: updated.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** Refunds an order's escrowed USD back to the agent-owner and marks it
 * terminal — shared by cancel (customer-initiated) and reject
 * (agent-initiated). */
async function refundEscrow(client, order, status, adminNote) {
  await client.query('UPDATE users SET usd_balance = usd_balance + $1 WHERE id = $2', [
    order.amount_usd,
    order.agent_user_id,
  ]);
  const updated = await client.query(
    `UPDATE agent_usd_topup_orders SET status = $1, admin_note = $2, updated_at = now() WHERE id = $3 RETURNING *`,
    [status, adminNote, order.id],
  );
  return updated.rows[0];
}

/** POST /usd-topup/orders/:id/cancel — customer cancels before release; the
 * agent's escrowed USD is refunded to them. */
router.post('/orders/:id/cancel', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const order = (
      await client.query(
        `SELECT o.*, a.user_id AS agent_user_id FROM agent_usd_topup_orders o
           JOIN agents a ON a.id = o.agent_id
          WHERE o.id = $1 AND o.customer_id = $2 AND o.status IN ('PENDING_PAYMENT','PROOF_SUBMITTED')
          FOR UPDATE`,
        [req.params.id, req.userId],
      )
    ).rows[0];
    if (!order) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Order not found or already settled' });
    }
    const updated = await refundEscrow(client, order, 'CANCELLED', null);
    await client.query('COMMIT');
    res.json({ order: updated });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/**
 * POST /usd-topup/orders/:id/confirm — agent confirms the KES was received
 * and releases the already-escrowed USD to the customer. The balance check
 * happened at order creation, not here — this just moves funds that are
 * already reserved.
 */
router.post('/orders/:id/confirm', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const agent = await ownAgentRow(client, req.userId);
    if (!agent || agent.status !== 'ACTIVE' || !agent.can_provide_usd) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent for this product' });
    }
    const order = (
      await client.query(
        `SELECT * FROM agent_usd_topup_orders WHERE id = $1 AND agent_id = $2 FOR UPDATE`,
        [req.params.id, agent.id],
      )
    ).rows[0];
    if (!order) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Order not found' });
    }
    if (order.status !== 'PROOF_SUBMITTED') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Order is ${order.status}, not awaiting confirmation` });
    }

    const amountUsd = Number(order.amount_usd);
    await client.query('UPDATE users SET usd_balance = usd_balance + $1 WHERE id = $2', [
      amountUsd,
      order.customer_id,
    ]);
    await client.query(
      `UPDATE agent_usd_topup_orders SET status = 'RELEASED', updated_at = now() WHERE id = $1`,
      [order.id],
    );
    await ledger.postWithClient(
      client,
      order.customer_id,
      { title: `USD top-up via ${agent.business_name}`, rail: 'Agent FX' },
      [
        { accountName: 'Agent payout clearing', direction: 'debit', amountUsd, memo: agent.agent_code },
        { accountName: 'Customer USD wallet', direction: 'credit', amountUsd, memo: `+${amountUsd} USD` },
      ],
    );
    await client.query('COMMIT');

    notify.notifyUser(order.customer_id, {
      title: 'USD credited',
      body: `$${amountUsd.toFixed(2)} has been added to your wallet by an agent.`,
    });

    res.json({ released: true, orderId: order.id, amountUsd });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /usd-topup/orders/:id/reject { note } — agent rejects invalid/missing
 * payment proof; the escrowed USD is refunded to them (customer can resubmit
 * proof, which re-opens the same escrowed order rather than requiring a new one). */
router.post('/orders/:id/reject', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const note = String(req.body?.note || '').trim();
    const agent = await ownAgentRow(client, req.userId);
    if (!agent) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not registered as an agent' });
    }
    const order = (
      await client.query(
        `SELECT o.*, a.user_id AS agent_user_id FROM agent_usd_topup_orders o
           JOIN agents a ON a.id = o.agent_id
          WHERE o.id = $1 AND o.agent_id = $2 AND o.status = 'PROOF_SUBMITTED'
          FOR UPDATE`,
        [req.params.id, agent.id],
      )
    ).rows[0];
    if (!order) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Order not found or not awaiting confirmation' });
    }
    const updated = await refundEscrow(client, order, 'REJECTED', note || null);
    await client.query('COMMIT');
    res.json({ order: updated });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
