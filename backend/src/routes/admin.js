const express = require('express');
const { pool } = require('../db');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const exchange = require('../services/exchange');
const compliance = require('../services/compliance');
const { creditAgentCommission } = require('../services/commission');
const { payoutToMpesa } = require('../services/paystackTransfers');

// Flat commissions for onboarding events that aren't sized by transaction
// amount — customer onboarding ($1) already existed in auth.js; merchant
// onboarding pays more since a merchant drives recurring transaction volume.
// card_issuance is plumbed in ahead of the Wayaki Card feature shipping.
const MERCHANT_ONBOARDING_COMMISSION_USD = 5;

const router = express.Router();
router.use(requireAuth, requireAdmin);

router.get('/exchange/status', async (_req, res, next) => {
  try {
    const [ping, account] = await Promise.all([
      exchange.publicPing(),
      exchange.accountSnapshot(),
    ]);
    res.json({
      publicApi: ping,
      account,
      supportedAssets: exchange.SUPPORTED,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/overview', async (_req, res, next) => {
  try {
    const [users, pendingDeposits, pendingWithdrawals, amlCases, merchants] = await Promise.all([
      pool.query('SELECT COUNT(*)::int AS count FROM users'),
      pool.query(
        `SELECT COUNT(*)::int AS count
           FROM mobile_money_movements
          WHERE type = 'DEPOSIT' AND status = 'PENDING_ADMIN'`,
      ),
      pool.query(
        `SELECT COUNT(*)::int AS count
           FROM mobile_money_movements
          WHERE type = 'WITHDRAWAL' AND status = 'PENDING_PAYOUT'`,
      ),
      pool.query("SELECT COUNT(*)::int AS count FROM aml_cases WHERE status = 'Open'"),
      pool.query("SELECT COUNT(*)::int AS count FROM merchants WHERE status = 'ACTIVE'"),
    ]);

    res.json({
      users: users.rows[0].count,
      pendingDeposits: pendingDeposits.rows[0].count,
      pendingWithdrawals: pendingWithdrawals.rows[0].count,
      openAmlCases: amlCases.rows[0].count,
      activeMerchants: merchants.rows[0].count,
      kesPerUsd: config.kesPerUsd,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /admin/sessions — login/logout timeline plus which users currently
 * look "logged in". JWTs aren't revoked server-side, so "open" here just
 * means the user's most recent recorded event was a login with no later
 * logout — not a cryptographic guarantee their token is actually still in
 * use (they may have just closed the tab).
 */
router.get('/sessions', async (req, res, next) => {
  try {
    const [recentEvents, openSessions] = await Promise.all([
      pool.query(
        `SELECT e.id, e.user_id, e.event_type, e.method, e.ip_address, e.user_agent, e.created_at,
                u.full_name, u.email
           FROM login_events e
           LEFT JOIN users u ON u.id = e.user_id
          ORDER BY e.created_at DESC
          LIMIT 300`,
      ),
      pool.query(
        `WITH latest AS (
           SELECT DISTINCT ON (user_id) user_id, event_type, method, created_at
             FROM login_events
            ORDER BY user_id, created_at DESC
         )
         SELECT l.user_id, l.method, l.created_at AS since, u.full_name, u.email
           FROM latest l
           JOIN users u ON u.id = l.user_id
          WHERE l.event_type = 'login'
          ORDER BY l.created_at DESC`,
      ),
    ]);
    res.json({ recentEvents: recentEvents.rows, openSessions: openSessions.rows });
  } catch (err) {
    next(err);
  }
});

/** GET /admin/otp-deliveries — every OTP send attempt, success or failure,
 * so support can answer "did this user's code actually go out" without
 * digging through Resend's dashboard by hand. */
router.get('/otp-deliveries', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim();
    const params = [];
    const where = status ? 'WHERE e.delivery_status = $1' : '';
    if (status) params.push(status);
    const rows = await pool.query(
      `SELECT e.id, e.email, e.purpose, e.delivery_status, e.failure_reason,
              e.attempts, e.consumed_at, e.expires_at, e.created_at, u.full_name
         FROM email_otps e
         LEFT JOIN users u ON u.id = e.user_id
         ${where}
        ORDER BY e.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /admin/activity — unified feed across P2P transfers, merchant
 * payments, mobile-money movements and login events, for a single
 * "everything that just happened" view instead of admins checking four
 * separate lists. Read-only trace/audit surface; disputes and reversals
 * still go through the existing per-type endpoints below (each needs its
 * own reversal semantics — a P2P reversal isn't the same operation as a
 * mobile-money one).
 */
router.get('/activity', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT f.*, u.full_name, u.email
         FROM (
           (SELECT id, created_at, 'p2p_transfer'::text AS type, sender_user_id AS user_id,
                   status, currency, amount, memo AS detail
              FROM p2p_transfers)
           UNION ALL
           (SELECT id, created_at, 'merchant_payment'::text AS type, payer_id AS user_id,
                   status, currency, amount, NULL::text AS detail
              FROM merchant_payments)
           UNION ALL
           (SELECT id, created_at, 'mobile_money_' || lower(type) AS type, user_id,
                   status, 'KES'::text AS currency, amount_kes AS amount, rail AS detail
              FROM mobile_money_movements)
           UNION ALL
           (SELECT id, created_at, 'login_' || event_type AS type, user_id,
                   event_type AS status, NULL::text AS currency, NULL::numeric AS amount, method AS detail
              FROM login_events)
         ) f
         LEFT JOIN users u ON u.id = f.user_id
        ORDER BY f.created_at DESC
        LIMIT 300`,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.get('/users', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim().toLowerCase();
    const params = q ? [`%${q}%`] : [];
    const where = q
      ? `WHERE LOWER(full_name) LIKE $1 OR LOWER(email) LIKE $1 OR phone LIKE $1`
      : '';
    const rows = await pool.query(
      `SELECT id, full_name, email, phone, kyc_tier, phone_verified, role,
              usd_balance, kes_balance, status, suspended_at, suspension_reason,
              created_at
         FROM users
         ${where}
        ORDER BY created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /admin/users/:id/suspend { reason } — freezes login and blocks every
 * authenticated request for this user immediately (see middleware/auth.js).
 * The sole admin account can't suspend itself or another admin. */
router.post('/users/:id/suspend', async (req, res, next) => {
  try {
    const reason = String(req.body?.reason || '').trim();
    if (!reason) return res.status(400).json({ error: 'A suspension reason is required' });
    if (req.params.id === req.userId) {
      return res.status(400).json({ error: 'Cannot suspend your own admin account' });
    }

    const target = (
      await pool.query('SELECT role FROM users WHERE id = $1', [req.params.id])
    ).rows[0];
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (target.role === 'admin') {
      return res.status(400).json({ error: 'Cannot suspend an admin account' });
    }

    const rows = await pool.query(
      `UPDATE users
          SET status = 'SUSPENDED', suspended_at = now(), suspended_by = $1, suspension_reason = $2
        WHERE id = $3
        RETURNING id, full_name, email, phone, status, suspended_at, suspension_reason`,
      [req.userId, reason, req.params.id],
    );
    res.json({ user: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** POST /admin/users/:id/reactivate — lifts a suspension. */
router.post('/users/:id/reactivate', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE users
          SET status = 'ACTIVE', suspended_at = NULL, suspended_by = NULL, suspension_reason = NULL
        WHERE id = $1
        RETURNING id, full_name, email, phone, status`,
      [req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/aml-cases', async (_req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT c.*, u.full_name, u.email, u.phone
         FROM aml_cases c
         LEFT JOIN users u ON u.id = c.user_id
        ORDER BY c.created_at DESC
        LIMIT 200`,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.post('/aml-cases/:id/resolve', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE aml_cases SET status = 'Resolved'
        WHERE id = $1
        RETURNING *`,
      [req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'AML case not found' });
    res.json({ case: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/merchants', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim().toUpperCase();
    const params = [];
    let where = '';
    if (status) {
      where = 'WHERE m.status = $1';
      params.push(status);
    }
    const rows = await pool.query(
      `SELECT m.*, u.full_name AS owner_name, u.email AS owner_email
         FROM merchants m
         JOIN users u ON u.id = m.owner_id
         ${where}
        ORDER BY m.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

function generateAgentCode() {
  return `AG${Math.floor(100000 + Math.random() * 900000)}`;
}

function generateTillNumber() {
  return `KF${Math.floor(100000 + Math.random() * 900000)}`;
}

async function findUserByIdentifier(identifier) {
  const value = String(identifier || '').trim();
  if (!value) return null;
  const rows = await pool.query(
    `SELECT id, full_name, email, phone FROM users
      WHERE LOWER(email) = LOWER($1) OR phone = $1
      LIMIT 1`,
    [value],
  );
  return rows.rows[0] || null;
}

const { TIER_ORDER: AGENT_TIERS, TIER_LIMITS_USD, isValidParentTier } = require('../services/agentTiers');

/** POST /admin/agents — admin directly onboards an existing user into the hierarchy,
 * pre-approved. tier defaults to 'AGENT'; countryCode is required for COUNTRY_AGENT and
 * SUPER_AGENT (one Country Agent per country is enforced at the DB level). parentAgentId
 * must reference a strictly higher tier when given. */
router.post('/agents', async (req, res, next) => {
  try {
    const businessName = String(req.body?.businessName || '').trim();
    const phone = String(req.body?.phone || '').trim() || null;
    const tier = String(req.body?.tier || 'AGENT').toUpperCase();
    const parentAgentId = String(req.body?.parentAgentId || '').trim() || null;
    const countryCode = String(req.body?.countryCode || '').trim().toUpperCase() || null;
    const region = String(req.body?.region || '').trim() || null;
    const city = String(req.body?.city || '').trim() || null;
    if (!businessName) return res.status(400).json({ error: 'Business name is required' });
    if (!['COUNTRY_AGENT', 'SUPER_AGENT', 'AGENT'].includes(tier)) {
      return res.status(400).json({ error: 'tier must be COUNTRY_AGENT, SUPER_AGENT or AGENT' });
    }
    if (['COUNTRY_AGENT', 'SUPER_AGENT'].includes(tier) && !/^[A-Z]{2}$/.test(countryCode || '')) {
      return res.status(400).json({ error: 'A valid 2-letter countryCode is required for this tier' });
    }

    let parent = null;
    if (parentAgentId) {
      if (tier === 'COUNTRY_AGENT') {
        return res.status(400).json({ error: 'A Country Agent cannot have a parent' });
      }
      parent = (await pool.query('SELECT * FROM agents WHERE id = $1', [parentAgentId])).rows[0];
      if (!parent || !isValidParentTier(parent.tier, tier)) {
        return res.status(400).json({ error: `parentAgentId must reference a tier above ${tier}` });
      }
    }

    const user = await findUserByIdentifier(req.body?.identifier);
    if (!user) return res.status(404).json({ error: 'No user found with that email or phone' });

    const existing = await pool.query('SELECT id FROM agents WHERE user_id = $1', [user.id]);
    if (existing.rows.length) {
      return res.status(409).json({ error: 'This user is already registered as an agent' });
    }

    const limits = TIER_LIMITS_USD[tier] || {};
    try {
      const inserted = await pool.query(
        `INSERT INTO agents
          (user_id, business_name, agent_code, phone, status, tier, parent_agent_id,
           country_code, region, city, min_float_usd, daily_limit_usd, approved_by, approved_at)
         VALUES ($1,$2,$3,$4,'ACTIVE',$5,$6,$7,$8,$9,$10,$11,$12,now())
         RETURNING *`,
        [
          user.id, businessName, generateAgentCode(), phone, tier, parent?.id || null,
          countryCode, region, city, limits.minFloatUsd || null, limits.dailyLimitUsd || null, req.userId,
        ],
      );
      res.status(201).json({ agent: inserted.rows[0] });
    } catch (err) {
      if (err.code === '23505') {
        return res.status(409).json({ error: `${countryCode} already has a Country Agent` });
      }
      throw err;
    }
  } catch (err) {
    next(err);
  }
});

router.get('/agents', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim().toUpperCase();
    const tier = String(req.query.tier || '').trim().toUpperCase();
    const conditions = [];
    const params = [];
    if (status) {
      params.push(status);
      conditions.push(`a.status = $${params.length}`);
    }
    if (tier) {
      params.push(tier);
      conditions.push(`a.tier = $${params.length}`);
    }
    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const rows = await pool.query(
      `SELECT a.*, u.full_name AS owner_name, u.email AS owner_email, u.phone AS owner_phone,
              p.business_name AS parent_name, p.agent_code AS parent_code
         FROM agents a
         JOIN users u ON u.id = a.user_id
         LEFT JOIN agents p ON p.id = a.parent_agent_id
         ${where}
        ORDER BY a.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /admin/agents/:id/tier — re-tier or re-parent an existing agent (e.g. promote to Super Agent). */
router.post('/agents/:id/tier', async (req, res, next) => {
  try {
    const tier = String(req.body?.tier || '').toUpperCase();
    const parentAgentId = String(req.body?.parentAgentId || '').trim() || null;
    if (!AGENT_TIERS.includes(tier)) {
      return res.status(400).json({ error: `tier must be one of ${AGENT_TIERS.join(', ')}` });
    }
    if (tier === 'COUNTRY_AGENT' && parentAgentId) {
      return res.status(400).json({ error: 'A Country Agent cannot have a parent' });
    }
    if (parentAgentId === req.params.id) {
      return res.status(400).json({ error: 'An agent cannot be its own parent' });
    }
    if (parentAgentId) {
      const parent = (await pool.query('SELECT tier FROM agents WHERE id = $1', [parentAgentId])).rows[0];
      if (!parent) return res.status(404).json({ error: 'parentAgentId not found' });
      if (!isValidParentTier(parent.tier, tier)) {
        return res.status(400).json({ error: `parentAgentId must reference a tier above ${tier}` });
      }
    }

    const rows = await pool.query(
      `UPDATE agents SET tier = $1, parent_agent_id = $2 WHERE id = $3 RETURNING *`,
      [tier, parentAgentId, req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Agent not found' });
    res.json({ agent: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/agents/:id/approve', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE agents SET status = 'ACTIVE', approved_by = $1, approved_at = now()
        WHERE id = $2
        RETURNING *`,
      [req.userId, req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Agent not found' });
    res.json({ agent: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** Admin can reject any pending application directly — a fallback alongside the
 * sponsor-side POST /agents/applications/:id/reject, e.g. for the bootstrap case
 * where an application had no sponsor to route to. */
router.post('/agents/:id/reject', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE agents SET status = 'REJECTED' WHERE id = $1 AND status = 'PENDING_REVIEW' RETURNING *`,
      [req.params.id],
    );
    if (rows.rows.length === 0) {
      return res.status(404).json({ error: 'No matching pending agent found' });
    }
    res.json({ agent: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/agents/:id/deactivate', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE agents SET status = 'SUSPENDED' WHERE id = $1 RETURNING *`,
      [req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Agent not found' });
    res.json({ agent: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/agents/:id/commissions', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT c.*, u.full_name AS related_user_name
         FROM agent_commissions c
         LEFT JOIN users u ON u.id = c.related_user_id
        WHERE c.agent_id = $1
        ORDER BY c.created_at DESC
        LIMIT 100`,
      [req.params.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** GET /admin/commissions/summary — commission liability across all agents. */
router.get('/commissions/summary', async (_req, res, next) => {
  try {
    const totals = await pool.query(
      `SELECT COALESCE(SUM(commission_balance), 0)::float AS total_liability_usd,
              COUNT(*) FILTER (WHERE status = 'ACTIVE')::int AS active_agent_count
         FROM agents`,
    );
    const byAgent = await pool.query(
      `SELECT a.id, a.business_name, a.agent_code, a.status, a.commission_balance, a.tier,
              u.full_name AS owner_name, u.email AS owner_email,
              COUNT(c.id)::int AS transaction_count
         FROM agents a
         JOIN users u ON u.id = a.user_id
         LEFT JOIN agent_commissions c ON c.agent_id = a.id
        GROUP BY a.id, u.full_name, u.email
        ORDER BY a.commission_balance DESC
        LIMIT 200`,
    );
    res.json({
      totalLiabilityUsd: totals.rows[0].total_liability_usd,
      activeAgentCount: totals.rows[0].active_agent_count,
      agents: byAgent.rows,
    });
  } catch (err) {
    next(err);
  }
});

/** POST /admin/merchants — admin directly onboards an existing user as a merchant, pre-approved.
 * Optional agentCode pays that agent the merchant-onboarding commission immediately, since the
 * merchant is created already ACTIVE (no separate approval step to gate it on). */
router.post('/merchants', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const name = String(req.body?.name || '').trim();
    const businessType = String(req.body?.businessType || '').trim() || null;
    const phone = String(req.body?.phone || '').trim() || null;
    if (!name) return res.status(400).json({ error: 'Merchant name is required' });

    const user = await findUserByIdentifier(req.body?.identifier);
    if (!user) return res.status(404).json({ error: 'No user found with that email or phone' });

    const agentCode = String(req.body?.agentCode || '').trim();
    let referringAgent = null;
    if (agentCode) {
      referringAgent = (
        await client.query("SELECT * FROM agents WHERE agent_code = $1 AND status = 'ACTIVE'", [agentCode])
      ).rows[0];
    }

    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO merchants (owner_id, name, till_number, business_type, phone, status, approved_by, approved_at, referred_by_agent_id)
       VALUES ($1,$2,$3,$4,$5,'ACTIVE',$6,now(),$7)
       RETURNING *`,
      [user.id, name, generateTillNumber(), businessType, phone, req.userId, referringAgent?.id || null],
    );
    if (referringAgent) {
      await creditAgentCommission(
        client, referringAgent, 'merchant_onboarding', 'USD',
        MERCHANT_ONBOARDING_COMMISSION_USD, user.id,
      );
    }
    await client.query('COMMIT');
    res.status(201).json({ merchant: inserted.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** Approving a merchant pays its referring agent (if any) the merchant-onboarding
 * commission — guarded so a merchant can never pay it out twice on re-approval. */
router.post('/merchants/:id/approve', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const before = (
      await client.query('SELECT status, referred_by_agent_id FROM merchants WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!before) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Merchant not found' });
    }

    const rows = await client.query(
      `UPDATE merchants SET status = 'ACTIVE', approved_by = $1, approved_at = now()
        WHERE id = $2
        RETURNING *`,
      [req.userId, req.params.id],
    );

    if (before.status !== 'ACTIVE' && before.referred_by_agent_id) {
      const agent = (
        await client.query('SELECT * FROM agents WHERE id = $1', [before.referred_by_agent_id])
      ).rows[0];
      if (agent) {
        await creditAgentCommission(
          client, agent, 'merchant_onboarding', 'USD',
          MERCHANT_ONBOARDING_COMMISSION_USD, rows.rows[0].owner_id,
        );
      }
    }

    await client.query('COMMIT');
    res.json({ merchant: rows.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

router.post('/merchants/:id/deactivate', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE merchants SET status = 'SUSPENDED' WHERE id = $1 RETURNING *`,
      [req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Merchant not found' });
    res.json({ merchant: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

/** GET /admin/p2p-transfers — browse wallet-to-wallet transfers, filterable by status. */
router.get('/p2p-transfers', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim().toUpperCase();
    const params = [];
    let where = '';
    if (status) {
      where = 'WHERE t.status = $1';
      params.push(status);
    }
    const rows = await pool.query(
      `SELECT t.*, s.full_name AS sender_name, s.email AS sender_email,
              r.full_name AS recipient_name, r.email AS recipient_email
         FROM p2p_transfers t
         JOIN users s ON s.id = t.sender_user_id
         JOIN users r ON r.id = t.recipient_user_id
         ${where}
        ORDER BY t.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /admin/p2p-transfers/:id/reverse { reason } — undoes a completed
 * wallet-to-wallet transfer: moves the money back from recipient to sender
 * and posts a compensating ledger transaction mirroring the original.
 * Blocked if the recipient no longer holds enough balance to reverse
 * cleanly — this never pushes a balance negative.
 */
router.post('/p2p-transfers/:id/reverse', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const reason = String(req.body?.reason || '').trim();
    if (!reason) return res.status(400).json({ error: 'A reversal reason is required' });

    await client.query('BEGIN');
    const transfer = (
      await client.query(
        `SELECT t.*, s.full_name AS sender_name, r.full_name AS recipient_name
           FROM p2p_transfers t
           JOIN users s ON s.id = t.sender_user_id
           JOIN users r ON r.id = t.recipient_user_id
          WHERE t.id = $1
          FOR UPDATE OF t`,
        [req.params.id],
      )
    ).rows[0];
    if (!transfer) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Transfer not found' });
    }
    if (transfer.status !== 'COMPLETED') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Transfer is already ${transfer.status}` });
    }

    const column = transfer.currency === 'KES' ? 'kes_balance' : 'usd_balance';
    const recipient = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        transfer.recipient_user_id,
      ])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [transfer.sender_user_id]);
    if (Number(recipient.balance) < Number(transfer.amount)) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: `Recipient only has ${recipient.balance} ${transfer.currency} left — not enough to reverse ${transfer.amount} ${transfer.currency}`,
      });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      transfer.amount,
      transfer.recipient_user_id,
    ]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      transfer.amount,
      transfer.sender_user_id,
    ]);

    const amountUsd = compliance.toUsd(Number(transfer.amount), transfer.currency);
    await ledger.postWithClient(
      client,
      transfer.sender_user_id,
      { title: `Reversal: refund from ${transfer.recipient_name}`, rail: 'Wayaki P2P reversal' },
      [
        { accountName: 'Wayaki transfer clearing', direction: 'debit', amountUsd, memo: `Reversal of ${transfer.id}` },
        { accountName: `Customer ${transfer.currency} wallet`, direction: 'credit', amountUsd, memo: reason },
      ],
    );
    await ledger.postWithClient(
      client,
      transfer.recipient_user_id,
      { title: 'Reversal: transfer clawed back', rail: 'Wayaki P2P reversal' },
      [
        { accountName: `Customer ${transfer.currency} wallet`, direction: 'debit', amountUsd, memo: reason },
        { accountName: 'Wayaki transfer clearing', direction: 'credit', amountUsd, memo: `Reversal of ${transfer.id}` },
      ],
    );

    const updated = await client.query(
      `UPDATE p2p_transfers
          SET status = 'REVERSED', reversed_at = now(), reversed_by = $1, reversal_reason = $2
        WHERE id = $3
        RETURNING *`,
      [req.userId, reason, transfer.id],
    );
    await client.query('COMMIT');
    res.json({ transfer: updated.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /admin/merchant-payments — browse merchant payments, filterable by status. */
router.get('/merchant-payments', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim().toUpperCase();
    const params = [];
    let where = '';
    if (status) {
      where = 'WHERE p.status = $1';
      params.push(status);
    }
    const rows = await pool.query(
      `SELECT p.*, m.name AS merchant_name, m.till_number,
              u.full_name AS payer_name, u.email AS payer_email
         FROM merchant_payments p
         JOIN merchants m ON m.id = p.merchant_id
         JOIN users u ON u.id = p.payer_id
         ${where}
        ORDER BY p.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /admin/merchant-payments/:id/reverse { reason } — refunds a
 * completed merchant payment back to the payer. Blocked if the merchant
 * owner no longer holds enough balance to reverse cleanly.
 */
router.post('/merchant-payments/:id/reverse', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const reason = String(req.body?.reason || '').trim();
    if (!reason) return res.status(400).json({ error: 'A reversal reason is required' });

    await client.query('BEGIN');
    const payment = (
      await client.query(
        `SELECT p.*, m.name AS merchant_name, m.owner_id
           FROM merchant_payments p
           JOIN merchants m ON m.id = p.merchant_id
          WHERE p.id = $1
          FOR UPDATE OF p`,
        [req.params.id],
      )
    ).rows[0];
    if (!payment) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Payment not found' });
    }
    if (payment.status !== 'COMPLETED') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Payment is already ${payment.status}` });
    }

    const column = payment.currency === 'KES' ? 'kes_balance' : 'usd_balance';
    const merchantOwner = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        payment.owner_id,
      ])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [payment.payer_id]);
    if (Number(merchantOwner.balance) < Number(payment.amount)) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: `Merchant only has ${merchantOwner.balance} ${payment.currency} left — not enough to reverse ${payment.amount} ${payment.currency}`,
      });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      payment.amount,
      payment.owner_id,
    ]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      payment.amount,
      payment.payer_id,
    ]);

    const amountUsd = compliance.toUsd(Number(payment.amount), payment.currency);
    await ledger.postWithClient(
      client,
      payment.owner_id,
      { title: 'Reversal: refund to payer', rail: 'Merchant QR reversal' },
      [
        { accountName: `Customer ${payment.currency} wallet`, direction: 'debit', amountUsd, memo: reason },
        { accountName: 'Merchant settlement clearing', direction: 'credit', amountUsd, memo: `Reversal of ${payment.id}` },
      ],
    );
    await ledger.postWithClient(
      client,
      payment.payer_id,
      { title: `Reversal: refund from ${payment.merchant_name}`, rail: 'Merchant QR reversal' },
      [
        { accountName: 'Merchant settlement clearing', direction: 'debit', amountUsd, memo: `Reversal of ${payment.id}` },
        { accountName: `Customer ${payment.currency} wallet`, direction: 'credit', amountUsd, memo: reason },
      ],
    );

    const updated = await client.query(
      `UPDATE merchant_payments
          SET status = 'REVERSED', reversed_at = now(), reversed_by = $1, reversal_reason = $2
        WHERE id = $3
        RETURNING *`,
      [req.userId, reason, payment.id],
    );
    await client.query('COMMIT');
    res.json({ payment: updated.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

router.get('/remittances', async (_req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT r.*, s.full_name AS sender_name, s.email AS sender_email,
              rec.full_name AS recipient_name
         FROM remittances r
         JOIN users s ON s.id = r.sender_user_id
         LEFT JOIN users rec ON rec.id = r.recipient_user_id
        ORDER BY r.created_at DESC
        LIMIT 200`,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.get('/virtual-accounts', async (_req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT a.*, u.full_name, u.email, u.phone
         FROM virtual_accounts a
         JOIN users u ON u.id = a.user_id
        ORDER BY a.created_at DESC
        LIMIT 200`,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.get('/mobile-money', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim();
    const params = [];
    const where = status ? 'WHERE m.status = $1' : '';
    if (status) params.push(status);
    const rows = await pool.query(
      `SELECT m.id, m.type, m.rail, m.phone, m.amount_kes, m.reference, m.status,
              m.admin_note, m.created_at, m.updated_at,
              u.full_name, u.email, u.phone AS user_phone
         FROM mobile_money_movements m
         JOIN users u ON u.id = m.user_id
         ${where}
        ORDER BY m.created_at DESC
        LIMIT 200`,
      params,
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.post('/mobile-money/:id/approve-deposit', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const note = String(req.body?.note || '').trim();
    await client.query('BEGIN');
    const movement = (
      await client.query(
        `SELECT * FROM mobile_money_movements
          WHERE id = $1 AND type = 'DEPOSIT'
          FOR UPDATE`,
        [req.params.id],
      )
    ).rows[0];
    if (!movement) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Deposit request not found' });
    }
    if (movement.status !== 'PENDING_ADMIN') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Deposit is already ${movement.status}` });
    }

    await client.query('UPDATE users SET kes_balance = kes_balance + $1 WHERE id = $2', [
      movement.amount_kes,
      movement.user_id,
    ]);
    await client.query(
      `UPDATE mobile_money_movements
          SET status = 'APPROVED', admin_note = $1, approved_by = $2, updated_at = now()
        WHERE id = $3`,
      [note || null, req.userId, movement.id],
    );
    const amountUsd = Number((Number(movement.amount_kes) / config.kesPerUsd).toFixed(2));
    await ledger.postWithClient(
      client,
      movement.user_id,
      { title: `${movement.rail} deposit approved`, rail: movement.rail },
      [
        { accountName: 'Mobile money settlement', direction: 'debit', amountUsd, memo: movement.reference || '' },
        { accountName: 'Customer KES wallet', direction: 'credit', amountUsd, memo: `${movement.amount_kes} KES credited` },
      ],
    );
    await client.query('COMMIT');
    res.json({ approved: true, movementId: movement.id });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/**
 * Fires a real Paystack Transfer to the withdrawal's M-Pesa number instead
 * of the admin paying out manually off-app. Paystack settles asynchronously
 * — this only gets the payout moving (status PROCESSING or, if Paystack's
 * "Confirm transfers before sending" is still on, PENDING_OTP); the
 * transfer.success/failed webhook below moves it to its final state.
 */
router.post('/mobile-money/:id/complete-withdrawal', async (req, res, next) => {
  try {
    const note = String(req.body?.note || '').trim();
    const movement = (
      await pool.query(
        `SELECT m.*, u.full_name
           FROM mobile_money_movements m
           JOIN users u ON u.id = m.user_id
          WHERE m.id = $1 AND m.type = 'WITHDRAWAL' AND m.status = 'PENDING_PAYOUT'`,
        [req.params.id],
      )
    ).rows[0];
    if (!movement) {
      return res.status(404).json({ error: 'Pending withdrawal request not found' });
    }
    if (movement.rail !== 'M-Pesa') {
      return res.status(400).json({
        error: `Automated payout only supports M-Pesa via Paystack — this is a ${movement.rail} withdrawal. Complete it manually and use /cancel to release the hold if it can't be paid out.`,
      });
    }

    const reference = `wd_${String(movement.id).replace(/-/g, '')}_${Date.now()}`;
    let transfer;
    try {
      transfer = await payoutToMpesa({
        name: movement.full_name,
        phone: movement.phone,
        amountKes: Number(movement.amount_kes),
        reference,
        reason: `Wayaki ${movement.rail} withdrawal`,
      });
    } catch (err) {
      return res.status(502).json({ error: `Paystack transfer failed: ${err.message}` });
    }

    const status = transfer.status === 'otp' ? 'PENDING_OTP' : 'PROCESSING';
    await pool.query(
      `UPDATE mobile_money_movements
          SET status = $1, reference = $2, admin_note = $3, approved_by = $4, updated_at = now()
        WHERE id = $5`,
      [status, reference, note || null, req.userId, movement.id],
    );

    res.json({
      initiated: true,
      movementId: movement.id,
      status,
      transferCode: transfer.transfer_code,
      ...(status === 'PENDING_OTP' && {
        warning:
          'Paystack is asking for an OTP confirmation before it will send this. Disable "Confirm transfers before sending" in Paystack Settings > Preferences to automate payouts end-to-end.',
      }),
    });
  } catch (err) {
    next(err);
  }
});

router.post('/mobile-money/:id/cancel', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const note = String(req.body?.note || '').trim();
    await client.query('BEGIN');
    const movement = (
      await client.query('SELECT * FROM mobile_money_movements WHERE id = $1 FOR UPDATE', [
        req.params.id,
      ])
    ).rows[0];
    if (!movement) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Movement not found' });
    }
    if (!['PENDING_ADMIN', 'PENDING_PAYOUT'].includes(movement.status)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Movement is already ${movement.status}` });
    }

    if (movement.type === 'WITHDRAWAL') {
      await client.query('UPDATE users SET kes_balance = kes_balance + $1 WHERE id = $2', [
        movement.amount_kes,
        movement.user_id,
      ]);
      const amountUsd = Number((Number(movement.amount_kes) / config.kesPerUsd).toFixed(2));
      await ledger.postWithClient(
        client,
        movement.user_id,
        { title: `${movement.rail} withdrawal cancelled`, rail: movement.rail },
        [
          { accountName: 'Mobile money payout clearing', direction: 'debit', amountUsd, memo: note },
          { accountName: 'Customer KES wallet', direction: 'credit', amountUsd, memo: `${movement.amount_kes} KES released` },
        ],
      );
    }

    await client.query(
      `UPDATE mobile_money_movements
          SET status = 'CANCELLED', admin_note = $1, approved_by = $2, updated_at = now()
        WHERE id = $3`,
      [note || null, req.userId, movement.id],
    );
    await client.query('COMMIT');
    res.json({ cancelled: true, movementId: movement.id });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
