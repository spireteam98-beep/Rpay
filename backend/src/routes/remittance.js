const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const compliance = require('../services/compliance');
const config = require('../config');

const router = express.Router();
router.use(requireAuth);

function destinationAmount(sourceAmount, destinationCurrency) {
  return destinationCurrency === 'KES'
    ? Number((sourceAmount * config.kesPerUsd).toFixed(2))
    : Number(sourceAmount.toFixed(2));
}

router.post('/quote', (req, res) => {
  const sourceAmount = Number(req.body?.sourceAmount);
  const destinationCurrency = String(req.body?.destinationCurrency || 'KES').toUpperCase();
  if (!Number.isFinite(sourceAmount) || sourceAmount <= 0 || !['KES', 'USD'].includes(destinationCurrency)) {
    return res.status(400).json({ error: 'sourceAmount and destinationCurrency KES/USD are required' });
  }
  res.json({
    sourceCurrency: 'USD',
    sourceAmount,
    destinationCurrency,
    destinationAmount: destinationAmount(sourceAmount, destinationCurrency),
    rate: destinationCurrency === 'KES' ? config.kesPerUsd : 1,
    feeUsd: 0,
  });
});

router.post('/send', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const sourceAmount = Number(req.body?.sourceAmount);
    const destinationCurrency = String(req.body?.destinationCurrency || 'KES').toUpperCase();
    const recipientPhone = String(req.body?.recipientPhone || '').trim();
    if (!recipientPhone || !Number.isFinite(sourceAmount) || sourceAmount <= 0 ||
        !['KES', 'USD'].includes(destinationCurrency)) {
      return res.status(400).json({ error: 'recipientPhone, sourceAmount and destinationCurrency are required' });
    }

    await client.query('BEGIN');
    const limit = await compliance.checkUserLimit(
      client,
      req.userId,
      sourceAmount,
      `Remittance to ${recipientPhone}`,
    );
    if (!limit.allowed) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Remittance requires compliance review' });
    }

    const sender = (
      await client.query('SELECT usd_balance FROM users WHERE id = $1 FOR UPDATE', [req.userId])
    ).rows[0];
    if (Number(sender.usd_balance) < sourceAmount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Not enough USD balance' });
    }
    const recipient = (
      await client.query('SELECT id FROM users WHERE phone = $1 FOR UPDATE', [recipientPhone])
    ).rows[0];
    if (!recipient) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Recipient wallet not found' });
    }

    const destAmount = destinationAmount(sourceAmount, destinationCurrency);
    const destColumn = destinationCurrency === 'KES' ? 'kes_balance' : 'usd_balance';
    await client.query('UPDATE users SET usd_balance = usd_balance - $1 WHERE id = $2', [
      sourceAmount,
      req.userId,
    ]);
    await client.query(`UPDATE users SET ${destColumn} = ${destColumn} + $1 WHERE id = $2`, [
      destAmount,
      recipient.id,
    ]);
    const remittance = await client.query(
      `INSERT INTO remittances
        (sender_user_id, recipient_user_id, recipient_phone, source_amount,
         destination_currency, destination_amount, rate)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [
        req.userId,
        recipient.id,
        recipientPhone,
        sourceAmount,
        destinationCurrency,
        destAmount,
        destinationCurrency === 'KES' ? config.kesPerUsd : 1,
      ],
    );

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Remittance sent to ${recipientPhone}`, rail: 'Remittance' },
      [
        { accountName: 'Customer USD wallet', direction: 'debit', amountUsd: sourceAmount, memo: remittance.rows[0].id },
        { accountName: 'Remittance clearing', direction: 'credit', amountUsd: sourceAmount, memo: recipientPhone },
      ],
    );
    await ledger.postWithClient(
      client,
      recipient.id,
      { title: 'Remittance received', rail: 'Remittance' },
      [
        { accountName: 'Remittance clearing', direction: 'debit', amountUsd: sourceAmount, memo: remittance.rows[0].id },
        { accountName: `Customer ${destinationCurrency} wallet`, direction: 'credit', amountUsd: sourceAmount, memo: recipientPhone },
      ],
    );
    await client.query('COMMIT');

    res.status(201).json({ remittance: remittance.rows[0] });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
