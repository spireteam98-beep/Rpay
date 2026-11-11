const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const custody = require('../services/custody');
const ledger = require('../services/ledger');
const { getPrices } = require('../services/prices');
const exchange = require('../services/exchange');
const config = require('../config');

const router = express.Router();
router.use(requireAuth);

const TIER_LIMITS = {
  1: { perTxUsd: 500, label: 'Tier 1' },
  2: { perTxUsd: 10000, label: 'Full KYC' },
};

router.get('/hybrid', async (req, res, next) => {
  try {
    const user = (
      await pool.query(
        `SELECT usd_balance, kes_balance, wallet_index, eth_address, kyc_tier
           FROM users WHERE id = $1`,
        [req.userId],
      )
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const [assets, marketData, pending] = await Promise.all([
      pool.query(
        'SELECT asset, amount FROM crypto_balances WHERE user_id = $1 AND amount > 0 ORDER BY asset',
        [req.userId],
      ),
      exchange.market(),
      pool.query(
        `SELECT id, type, rail, amount_kes, reference, status, created_at
           FROM mobile_money_movements
          WHERE user_id = $1 AND status IN ('PENDING_ADMIN','PENDING_PAYOUT')
          ORDER BY created_at DESC`,
        [req.userId],
      ),
    ]);

    const holdings = assets.rows.map((row) => {
      const live = marketData[row.asset] || { price: 0 };
      const amount = Number(row.amount);
      return {
        asset: row.asset,
        amount,
        priceUsd: live.price,
        valueUsd: Number((amount * live.price).toFixed(2)),
      };
    });
    const cryptoUsd = holdings.reduce((sum, holding) => sum + holding.valueUsd, 0);
    const kesUsd = Number(user.kes_balance) / config.kesPerUsd;

    res.json({
      fiat: {
        KES: Number(user.kes_balance),
        USD: Number(user.usd_balance),
        kesPerUsd: config.kesPerUsd,
      },
      crypto: {
        depositAddress: user.eth_address,
        holdings,
        totalUsd: Number(cryptoUsd.toFixed(2)),
      },
      totalUsd: Number((Number(user.usd_balance) + kesUsd + cryptoUsd).toFixed(2)),
      pendingMobileMoney: pending.rows,
      tier: TIER_LIMITS[user.kyc_tier] || TIER_LIMITS[1],
    });
  } catch (err) {
    next(err);
  }
});

/** GET /wallet/summary — custody address, on-chain balance, live prices. */
router.get('/summary', async (req, res, next) => {
  try {
    const user = (
      await pool.query(
        'SELECT wallet_index, eth_address, kyc_tier FROM users WHERE id = $1',
        [req.userId],
      )
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const [balanceEth, prices] = await Promise.all([
      custody.balanceOf(user.eth_address),
      getPrices(),
    ]);

    const balanceUsd = Number(balanceEth) * prices.ETH.usd;
    res.json({
      network: custody.networkLabel(),
      depositAddress: user.eth_address,
      eth: { balance: balanceEth, usd: Number(balanceUsd.toFixed(2)) },
      prices,
      tier: TIER_LIMITS[user.kyc_tier] || TIER_LIMITS[1],
    });
  } catch (err) {
    next(err);
  }
});

/** GET /wallet/prices — live market data only. */
router.get('/prices', async (_req, res, next) => {
  try {
    res.json(await getPrices());
  } catch (err) {
    next(err);
  }
});

/**
 * POST /wallet/withdraw { toAddress, amountEth }
 * Signs with the customer's derived key, enforces KYC limits,
 * posts a balanced ledger transaction, records the withdrawal.
 */
router.post('/withdraw', async (req, res, next) => {
  try {
    const { toAddress, amountEth } = req.body || {};
    const amount = Number(amountEth);
    if (!toAddress || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'toAddress and a positive amountEth are required' });
    }

    const user = (
      await pool.query(
        'SELECT wallet_index, eth_address, kyc_tier FROM users WHERE id = $1',
        [req.userId],
      )
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const prices = await getPrices();
    const amountUsd = Number((amount * prices.ETH.usd).toFixed(2));
    const limits = TIER_LIMITS[user.kyc_tier] || TIER_LIMITS[1];
    if (amountUsd > limits.perTxUsd) {
      await pool.query(
        `INSERT INTO aml_cases (user_id, kind, subject, details)
         VALUES ($1,'limitBreach',$2,$3)`,
        [req.userId, toAddress, `Attempted $${amountUsd} vs ${limits.label} limit $${limits.perTxUsd}`],
      );
      return res.status(403).json({
        error: `${limits.label} limit is $${limits.perTxUsd} per withdrawal. Complete KYC to raise it.`,
      });
    }

    const { hash } = await custody.sendEth(user.wallet_index, toAddress, amount);

    await pool.query(
      `INSERT INTO withdrawals (user_id, to_address, amount_eth, tx_hash, status)
       VALUES ($1,$2,$3,$4,'Broadcast')`,
      [req.userId, toAddress, amount, hash],
    );

    await ledger.post(
      req.userId,
      { title: `ETH withdrawal to ${toAddress.slice(0, 10)}…`, rail: 'On-chain' },
      [
        { accountName: 'Customer crypto liability', direction: 'debit', amountUsd, memo: 'Custody balance reduced' },
        { accountName: 'On-chain settlement', direction: 'credit', amountUsd, memo: `tx ${hash}` },
      ],
    );

    res.json({ txHash: hash, network: custody.networkLabel() });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /wallet/convert { from: 'USD'|'KES', to: 'USD'|'KES', amount }
 * Moves value between the customer's own USD and KES wallets at the fixed
 * KES_PER_USD rate — the "intentionally convert to USD" bridge between the
 * two currency accounts. No fee/spread yet; that's a pricing decision for
 * later, not a technical one.
 */
router.post('/convert', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const from = String(req.body?.from || '').toUpperCase();
    const to = String(req.body?.to || '').toUpperCase();
    const amount = Number(req.body?.amount);

    if (!['USD', 'KES'].includes(from) || !['USD', 'KES'].includes(to) || from === to) {
      return res.status(400).json({ error: 'from and to must be USD and KES (in either order)' });
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'A positive amount is required' });
    }

    await client.query('BEGIN');
    const user = (
      await client.query(
        'SELECT usd_balance, kes_balance FROM users WHERE id = $1 FOR UPDATE',
        [req.userId],
      )
    ).rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }

    const fromBalance = from === 'USD' ? Number(user.usd_balance) : Number(user.kes_balance);
    if (fromBalance < amount) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `Not enough ${from} balance to convert` });
    }

    const convertedAmount =
      from === 'USD' && to === 'KES'
        ? Number((amount * config.kesPerUsd).toFixed(2))
        : Number((amount / config.kesPerUsd).toFixed(2));
    const usdEquivalent = from === 'USD' ? amount : Number((amount / config.kesPerUsd).toFixed(2));

    const fromColumn = from === 'USD' ? 'usd_balance' : 'kes_balance';
    const toColumn = to === 'USD' ? 'usd_balance' : 'kes_balance';
    await client.query(
      `UPDATE users SET ${fromColumn} = ${fromColumn} - $1, ${toColumn} = ${toColumn} + $2 WHERE id = $3`,
      [amount, convertedAmount, req.userId],
    );

    await ledger.postWithClient(
      client,
      req.userId,
      { title: `Convert ${from} to ${to}`, rail: 'Wayaki FX' },
      [
        { accountName: `Customer ${from} wallet`, direction: 'debit', amountUsd: usdEquivalent, memo: `${amount.toFixed(2)} ${from}` },
        { accountName: `Customer ${to} wallet`, direction: 'credit', amountUsd: usdEquivalent, memo: `${convertedAmount.toFixed(2)} ${to}` },
      ],
    );

    await client.query('COMMIT');
    res.json({ from, to, amount, convertedAmount, kesPerUsd: config.kesPerUsd });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /wallet/withdrawals — history. */
router.get('/withdrawals', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, chain, to_address, amount_eth, tx_hash, status, created_at
         FROM withdrawals WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
