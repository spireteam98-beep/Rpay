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

router.get('/', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT t.*, s.full_name AS sender_name, r.full_name AS recipient_name
         FROM p2p_transfers t
         JOIN users s ON s.id = t.sender_user_id
         JOIN users r ON r.id = t.recipient_user_id
        WHERE t.sender_user_id = $1 OR t.recipient_user_id = $1
        ORDER BY t.created_at DESC
        LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const recipient = String(req.body?.recipient || '').trim().toLowerCase();
    const currency = cleanCurrency(req.body?.currency);
    const amount = Number(req.body?.amount);
    const memo = String(req.body?.memo || '').trim();
    if (!recipient || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'recipient and positive amount are required' });
    }

    await client.query('BEGIN');
    const receiver = (
      await client.query(
        `SELECT id, full_name FROM users
          WHERE LOWER(email) = $1 OR phone = $2
          LIMIT 1`,
        [recipient, req.body?.recipient],
      )
    ).rows[0];
    if (!receiver) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Recipient not found' });
    }
    if (receiver.id === req.userId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Cannot transfer to yourself' });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const limit = await compliance.checkUserLimit(
      client,
      req.userId,
      amountUsd,
      `P2P ${currency} transfer`,
    );
    const screen = await compliance.screenText(client, req.userId, 'P2P transfer memo', memo);
    if (!limit.allowed || !screen.clear) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Transfer requires compliance review' });
    }

    const column = balanceColumn(currency);
    const sender = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [
        req.userId,
      ])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [receiver.id]);
    if (Number(sender.balance) < amount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${currency} balance` });
    }

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [
      amount,
      req.userId,
    ]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
      amount,
      receiver.id,
    ]);
    const transfer = await client.query(
      `INSERT INTO p2p_transfers
        (sender_user_id, recipient_user_id, currency, amount, memo)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [req.userId, receiver.id, currency, amount, memo || null],
    );

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Sent ${currency} to ${receiver.full_name}`, rail: 'RoyallPay P2P' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd, memo },
        { accountName: 'RoyallPay transfer clearing', direction: 'credit', amountUsd, memo: transfer.rows[0].id },
      ],
    );
    await ledger.postWithClient(
      client,
      receiver.id,
      { title: `Received ${currency}`, rail: 'RoyallPay P2P' },
      [
        { accountName: 'RoyallPay transfer clearing', direction: 'debit', amountUsd, memo: transfer.rows[0].id },
        { accountName: `Customer ${currency} wallet`, direction: 'credit', amountUsd, memo },
      ],
    );
    await client.query('COMMIT');

    res.status(201).json({ transfer: transfer.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
