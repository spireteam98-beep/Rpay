const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const exchange = require('../services/exchange');
const config = require('../config');

const router = express.Router();
router.use(requireAuth);

// Same flat rate as agent-assisted cash deposits — the agent earns a cut
// of the fiat leg for supplying the crypto float and doing the manual check.
const P2P_COMMISSION_RATE = 0.01;

function assetName(value) {
  const asset = String(value || '').toUpperCase();
  if (!exchange.SUPPORTED.includes(asset)) {
    return null;
  }
  return asset;
}

function fiatCurrency(value) {
  const currency = String(value || 'KES').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw new Error('fiatCurrency must be KES or USD');
  return currency;
}

async function ownAgentRow(client, userId) {
  const rows = await client.query('SELECT * FROM agents WHERE user_id = $1', [userId]);
  return rows.rows[0] || null;
}

/** GET /p2p/agents — active agents a customer can buy crypto from. */
router.get('/agents', async (_req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT a.id, a.business_name, a.agent_code, a.phone, u.full_name AS owner_name
         FROM agents a
         JOIN users u ON u.id = a.user_id
        WHERE a.status = 'ACTIVE'
        ORDER BY a.business_name
        LIMIT 100`,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /p2p/orders { agentId, asset, cryptoAmount, fiatCurrency } — customer opens a buy order. */
router.post('/orders', async (req, res, next) => {
  try {
    const agentId = String(req.body?.agentId || '').trim();
    const asset = assetName(req.body?.asset);
    const cryptoAmount = Number(req.body?.cryptoAmount);
    const currency = fiatCurrency(req.body?.fiatCurrency);
    if (!agentId) return res.status(400).json({ error: 'agentId is required' });
    if (!asset) return res.status(400).json({ error: `asset must be one of ${exchange.SUPPORTED.join(', ')}` });
    if (!Number.isFinite(cryptoAmount) || cryptoAmount <= 0) {
      return res.status(400).json({ error: 'Positive cryptoAmount is required' });
    }

    const agent = (
      await pool.query(`SELECT id FROM agents WHERE id = $1 AND status = 'ACTIVE'`, [agentId])
    ).rows[0];
    if (!agent) return res.status(404).json({ error: 'Agent not found or not active' });

    const priceUsd = await exchange.lastPrice(asset);
    const usdAmount = cryptoAmount * priceUsd;
    const limit = await compliance.checkUserLimit(
      pool,
      req.userId,
      usdAmount,
      `P2P buy ${asset}`,
    );
    if (!limit.allowed) {
      return res.status(403).json({ error: 'This order requires compliance review' });
    }

    const fiatAmount = currency === 'KES' ? usdAmount * config.kesPerUsd : usdAmount;

    const inserted = await pool.query(
      `INSERT INTO p2p_orders
        (customer_id, agent_id, asset, crypto_amount, fiat_currency, fiat_amount, rate_usd)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [req.userId, agentId, asset, cryptoAmount, currency, Number(fiatAmount.toFixed(2)), priceUsd],
    );
    const agentContact = (
      await pool.query(
        `SELECT a.business_name, a.agent_code, a.phone, u.full_name AS owner_name
           FROM agents a JOIN users u ON u.id = a.user_id WHERE a.id = $1`,
        [agentId],
      )
    ).rows[0];
    res.status(201).json({ order: inserted.rows[0], agent: agentContact });
  } catch (err) {
    next(err);
  }
});

/** GET /p2p/orders/mine — the customer's own order history. */
router.get('/orders/mine', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT o.*, a.business_name AS agent_name, a.agent_code, a.phone AS agent_phone
         FROM p2p_orders o
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

/** GET /p2p/orders/assigned — orders assigned to the caller's agent profile. */
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
         FROM p2p_orders o
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

/** GET /p2p/orders/:id — detail view, visible to the customer or the assigned agent. */
router.get('/orders/:id', async (req, res, next) => {
  try {
    const order = (
      await pool.query(
        `SELECT o.*, a.business_name AS agent_name, a.agent_code, a.phone AS agent_phone,
                a.user_id AS agent_user_id, u.full_name AS customer_name
           FROM p2p_orders o
           JOIN agents a ON a.id = o.agent_id
           JOIN users u ON u.id = o.customer_id
          WHERE o.id = $1`,
        [req.params.id],
      )
    ).rows[0];
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (order.customer_id !== req.userId && order.agent_user_id !== req.userId) {
      return res.status(403).json({ error: 'Not your order' });
    }
    res.json(order);
  } catch (err) {
    next(err);
  }
});

/** POST /p2p/orders/:id/proof { proofImage, reference } — customer uploads payment proof. */
router.post('/orders/:id/proof', async (req, res, next) => {
  try {
    const proofImage = String(req.body?.proofImage || '').trim();
    const reference = String(req.body?.reference || '').trim() || null;
    if (!proofImage) return res.status(400).json({ error: 'proofImage is required' });

    const updated = await pool.query(
      `UPDATE p2p_orders
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

/** POST /p2p/orders/:id/cancel — customer cancels before proof is reviewed. */
router.post('/orders/:id/cancel', async (req, res, next) => {
  try {
    const updated = await pool.query(
      `UPDATE p2p_orders
          SET status = 'CANCELLED', updated_at = now()
        WHERE id = $1 AND customer_id = $2 AND status IN ('PENDING_PAYMENT','PROOF_SUBMITTED')
        RETURNING *`,
      [req.params.id, req.userId],
    );
    if (updated.rows.length === 0) {
      return res.status(409).json({ error: 'Order not found or already settled' });
    }
    res.json({ order: updated.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** POST /p2p/orders/:id/confirm — agent confirms payment received, releases the crypto. */
router.post('/orders/:id/confirm', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const agent = await ownAgentRow(client, req.userId);
    if (!agent || agent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent' });
    }
    const order = (
      await client.query(
        `SELECT * FROM p2p_orders WHERE id = $1 AND agent_id = $2 FOR UPDATE`,
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

    await client.query(
      `INSERT INTO crypto_balances (user_id, asset, amount) VALUES ($1,$2,$3)
       ON CONFLICT (user_id, asset) DO UPDATE SET amount = crypto_balances.amount + $3`,
      [order.customer_id, order.asset, order.crypto_amount],
    );
    await client.query(
      `UPDATE p2p_orders SET status = 'RELEASED', updated_at = now() WHERE id = $1`,
      [order.id],
    );

    const usdAmount = Number(order.rate_usd) * Number(order.crypto_amount);
    await ledger.postWithClient(
      client,
      order.customer_id,
      { title: `P2P buy ${order.crypto_amount} ${order.asset} via ${agent.business_name}`, rail: 'P2P' },
      [
        { accountName: 'Agent crypto float clearing', direction: 'debit', amountUsd: usdAmount, memo: agent.agent_code },
        { accountName: 'Customer crypto liability', direction: 'credit', amountUsd: usdAmount, memo: `+${order.crypto_amount} ${order.asset}` },
      ],
    );

    const commissionAmount = Number(order.fiat_amount) * P2P_COMMISSION_RATE;
    const commissionUsd = compliance.toUsd(commissionAmount, order.fiat_currency);
    await client.query(
      `UPDATE agents SET commission_balance = commission_balance + $1 WHERE id = $2`,
      [commissionUsd, agent.id],
    );
    await client.query(
      `INSERT INTO agent_commissions (agent_id, kind, currency, amount, related_user_id)
       VALUES ($1,'p2p',$2,$3,$4)`,
      [agent.id, order.fiat_currency, commissionAmount, order.customer_id],
    );

    await client.query('COMMIT');
    res.json({ released: true, orderId: order.id, asset: order.asset, cryptoAmount: order.crypto_amount });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /p2p/orders/:id/reject { note } — agent rejects invalid/missing payment proof. */
router.post('/orders/:id/reject', async (req, res, next) => {
  try {
    const note = String(req.body?.note || '').trim();
    const agent = await ownAgentRow(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });

    const updated = await pool.query(
      `UPDATE p2p_orders
          SET status = 'REJECTED', admin_note = $1, updated_at = now()
        WHERE id = $2 AND agent_id = $3 AND status = 'PROOF_SUBMITTED'
        RETURNING *`,
      [note || null, req.params.id, agent.id],
    );
    if (updated.rows.length === 0) {
      return res.status(409).json({ error: 'Order not found or not awaiting confirmation' });
    }
    res.json({ order: updated.rows[0] });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
