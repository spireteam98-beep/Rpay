const express = require('express');
const { pool } = require('../db');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');
const exchange = require('../services/exchange');

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

router.get('/users', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim().toLowerCase();
    const params = q ? [`%${q}%`] : [];
    const where = q
      ? `WHERE LOWER(full_name) LIKE $1 OR LOWER(email) LIKE $1 OR phone LIKE $1`
      : '';
    const rows = await pool.query(
      `SELECT id, full_name, email, phone, kyc_tier, phone_verified, role,
              usd_balance, kes_balance, created_at
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

/** POST /admin/agents — admin directly onboards an existing user as an agent, pre-approved. */
router.post('/agents', async (req, res, next) => {
  try {
    const businessName = String(req.body?.businessName || '').trim();
    const phone = String(req.body?.phone || '').trim() || null;
    if (!businessName) return res.status(400).json({ error: 'Business name is required' });

    const user = await findUserByIdentifier(req.body?.identifier);
    if (!user) return res.status(404).json({ error: 'No user found with that email or phone' });

    const existing = await pool.query('SELECT id FROM agents WHERE user_id = $1', [user.id]);
    if (existing.rows.length) {
      return res.status(409).json({ error: 'This user is already registered as an agent' });
    }

    const inserted = await pool.query(
      `INSERT INTO agents (user_id, business_name, agent_code, phone, status, approved_by, approved_at)
       VALUES ($1,$2,$3,$4,'ACTIVE',$5,now())
       RETURNING *`,
      [user.id, businessName, generateAgentCode(), phone, req.userId],
    );
    res.status(201).json({ agent: inserted.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/agents', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim().toUpperCase();
    const params = [];
    let where = '';
    if (status) {
      where = 'WHERE a.status = $1';
      params.push(status);
    }
    const rows = await pool.query(
      `SELECT a.*, u.full_name AS owner_name, u.email AS owner_email, u.phone AS owner_phone
         FROM agents a
         JOIN users u ON u.id = a.user_id
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
      `SELECT a.id, a.business_name, a.agent_code, a.status, a.commission_balance,
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

/** POST /admin/merchants — admin directly onboards an existing user as a merchant, pre-approved. */
router.post('/merchants', async (req, res, next) => {
  try {
    const name = String(req.body?.name || '').trim();
    const businessType = String(req.body?.businessType || '').trim() || null;
    const phone = String(req.body?.phone || '').trim() || null;
    if (!name) return res.status(400).json({ error: 'Merchant name is required' });

    const user = await findUserByIdentifier(req.body?.identifier);
    if (!user) return res.status(404).json({ error: 'No user found with that email or phone' });

    const inserted = await pool.query(
      `INSERT INTO merchants (owner_id, name, till_number, business_type, phone, status, approved_by, approved_at)
       VALUES ($1,$2,$3,$4,$5,'ACTIVE',$6,now())
       RETURNING *`,
      [user.id, name, generateTillNumber(), businessType, phone, req.userId],
    );
    res.status(201).json({ merchant: inserted.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/merchants/:id/approve', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `UPDATE merchants SET status = 'ACTIVE', approved_by = $1, approved_at = now()
        WHERE id = $2
        RETURNING *`,
      [req.userId, req.params.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Merchant not found' });
    res.json({ merchant: rows.rows[0] });
  } catch (err) {
    next(err);
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

router.post('/mobile-money/:id/complete-withdrawal', async (req, res, next) => {
  try {
    const note = String(req.body?.note || '').trim();
    const updated = await pool.query(
      `UPDATE mobile_money_movements
          SET status = 'COMPLETED', admin_note = $1, approved_by = $2, updated_at = now()
        WHERE id = $3 AND type = 'WITHDRAWAL' AND status = 'PENDING_PAYOUT'
        RETURNING id`,
      [note || null, req.userId, req.params.id],
    );
    if (updated.rows.length === 0) {
      return res.status(404).json({ error: 'Pending withdrawal request not found' });
    }
    res.json({ completed: true, movementId: updated.rows[0].id });
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
