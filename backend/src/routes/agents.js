const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const pricing = require('../services/pricing');
const { creditAgentCommission } = require('../services/commission');
const { RECRUIT_TIER, CAN_TRANSACT, TIER_LIMITS_USD } = require('../services/agentTiers');
const notify = require('../services/notify');

const router = express.Router();
router.use(requireAuth);

// Deposits are free to the customer (M-Pesa's "All Deposits FREE" policy) —
// this is a flat Wayaki-funded incentive to reward agents for deposit
// volume, not a cut of a customer fee.
const DEPOSIT_COMMISSION_RATE = 0.01;

// Withdrawals charge the customer the tiered fee in services/pricing.js
// (mirrors M-Pesa's agent-withdrawal tariff). The agent keeps the bulk of
// that fee for doing the cash handling; Wayaki keeps the rest.
const { WITHDRAWAL_AGENT_FEE_SHARE } = pricing;

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

async function requireOwnAgent(client, userId) {
  const rows = await client.query('SELECT * FROM agents WHERE user_id = $1', [userId]);
  return rows.rows[0] || null;
}

/**
 * Resolves who req.userId is acting as for a deposit/withdrawal: the
 * agent's owner, or an ACTIVE cashier scoped to that specific agent.
 * When agentId is omitted, falls back to "my own agent" — the original
 * owner-only behavior, unchanged for anyone not using cashiers.
 */
async function resolveActingAgent(client, userId, agentId) {
  if (!agentId) {
    const owned = await requireOwnAgent(client, userId);
    return owned ? { agent: owned, role: 'OWNER' } : null;
  }
  const owned = (
    await client.query('SELECT * FROM agents WHERE id = $1 AND user_id = $2', [agentId, userId])
  ).rows[0];
  if (owned) return { agent: owned, role: 'OWNER' };

  const cashier = (
    await client.query(
      `SELECT a.* FROM agents a
         JOIN agent_staff s ON s.agent_id = a.id
        WHERE a.id = $1 AND s.user_id = $2 AND s.status = 'ACTIVE'`,
      [agentId, userId],
    )
  ).rows[0];
  return cashier ? { agent: cashier, role: 'CASHIER' } : null;
}

/**
 * Finds who a new Agent-tier application should be routed to: an ACTIVE
 * Super Agent covering that exact region if one exists, else any ACTIVE
 * Super Agent in the country, else that country's Country Agent, else null
 * (meaning no sponsor exists yet — falls to the Wayaki admin queue).
 */
async function findSponsorForLocation(client, countryCode, region) {
  if (region) {
    const regional = await client.query(
      `SELECT * FROM agents WHERE tier = 'SUPER_AGENT' AND status = 'ACTIVE'
        AND country_code = $1 AND region = $2 LIMIT 1`,
      [countryCode, region],
    );
    if (regional.rows[0]) return regional.rows[0];
  }
  const anySuper = await client.query(
    `SELECT * FROM agents WHERE tier = 'SUPER_AGENT' AND status = 'ACTIVE'
      AND country_code = $1 LIMIT 1`,
    [countryCode],
  );
  if (anySuper.rows[0]) return anySuper.rows[0];

  const countryAgent = await client.query(
    `SELECT * FROM agents WHERE tier = 'COUNTRY_AGENT' AND status = 'ACTIVE'
      AND country_code = $1 LIMIT 1`,
    [countryCode],
  );
  return countryAgent.rows[0] || null;
}

router.get('/me', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    res.json({ agent });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /agents — self-serve "become an agent". Every Wayaki user can apply,
 * but only once they're fully verified (agents handle other people's cash).
 * The app shares the applicant's location; we resolve the right sponsor
 * (Super Agent for that area, or the country's Country Agent, or nobody yet)
 * and the application sits at PENDING_REVIEW until that sponsor — or admin,
 * if no sponsor exists in that location — approves it via /applications.
 */
router.post('/', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const businessName = String(req.body?.businessName || '').trim();
    const phone = String(req.body?.phone || '').trim() || null;
    const countryCode = String(req.body?.countryCode || '').trim().toUpperCase();
    const region = String(req.body?.region || '').trim() || null;
    const city = String(req.body?.city || '').trim() || null;
    // What the applicant is asking to offer — reviewed and granted (or not)
    // by whoever approves the application; see can_provide_kes/usd below.
    const wantsProvideKes = req.body?.wantsProvideKes !== false;
    const wantsProvideUsd = req.body?.wantsProvideUsd === true;
    if (!businessName) return res.status(400).json({ error: 'Business name is required' });
    if (!/^[A-Z]{2}$/.test(countryCode)) {
      return res.status(400).json({ error: 'Share your location — a valid 2-letter countryCode is required' });
    }
    if (!wantsProvideKes && !wantsProvideUsd) {
      return res.status(400).json({ error: 'Choose at least one product to offer' });
    }

    await client.query('BEGIN');
    const user = (
      await client.query('SELECT email_verified, phone_verified, kyc_tier FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (!user.email_verified || !user.phone_verified || Number(user.kyc_tier) < 2) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        error: 'Verify your email and phone and complete KYC before applying to become an agent',
      });
    }

    const existing = await requireOwnAgent(client, req.userId);
    if (existing) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'You are already registered as an agent' });
    }

    const sponsor = await findSponsorForLocation(client, countryCode, region);
    const limits = TIER_LIMITS_USD.AGENT;
    const inserted = await client.query(
      `INSERT INTO agents
        (user_id, business_name, agent_code, phone, status, tier, parent_agent_id,
         country_code, region, city, min_float_usd, daily_limit_usd,
         wants_provide_kes, wants_provide_usd)
       VALUES ($1,$2,$3,$4,'PENDING_REVIEW','AGENT',$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING *`,
      [
        req.userId, businessName, agentCode(), phone, sponsor?.id || null,
        countryCode, region, city, limits.minFloatUsd, limits.dailyLimitUsd,
        wantsProvideKes, wantsProvideUsd,
      ],
    );
    await client.query('COMMIT');
    res.status(201).json({
      agent: inserted.rows[0],
      routedTo: sponsor
        ? { tier: sponsor.tier, businessName: sponsor.business_name, agentCode: sponsor.agent_code }
        : { tier: 'WAYAKI_ADMIN', businessName: 'Wayaki platform team' },
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /agents/recruit — an active Agent/Super Agent onboards a subordinate. */
router.post('/recruit', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const businessName = String(req.body?.businessName || '').trim();
    const phone = String(req.body?.phone || '').trim() || null;
    if (!businessName) {
      return res.status(400).json({ error: 'Business name is required' });
    }

    await client.query('BEGIN');
    const parent = await requireOwnAgent(client, req.userId);
    if (!parent || parent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent' });
    }
    const childTier = RECRUIT_TIER[parent.tier];
    if (!childTier) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Sub-agents cannot recruit further' });
    }

    const user = await findCustomer(client, req.body?.identifier);
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No user found with that email or phone' });
    }
    const existing = await requireOwnAgent(client, user.id);
    if (existing) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This user is already registered as an agent' });
    }

    // Recruited tiers are auto-active — same convenience as Safaricom's
    // aggregated-line onboarding, where the principal vets the recruit and
    // Safaricom doesn't re-review each one; admins retain deactivate power.
    const inserted = await client.query(
      `INSERT INTO agents
        (user_id, business_name, agent_code, phone, status, tier, parent_agent_id, approved_by, approved_at)
       VALUES ($1,$2,$3,$4,'ACTIVE',$5,$6,$7,now())
       RETURNING *`,
      [user.id, businessName, agentCode(), phone, childTier, parent.id, req.userId],
    );
    await client.query('COMMIT');
    res.status(201).json({ agent: inserted.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /agents/network — the caller's own recruits + override earnings. */
router.get('/network', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });

    const recruits = await pool.query(
      `SELECT a.*, u.full_name AS owner_name, u.email AS owner_email
         FROM agents a
         JOIN users u ON u.id = a.user_id
        WHERE a.parent_agent_id = $1
        ORDER BY a.created_at DESC`,
      [agent.id],
    );
    const overrideRows = await pool.query(
      `SELECT amount, currency FROM agent_commissions WHERE agent_id = $1 AND kind = 'override'`,
      [agent.id],
    );
    const overrideEarnedUsd = overrideRows.rows.reduce(
      (sum, row) => sum + compliance.toUsd(Number(row.amount), row.currency),
      0,
    );
    res.json({
      recruits: recruits.rows,
      canRecruit: Boolean(RECRUIT_TIER[agent.tier]),
      recruitTier: RECRUIT_TIER[agent.tier] || null,
      overrideEarnedUsd: Number(overrideEarnedUsd.toFixed(2)),
    });
  } catch (err) {
    next(err);
  }
});

/** GET /agents/applications — pending Agent-tier applications routed to me for review. */
router.get('/applications', async (req, res, next) => {
  try {
    const me = await requireOwnAgent(pool, req.userId);
    if (!me) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `SELECT a.*, u.full_name AS owner_name, u.email AS owner_email, u.phone AS owner_phone
         FROM agents a
         JOIN users u ON u.id = a.user_id
        WHERE a.parent_agent_id = $1 AND a.status = 'PENDING_REVIEW'
        ORDER BY a.created_at`,
      [me.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /agents/applications/:id/approve — sponsor approves an application
 * routed to them, granting exactly the products the applicant requested
 * (wants_provide_kes/usd). A sponsor greenlights that this applicant should
 * operate at all; which specific products stay enabled afterward is Wayaki
 * admin's ongoing call via PUT /admin/agents/:id/capabilities.
 */
router.post('/applications/:id/approve', async (req, res, next) => {
  try {
    const me = await requireOwnAgent(pool, req.userId);
    if (!me) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `UPDATE agents
          SET status = 'ACTIVE', approved_by = $1, approved_at = now(),
              can_provide_kes = wants_provide_kes, can_provide_usd = wants_provide_usd
        WHERE id = $2 AND parent_agent_id = $3 AND status = 'PENDING_REVIEW'
        RETURNING *`,
      [req.userId, req.params.id, me.id],
    );
    if (rows.rows.length === 0) {
      return res.status(404).json({ error: 'No matching pending application found' });
    }
    res.json({ agent: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** POST /agents/applications/:id/reject — sponsor rejects an application routed to them. */
router.post('/applications/:id/reject', async (req, res, next) => {
  try {
    const me = await requireOwnAgent(pool, req.userId);
    if (!me) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `UPDATE agents SET status = 'REJECTED'
        WHERE id = $1 AND parent_agent_id = $2 AND status = 'PENDING_REVIEW'
        RETURNING *`,
      [req.params.id, me.id],
    );
    if (rows.rows.length === 0) {
      return res.status(404).json({ error: 'No matching pending application found' });
    }
    res.json({ agent: rows.rows[0] });
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

/** POST /agents/staff — owner adds a cashier to their own agent, scoped to deposit/withdraw only. */
router.post('/staff', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const agent = await requireOwnAgent(client, req.userId);
    if (!agent) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not registered as an agent' });
    }
    const user = await findCustomer(client, req.body?.identifier);
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No user found with that email or phone' });
    }
    const inserted = await client.query(
      `INSERT INTO agent_staff (agent_id, user_id, added_by)
       VALUES ($1,$2,$3)
       ON CONFLICT (agent_id, user_id) DO UPDATE SET status = 'ACTIVE'
       RETURNING *`,
      [agent.id, user.id, req.userId],
    );
    await client.query('COMMIT');
    res.status(201).json({ cashier: inserted.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /agents/staff — owner lists their cashiers. */
router.get('/staff', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `SELECT s.*, u.full_name, u.email, u.phone
         FROM agent_staff s
         JOIN users u ON u.id = s.user_id
        WHERE s.agent_id = $1
        ORDER BY s.created_at DESC`,
      [agent.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /agents/staff/:staffId/remove — owner deactivates a cashier. */
router.post('/staff/:staffId/remove', async (req, res, next) => {
  try {
    const agent = await requireOwnAgent(pool, req.userId);
    if (!agent) return res.status(404).json({ error: 'You are not registered as an agent' });
    const rows = await pool.query(
      `UPDATE agent_staff SET status = 'SUSPENDED' WHERE id = $1 AND agent_id = $2 RETURNING *`,
      [req.params.staffId, agent.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Cashier not found' });
    res.json({ cashier: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** GET /agents/cashier-of — agents I've been added as a cashier for. */
router.get('/cashier-of', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT a.id, a.business_name, a.agent_code, a.tier, a.status AS agent_status, s.status AS staff_status
         FROM agent_staff s
         JOIN agents a ON a.id = s.agent_id
        WHERE s.user_id = $1
        ORDER BY s.created_at DESC`,
      [req.userId],
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

    const agentId = req.body?.agentId ? String(req.body.agentId).trim() : null;

    await client.query('BEGIN');
    const acting = await resolveActingAgent(client, req.userId, agentId);
    if (!acting || acting.agent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }
    const agent = acting.agent;
    if (!CAN_TRANSACT[agent.tier]) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        error: `${agent.tier === 'COUNTRY_AGENT' ? 'Country Agents' : 'Super Agents'} manage their network's float and don't serve customers directly`,
      });
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
    await creditAgentCommission(client, agent, 'deposit', currency, commissionAmount, customer.id);

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

/**
 * POST /agents/withdrawals — agent hands the customer cash, system debits
 * their wallet for the withdrawal PLUS the tiered agent-withdrawal fee (see
 * services/pricing.js) — same convention M-Pesa uses: the customer receives
 * the full cash amount, and the fee is an additional deduction from their
 * account. The agent keeps most of that fee (WITHDRAWAL_AGENT_FEE_SHARE);
 * the remainder is Wayaki's take, credited implicitly via the "Withdrawal
 * fee revenue" ledger leg below (not paid out to any agent).
 */
router.post('/withdrawals', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }

    let fee;
    try {
      fee = pricing.withdrawalFee(amount, currency);
    } catch (err) {
      return res.status(400).json({ error: err.message });
    }
    const totalDebit = amount + fee;
    const agentId = req.body?.agentId ? String(req.body.agentId).trim() : null;

    await client.query('BEGIN');
    const acting = await resolveActingAgent(client, req.userId, agentId);
    if (!acting || acting.agent.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }
    const agent = acting.agent;
    if (!CAN_TRANSACT[agent.tier]) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        error: `${agent.tier === 'COUNTRY_AGENT' ? 'Country Agents' : 'Super Agents'} manage their network's float and don't serve customers directly`,
      });
    }
    const customer = await findCustomer(client, req.body?.customer);
    if (!customer) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Customer not found' });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const feeUsd = compliance.toUsd(fee, currency);
    const totalUsd = amountUsd + feeUsd;
    const limit = await compliance.checkUserLimit(
      client,
      customer.id,
      totalUsd,
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
    if (Number(balanceRow.balance) < totalDebit) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: `Customer needs ${totalDebit} ${currency} (${amount} withdrawal + ${fee} fee) but only has ${balanceRow.balance}`,
      });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      totalDebit,
      customer.id,
    ]);
    await ledger.postWithClient(
      client,
      customer.id,
      { title: `Agent cash-out via ${agent.business_name}`, rail: 'Agent' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd: totalUsd, memo: agent.agent_code },
        { accountName: 'Agent float clearing', direction: 'credit', amountUsd, memo: agent.agent_code },
        { accountName: 'Withdrawal fee revenue', direction: 'credit', amountUsd: feeUsd, memo: agent.agent_code },
      ],
    );

    const commissionAmount = fee * WITHDRAWAL_AGENT_FEE_SHARE;
    await creditAgentCommission(client, agent, 'withdrawal', currency, commissionAmount, customer.id);

    await client.query('COMMIT');
    res.status(201).json({
      debited: { customerId: customer.id, customerName: customer.full_name, currency, amount, fee, total: totalDebit },
      commission: { currency, amount: commissionAmount },
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/**
 * M-Pesa/Till FX marketplace — agents post their own live KES-per-USD
 * rate (below is Wayaki's Paystack/market rate; the spread they set below
 * that is their margin) instead of Paystack ever being asked to fund a
 * USD-sourced M-Pesa/Till send (Stripe/Waafi money never reaches
 * Paystack's balance, so that was unreliable). Customers browse this list
 * (GET /mobile-money/fx-offers, routes/mobileMoney.js) and pick one; the
 * order is pre-assigned to that specific agent at creation, not dropped
 * into an anonymous pool. See routes/mobileMoney.js POST /withdrawals for
 * how orders get created against a locked-in rate.
 */

const DIRECTIONS = ['AGENT_PROVIDES_KES', 'AGENT_PROVIDES_USD'];
function capabilityFor(agent, direction) {
  return direction === 'AGENT_PROVIDES_USD' ? agent.can_provide_usd : agent.can_provide_kes;
}

/** GET /agents/fx-offer — the calling agent's own current rate offers, keyed
 * by direction ({ AGENT_PROVIDES_KES, AGENT_PROVIDES_USD }), null where not set. */
router.get('/fx-offer', async (req, res, next) => {
  try {
    const agentId = req.query?.agentId ? String(req.query.agentId).trim() : null;
    const acting = await resolveActingAgent(pool, req.userId, agentId);
    if (!acting) {
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }
    const rows = (
      await pool.query('SELECT * FROM agent_fx_offers WHERE agent_id = $1', [acting.agent.id])
    ).rows;
    const byDirection = { AGENT_PROVIDES_KES: null, AGENT_PROVIDES_USD: null };
    for (const row of rows) byDirection[row.direction] = row;
    res.json(byDirection);
  } catch (err) {
    next(err);
  }
});

/** PUT /agents/fx-offer { direction, rateKesPerUsd, minUsd, maxUsd, active }
 * — upsert the calling agent's rate for one direction. Only the agent owner
 * can set it (not cashiers) — this is a pricing/risk decision, not
 * day-to-day cash handling. Requires the direction to have been granted by
 * whoever approved the application (can_provide_kes/usd) — an agent can't
 * unilaterally light up a product nobody signed off on. */
router.put('/fx-offer', async (req, res, next) => {
  try {
    const owned = await requireOwnAgent(pool, req.userId);
    if (!owned || owned.status !== 'ACTIVE') {
      return res.status(404).json({ error: 'You are not an active agent' });
    }
    if (!CAN_TRANSACT[owned.tier]) {
      return res.status(403).json({
        error: `${owned.tier === 'COUNTRY_AGENT' ? 'Country Agents' : 'Super Agents'} manage their network's float and don't serve customers directly`,
      });
    }
    const direction = String(req.body?.direction || '').trim().toUpperCase();
    if (!DIRECTIONS.includes(direction)) {
      return res.status(400).json({ error: `direction must be one of ${DIRECTIONS.join(', ')}` });
    }
    if (!capabilityFor(owned, direction)) {
      return res.status(403).json({
        error:
          direction === 'AGENT_PROVIDES_USD'
            ? 'Providing USD is not enabled on your account yet — ask Wayaki admin to grant it'
            : 'Providing KES is not enabled on your account yet — ask Wayaki admin to grant it',
      });
    }
    const rate = Number(req.body?.rateKesPerUsd);
    const minUsd = Number(req.body?.minUsd ?? 1);
    const maxUsd = Number(req.body?.maxUsd ?? 1000);
    const active = req.body?.active !== false;
    if (!Number.isFinite(rate) || rate <= 0) {
      return res.status(400).json({ error: 'A positive rateKesPerUsd is required' });
    }
    if (!Number.isFinite(minUsd) || !Number.isFinite(maxUsd) || minUsd <= 0 || maxUsd < minUsd) {
      return res.status(400).json({ error: 'minUsd/maxUsd must be positive with max >= min' });
    }
    // Sanity guard: an agent fat-fingering a rate wildly off Wayaki's
    // reference rate (e.g. typing 1.29 instead of 129, or 12900) would
    // otherwise sit live in the marketplace and either scam customers or
    // bankrupt the agent's own float.
    const reference = config.kesPerUsd;
    if (rate < reference * 0.5 || rate > reference * 1.1) {
      return res.status(400).json({
        error: `Rate looks off — Wayaki's reference rate is ~${reference} KES/USD. Enter something close to (usually just under) that.`,
      });
    }

    const offer = await pool.query(
      `INSERT INTO agent_fx_offers (agent_id, direction, rate_kes_per_usd, min_usd, max_usd, active)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (agent_id, direction) DO UPDATE
         SET rate_kes_per_usd = $3, min_usd = $4, max_usd = $5, active = $6, updated_at = now()
       RETURNING *`,
      [owned.id, direction, rate, minUsd, maxUsd, active],
    );
    res.json(offer.rows[0]);
  } catch (err) {
    next(err);
  }
});

/** POST /agents/mobile-money-queue/:id/accept — the specific agent this
 * order was assigned to at creation confirms they'll fulfill it. */
router.post('/mobile-money-queue/:id/accept', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const agentId = req.body?.agentId ? String(req.body.agentId).trim() : null;
    const acting = await resolveActingAgent(client, req.userId, agentId);
    if (!acting || acting.agent.status !== 'ACTIVE') {
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }

    await client.query('BEGIN');
    const accepted = await client.query(
      `UPDATE mobile_money_movements
          SET status = 'AGENT_CLAIMED', claimed_at = now(), updated_at = now()
        WHERE id = $1 AND status = 'PENDING_AGENT' AND agent_id = $2
        RETURNING id, rail, phone, amount_kes, locked_rate_kes_per_usd, status, claimed_at`,
      [req.params.id, acting.agent.id],
    );
    if (accepted.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Not assigned to you, or no longer pending' });
    }
    await client.query('COMMIT');
    res.json({ accepted: accepted.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /agents/mobile-money-queue/:id/decline — the assigned agent can't
 * fulfill it; refunds the customer so they can pick a different offer,
 * rather than leaving it to sit unfulfilled or silently reassigning it. */
router.post('/mobile-money-queue/:id/decline', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const agentId = req.body?.agentId ? String(req.body.agentId).trim() : null;
    const acting = await resolveActingAgent(client, req.userId, agentId);
    if (!acting) {
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }

    await client.query('BEGIN');
    const movement = (
      await client.query(
        `SELECT * FROM mobile_money_movements
          WHERE id = $1 AND status IN ('PENDING_AGENT','AGENT_CLAIMED') AND agent_id = $2
          FOR UPDATE`,
        [req.params.id, acting.agent.id],
      )
    ).rows[0];
    if (!movement) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Not assigned to you, or already settled' });
    }

    const sourceCurrency = movement.source_currency || 'USD';
    const balanceColumn = sourceCurrency === 'USD' ? 'usd_balance' : 'kes_balance';
    const debitAmount = Number(movement.amount_kes) / Number(movement.locked_rate_kes_per_usd || config.kesPerUsd);
    await client.query(`UPDATE users SET ${balanceColumn} = ${balanceColumn} + $1 WHERE id = $2`, [
      debitAmount,
      movement.user_id,
    ]);
    const amountUsd = sourceCurrency === 'USD' ? debitAmount : debitAmount / config.kesPerUsd;
    await ledger.postWithClient(
      client,
      movement.user_id,
      { title: `${movement.rail} payout declined by agent`, rail: movement.rail },
      [
        { accountName: 'Agent payout clearing', direction: 'debit', amountUsd, memo: 'Declined by agent' },
        {
          accountName: `Customer ${sourceCurrency} wallet`,
          direction: 'credit',
          amountUsd,
          memo: `${debitAmount.toFixed(2)} ${sourceCurrency} released`,
        },
      ],
    );
    await client.query(
      `UPDATE mobile_money_movements
          SET status = 'FAILED', admin_note = 'Declined by agent', updated_at = now()
        WHERE id = $1`,
      [movement.id],
    );
    await client.query('COMMIT');

    notify.notifyUser(movement.user_id, {
      title: 'Payout declined',
      body: `The agent couldn't fulfill your ${movement.rail} request — your balance has been refunded. Try another agent's rate.`,
    });

    res.json({ declined: true });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** POST /agents/mobile-money-queue/:id/complete { reference } — the agent
 * confirms they've sent the real M-Pesa/Till payment. Settlement is a
 * direct swap: the customer's paid amount (already debited at request
 * time) credits the agent-owner's own USD balance — the agent's margin
 * was already baked into the rate they offered, not a separate fee. */
router.post('/mobile-money-queue/:id/complete', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const agentId = req.body?.agentId ? String(req.body.agentId).trim() : null;
    const reference = String(req.body?.reference || '').trim();
    if (!reference) {
      return res.status(400).json({ error: 'A reference (e.g. the M-Pesa confirmation code) is required' });
    }
    const acting = await resolveActingAgent(client, req.userId, agentId);
    if (!acting) {
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }

    await client.query('BEGIN');
    const movement = (
      await client.query(
        `SELECT * FROM mobile_money_movements
          WHERE id = $1 AND status = 'AGENT_CLAIMED' AND agent_id = $2
          FOR UPDATE`,
        [req.params.id, acting.agent.id],
      )
    ).rows[0];
    if (!movement) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Not currently accepted by you' });
    }

    await client.query(
      `UPDATE mobile_money_movements
          SET status = 'COMPLETED', agent_reference = $1, updated_at = now()
        WHERE id = $2`,
      [reference, movement.id],
    );

    // The customer paid in USD (this marketplace is USD-sourced by
    // design) — that amount becomes the agent-owner's own real balance in
    // exchange for the real KES they just sent.
    const settlementUsd = Number(movement.amount_kes) / Number(movement.locked_rate_kes_per_usd);
    await client.query('UPDATE users SET usd_balance = usd_balance + $1 WHERE id = $2', [
      settlementUsd,
      acting.agent.user_id,
    ]);
    await ledger.postWithClient(
      client,
      acting.agent.user_id,
      { title: `M-Pesa/Till FX fulfilled for customer`, rail: 'Agent FX' },
      [
        { accountName: 'Agent payout clearing', direction: 'debit', amountUsd: settlementUsd, memo: reference },
        { accountName: 'Customer USD wallet', direction: 'credit', amountUsd: settlementUsd, memo: reference },
      ],
    );
    await client.query('COMMIT');

    notify.notifyUser(movement.user_id, {
      title: movement.rail === 'M-Pesa Till' ? 'Till payment sent' : 'M-Pesa payment sent',
      body: `Your ${movement.amount_kes} KES ${movement.rail} payment has been sent by an agent.`,
    });

    res.json({ completed: true, settlement: { currency: 'USD', amount: settlementUsd } });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /agents/mobile-money-queue — orders currently assigned to the
 * calling agent (awaiting accept, or already accepted and being
 * fulfilled). Orders are pre-assigned to a specific agent at creation
 * (the customer picked their rate offer) — there's no open/unclaimed pool
 * to browse here anymore. */
router.get('/mobile-money-queue', async (req, res, next) => {
  try {
    const agentId = req.query?.agentId ? String(req.query.agentId).trim() : null;
    const acting = await resolveActingAgent(pool, req.userId, agentId);
    if (!acting || acting.agent.status !== 'ACTIVE') {
      return res.status(404).json({ error: 'You are not an active agent or cashier' });
    }
    const rows = await pool.query(
      `SELECT id, rail, phone, amount_kes, locked_rate_kes_per_usd, status,
              agent_id, claimed_at, created_at
         FROM mobile_money_movements
        WHERE agent_id = $1 AND status IN ('PENDING_AGENT','AGENT_CLAIMED')
        ORDER BY created_at ASC
        LIMIT 100`,
      [acting.agent.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
