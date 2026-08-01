const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');

const router = express.Router();
router.use(requireAuth);

function cleanCurrency(value) {
  const currency = String(value || 'KES').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw new Error('currency must be KES or USD');
  return currency;
}

function balanceColumn(currency) {
  return currency === 'KES' ? 'kes_balance' : 'usd_balance';
}

// Plain 6-digit, like a real M-Pesa till number — no letter prefix, so it
// reads as "the business ID" rather than an internal code.
function tillNumber() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/** A 6-digit space is small enough that collisions are plausible at scale,
 * so check-and-retry rather than trusting one random draw. */
async function uniqueTillNumber(client) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const candidate = tillNumber();
    const exists = await client.query('SELECT 1 FROM merchants WHERE till_number = $1', [candidate]);
    if (exists.rows.length === 0) return candidate;
  }
  throw new Error('Could not generate a unique till number — try again');
}

async function findUserByIdentifier(client, identifier) {
  const value = String(identifier || '').trim();
  if (!value) return null;
  const rows = await client.query(
    `SELECT id, full_name, email, phone FROM users
      WHERE LOWER(email) = LOWER($1) OR phone = $1
      LIMIT 1`,
    [value],
  );
  return rows.rows[0] || null;
}

/**
 * Resolves who req.userId is acting as for a merchant action: the
 * merchant's owner, or an ACTIVE teller scoped to that specific merchant.
 * Tellers can accept/request payments on the till; they're never given
 * the owner's personal settlement wallet balance through any route.
 */
async function resolveMerchantAccess(client, userId, merchantId) {
  const merchant = (await client.query('SELECT * FROM merchants WHERE id = $1', [merchantId])).rows[0];
  if (!merchant) return null;
  if (merchant.owner_id === userId) return { merchant, role: 'OWNER' };

  const teller = (
    await client.query(
      `SELECT 1 FROM merchant_staff WHERE merchant_id = $1 AND user_id = $2 AND status = 'ACTIVE'`,
      [merchantId, userId],
    )
  ).rows[0];
  return teller ? { merchant, role: 'TELLER' } : null;
}

router.get('/me', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, name, till_number, business_type, phone, status, created_at
         FROM merchants WHERE owner_id = $1 ORDER BY created_at DESC`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** GET /merchants/staff-of — merchants I've been added as a teller for. */
router.get('/staff-of', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT m.id, m.name, m.till_number, m.status AS merchant_status, s.status AS staff_status
         FROM merchant_staff s
         JOIN merchants m ON m.id = s.merchant_id
        WHERE s.user_id = $1
        ORDER BY s.created_at DESC`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /merchants/:merchantId/staff — owner adds a teller, scoped to accepting payments only. */
router.post('/:merchantId/staff', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const merchant = (
      await client.query('SELECT id FROM merchants WHERE id = $1 AND owner_id = $2', [
        req.params.merchantId,
        req.userId,
      ])
    ).rows[0];
    if (!merchant) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Merchant not found' });
    }
    const user = await findUserByIdentifier(client, req.body?.identifier);
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No user found with that email or phone' });
    }
    const inserted = await client.query(
      `INSERT INTO merchant_staff (merchant_id, user_id, added_by)
       VALUES ($1,$2,$3)
       ON CONFLICT (merchant_id, user_id) DO UPDATE SET status = 'ACTIVE'
       RETURNING *`,
      [merchant.id, user.id, req.userId],
    );
    await client.query('COMMIT');
    res.status(201).json({ teller: inserted.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /merchants/:merchantId/staff — owner lists their tellers. */
router.get('/:merchantId/staff', async (req, res, next) => {
  try {
    const merchant = (
      await pool.query('SELECT id FROM merchants WHERE id = $1 AND owner_id = $2', [
        req.params.merchantId,
        req.userId,
      ])
    ).rows[0];
    if (!merchant) return res.status(404).json({ error: 'Merchant not found' });

    const rows = await pool.query(
      `SELECT s.*, u.full_name, u.email, u.phone
         FROM merchant_staff s
         JOIN users u ON u.id = s.user_id
        WHERE s.merchant_id = $1
        ORDER BY s.created_at DESC`,
      [merchant.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** POST /merchants/:merchantId/staff/:staffId/remove — owner deactivates a teller. */
router.post('/:merchantId/staff/:staffId/remove', async (req, res, next) => {
  try {
    const merchant = (
      await pool.query('SELECT id FROM merchants WHERE id = $1 AND owner_id = $2', [
        req.params.merchantId,
        req.userId,
      ])
    ).rows[0];
    if (!merchant) return res.status(404).json({ error: 'Merchant not found' });

    const rows = await pool.query(
      `UPDATE merchant_staff SET status = 'SUSPENDED' WHERE id = $1 AND merchant_id = $2 RETURNING *`,
      [req.params.staffId, merchant.id],
    );
    if (rows.rows.length === 0) return res.status(404).json({ error: 'Teller not found' });
    res.json({ teller: rows.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const name = String(req.body?.name || '').trim();
    const businessType = String(req.body?.businessType || '').trim() || null;
    const phone = String(req.body?.phone || '').trim() || null;
    if (!name) return res.status(400).json({ error: 'Merchant name is required' });

    // Agent-assisted merchant onboarding: a valid referral code links the
    // new merchant to the agent — commission is paid once an admin approves
    // it (see admin.js POST /merchants/:id/approve), not at this PENDING stage.
    const agentCode = String(req.body?.agentCode || '').trim();
    let referringAgent = null;
    if (agentCode) {
      referringAgent = (
        await pool.query("SELECT id FROM agents WHERE agent_code = $1 AND status = 'ACTIVE'", [
          agentCode,
        ])
      ).rows[0];
    }

    const inserted = await pool.query(
      `INSERT INTO merchants (owner_id, name, till_number, business_type, phone, status, referred_by_agent_id)
       VALUES ($1,$2,$3,$4,$5,'PENDING',$6)
       RETURNING id, name, till_number, business_type, phone, status, created_at`,
      [req.userId, name, await uniqueTillNumber(pool), businessType, phone, referringAgent?.id || null],
    );
    res.status(201).json({ merchant: inserted.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/:merchantId/payment-links', async (req, res, next) => {
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    const description = String(req.body?.description || '').trim();
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }
    const access = await resolveMerchantAccess(pool, req.userId, req.params.merchantId);
    if (!access) return res.status(404).json({ error: 'Merchant not found' });

    const link = await pool.query(
      `INSERT INTO payment_links (merchant_id, currency, amount, description)
       VALUES ($1,$2,$3,$4)
       RETURNING *`,
      [access.merchant.id, currency, amount, description || null],
    );
    res.status(201).json({ paymentLink: link.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/pay-link/:linkId', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const link = (
      await client.query(
        `SELECT l.*, m.owner_id, m.name AS merchant_name
           FROM payment_links l
           JOIN merchants m ON m.id = l.merchant_id
          WHERE l.id = $1 AND l.status = 'OPEN'
          FOR UPDATE`,
        [req.params.linkId],
      )
    ).rows[0];
    if (!link) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Payment link not found' });
    }

    const amountUsd = compliance.toUsd(Number(link.amount), link.currency);
    const limit = await compliance.checkUserLimit(
      client,
      req.userId,
      amountUsd,
      `Merchant payment to ${link.merchant_name}`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Payment requires compliance review' });
    }

    const column = balanceColumn(link.currency);
    const payer = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        req.userId,
      ])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [link.owner_id]);
    if (Number(payer.balance) < Number(link.amount)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${link.currency} balance` });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      link.amount,
      req.userId,
    ]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      link.amount,
      link.owner_id,
    ]);
    const payment = await client.query(
      `INSERT INTO merchant_payments
        (merchant_id, payer_id, payment_link_id, currency, amount)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [link.merchant_id, req.userId, link.id, link.currency, link.amount],
    );
    await client.query("UPDATE payment_links SET status = 'PAID' WHERE id = $1", [link.id]);

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Paid ${link.merchant_name}`, rail: 'Merchant QR' },
      [
        { accountName: `Customer ${link.currency} wallet`, direction: 'debit', amountUsd, memo: link.id },
        { accountName: 'Merchant settlement clearing', direction: 'credit', amountUsd, memo: payment.rows[0].id },
      ],
    );
    await ledger.postWithClient(
      client,
      link.owner_id,
      { title: `Merchant sale: ${link.merchant_name}`, rail: 'Merchant QR' },
      [
        { accountName: 'Merchant settlement clearing', direction: 'debit', amountUsd, memo: payment.rows[0].id },
        { accountName: `Customer ${link.currency} wallet`, direction: 'credit', amountUsd, memo: link.id },
      ],
    );
    await client.query('COMMIT');

    res.status(201).json({ payment: payment.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/**
 * GET /merchants/by-till/:tillNumber — looks up a merchant's public-facing
 * name/status by till number, so the payer sees who they're about to pay
 * before entering an amount. Used by the QR-code link (see merchant_screen.dart)
 * and the pay-by-till screen; only exposes what a payer needs, never balances.
 */
router.get('/by-till/:tillNumber', async (req, res, next) => {
  try {
    const merchant = (
      await pool.query(
        `SELECT id, name, till_number, business_type, status FROM merchants WHERE till_number = $1`,
        [req.params.tillNumber],
      )
    ).rows[0];
    if (!merchant || merchant.status !== 'ACTIVE') {
      return res.status(404).json({ error: 'Merchant not found or not active' });
    }
    res.json(merchant);
  } catch (err) {
    next(err);
  }
});

/** POST /merchants/pay/:tillNumber — direct QR/till payment, no payment link needed. */
router.post('/pay/:tillNumber', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Positive amount is required' });
    }

    await client.query('BEGIN');
    const merchant = (
      await client.query(
        `SELECT id, owner_id, name FROM merchants
          WHERE till_number = $1 AND status = 'ACTIVE'`,
        [req.params.tillNumber],
      )
    ).rows[0];
    if (!merchant) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Merchant not found' });
    }
    if (merchant.owner_id === req.userId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Cannot pay your own till' });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const limit = await compliance.checkUserLimit(
      client,
      req.userId,
      amountUsd,
      `Merchant payment to ${merchant.name}`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Payment requires compliance review' });
    }

    const column = balanceColumn(currency);
    const payer = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        req.userId,
      ])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [merchant.owner_id]);
    if (Number(payer.balance) < amount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${currency} balance` });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      amount,
      req.userId,
    ]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      amount,
      merchant.owner_id,
    ]);
    const payment = await client.query(
      `INSERT INTO merchant_payments (merchant_id, payer_id, currency, amount)
       VALUES ($1,$2,$3,$4)
       RETURNING *`,
      [merchant.id, req.userId, currency, amount],
    );

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Paid ${merchant.name}`, rail: 'Merchant QR' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd, memo: merchant.id },
        { accountName: 'Merchant settlement clearing', direction: 'credit', amountUsd, memo: payment.rows[0].id },
      ],
    );
    await ledger.postWithClient(
      client,
      merchant.owner_id,
      { title: `Merchant sale: ${merchant.name}`, rail: 'Merchant QR' },
      [
        { accountName: 'Merchant settlement clearing', direction: 'debit', amountUsd, memo: payment.rows[0].id },
        { accountName: `Customer ${currency} wallet`, direction: 'credit', amountUsd, memo: merchant.id },
      ],
    );
    await client.query('COMMIT');

    res.status(201).json({ payment: payment.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /merchants/:merchantId/payments — recent payments received. */
router.get('/:merchantId/payments', async (req, res, next) => {
  try {
    const access = await resolveMerchantAccess(pool, req.userId, req.params.merchantId);
    if (!access) return res.status(404).json({ error: 'Merchant not found' });

    const rows = await pool.query(
      `SELECT p.*, u.full_name AS payer_name
         FROM merchant_payments p
         JOIN users u ON u.id = p.payer_id
        WHERE p.merchant_id = $1
        ORDER BY p.created_at DESC
        LIMIT 50`,
      [access.merchant.id],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
