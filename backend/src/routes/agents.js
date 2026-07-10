const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');

const router = express.Router();
router.use(requireAuth);

// Flat commission rates — placeholder until real commission-tier config exists.
const DEPOSIT_COMMISSION_RATE = 0.01;
const WITHDRAWAL_COMMISSION_RATE = 0.01;

function cleanCurrency(value) {
  const currency = String(value || 'KES').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw new Error('currency must be KES or USD');
  return currency;
}

function balanceColumn(currency) {
  return currency === 'KES' ? 'kes_balance' : 'usd_balance';
}

function agentCode() {
  return `AG${Math.floor(100000 + Math.random() * 900000)}`;
}

async function findCustomer(client, identifier) {
  const value = String(identifier || '').trim();
  if (!value) return null;
  const rows = await client.query(
    `SELECT id, full_name, kes_balance, usd_balance FROM users
      WHERE LOWER(email) = LOWER($1) OR phone = $1
      LIMIT 1`,
    [value],
  );
  return rows.rows[0] || null;
}

// commission_balance is tracked in USD (the ledger's normalizing currency);
// the agent_commissions row keeps the original currency/amount for display.
async function creditCommission(client, agentId, kind, currency, amount, relatedUserId) {
  const amountUsd = compliance.toUsd(amount, currency);
  await client.query(
    `UPDATE agents SET commission_balance = commission_balance + $1 WHERE id = $2`,
    [amountUsd, agentId],
  );
  await client.query(
    `INSERT INTO agent_commissions (agent_id, kind, currency, amount, related_user_id)
     VALUES ($1,$2,$3,$4,$5)`,
    [agentId, kind, currency, amount, relatedUserId],
  );
}

async function requireOwnAgent(client, userId) {
  const rows = await client.query('SELECT * FROM agents WHERE user_id = $1', [userId]);
  return rows.rows[0] || null;
}

router.get('/me', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    res.json({ agent });
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const businessName = String(req.body?.businessName || '').trim();
    const phone = String(req.body?.phone || '').trim() || null;
    if (!businessName) return res.status(400).json({ error: 'Business name is required' });

    const existing = await requireOwnAgent(pool, req.userId);
    if (existing) return res.status(409).json({ error: 'You are already registered as an agent' });

    const inserted = await pool.query(
      `INSERT INTO agents (user_id, business_name, agent_code, phone)
       VALUES ($1,$2,$3,$4)
       RETURNING *`,
      [req.userId, businessName, agentCode(), phone],
    );
    res.status(201).json({ agent: inserted.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/commissions', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `SELECT c.*, u.full_name AS related_user_name
         FROM agent_commissions c
         LEFT JOIN users u ON u.id = c.related_user_id
        WHERE c.agent_id = $1
        ORDER BY c.created_at DESC
        LIMIT 50`,
      [agent.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /agents/deposits — agent hands the customer cash, system credits their wallet. */
router.post('/deposits', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }

    await client.query('BEGIN');
    const agent = await requireOwnAgent(client, req.userId);
    if (!agent || agent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent' });
    }
    const customer = await findCustomer(client, req.body?.customer);
    if (!customer) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Customer not found' });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const limit = await compliance.checkUserLimit(
      client,
      customer.id,
      amountUsd,
      `Agent-assisted ${currency} deposit`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Deposit requires compliance review' });
    }

    const column = balanceColumn(currency);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      amount,
      customer.id,
    ]);
    await ledger.postWithClient(
      client,
      customer.id,
      { title: `Agent cash-in via ${agent.business_name}`, rail: 'Agent' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'credit', amountUsd, memo: agent.agent_code },
        { accountName: 'Agent float clearing', direction: 'debit', amountUsd, memo: agent.agent_code },
      ],
    );

    const commissionAmount = amount * DEPOSIT_COMMISSION_RATE;
    await creditCommission(client, agent.id, 'deposit', currency, commissionAmount, customer.id);

    await client.query('COMMIT');
    res.status(201).json({
      credited: { customerId: customer.id, customerName: customer.full_name, currency, amount },
      commission: { currency, amount: commissionAmount },
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /agents/withdrawals — agent hands the customer cash, system debits their wallet. */
router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }

    await client.query('BEGIN');
    const agent = await requireOwnAgent(client, req.userId);
    if (!agent || agent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent' });
    }
    const customer = await findCustomer(client, req.body?.customer);
    if (!customer) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Customer not found' });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const limit = await compliance.checkUserLimit(
      client,
      customer.id,
      amountUsd,
      `Agent-assisted ${currency} withdrawal`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Withdrawal requires compliance review' });
    }

    const column = balanceColumn(currency);
    const balanceRow = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        customer.id,
      ])
    ).rows[0];
    if (Number(balanceRow.balance) < amount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Customer does not have enough ${currency} balance` });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      amount,
      customer.id,
    ]);
    await ledger.postWithClient(
      client,
      customer.id,
      { title: `Agent cash-out via ${agent.business_name}`, rail: 'Agent' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd, memo: agent.agent_code },
        { accountName: 'Agent float clearing', direction: 'credit', amountUsd, memo: agent.agent_code },
      ],
    );

    const commissionAmount = amount * WITHDRAWAL_COMMISSION_RATE;
    await creditCommission(client, agent.id, 'withdrawal', currency, commissionAmount, customer.id);

    await client.query('COMMIT');
    res.status(201).json({
      debited: { customerId: customer.id, customerName: customer.full_name, currency, amount },
      commission: { currency, amount: commissionAmount },
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
