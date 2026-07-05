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

function tillNumber() {
  return `KF${Math.floor(100000 + Math.random() * 900000)}`;
}

router.get('/me', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, name, till_number, status, created_at
         FROM merchants WHERE owner_id = $1 ORDER BY created_at DESC`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const name = String(req.body?.name || '').trim();
    if (!name) return res.status(400).json({ error: 'Merchant name is required' });
    const inserted = await pool.query(
      `INSERT INTO merchants (owner_id, name, till_number)
       VALUES ($1,$2,$3)
       RETURNING id, name, till_number, status, created_at`,
      [req.userId, name, tillNumber()],
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
    const merchant = (
      await pool.query('SELECT id FROM merchants WHERE id = $1 AND owner_id = $2', [
        req.params.merchantId,
        req.userId,
      ])
    ).rows[0];
    if (!merchant) return res.status(404).json({ error: 'Merchant not found' });

    const link = await pool.query(
      `INSERT INTO payment_links (merchant_id, currency, amount, description)
       VALUES ($1,$2,$3,$4)
       RETURNING *`,
      [merchant.id, currency, amount, description || null],
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

module.exports = router;
