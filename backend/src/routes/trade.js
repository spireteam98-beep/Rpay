const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const exchange = require('../services/exchange');
const ledger = require('../services/ledger');
const config = require('../config');

const router = express.Router();

/** GET /trade/market — live prices, public (no auth needed). */
router.get('/market', async (_req, res, next) => {
  try {
    res.json({
      executionMode: customerExecutionMode(exchange.orderMode()),
      assets: await exchange.market(),
    });
  } catch (err) {
    next(err);
  }
});

router.use(requireAuth);

const TIER_LIMITS = { 1: { perTxUsd: 500, label: 'Tier 1' }, 2: { perTxUsd: 10000, label: 'Full KYC' } };

function customerExecutionMode(mode) {
  return String(mode || '').startsWith('binance-') ? 'external-market' : 'internal';
}

/** GET /trade/balances — USD funding balance + custody assets, valued live. */
router.get('/balances', async (req, res, next) => {
  try {
    const user = (
      await pool.query('SELECT usd_balance, kes_balance, kyc_tier FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const assets = await pool.query(
      'SELECT asset, amount FROM crypto_balances WHERE user_id = $1 AND amount > 0 ORDER BY asset',
      [req.userId],
    );
    const marketData = await exchange.market();

    const holdings = assets.rows.map((row) => {
      const live = marketData[row.asset] || { price: 0, change24h: 0 };
      const amount = Number(row.amount);
      return {
        asset: row.asset,
        amount,
        price: live.price,
        change24h: live.change24h,
        valueUsd: Number((amount * live.price).toFixed(2)),
      };
    });

    res.json({
      usdBalance: Number(user.usd_balance),
      kesBalance: Number(user.kes_balance),
      kesPerUsd: config.kesPerUsd,
      holdings,
      totalCryptoUsd: Number(
        holdings.reduce((sum, h) => sum + h.valueUsd, 0).toFixed(2),
      ),
      tier: TIER_LIMITS[user.kyc_tier] || TIER_LIMITS[1],
      executionMode: customerExecutionMode(exchange.orderMode()),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /trade/buy { asset, usdAmount } — market-buy crypto with USD balance.
 * POST /trade/sell { asset, usdAmount } — market-sell crypto back to USD.
 */
async function executeTrade(req, res, next, side) {
  const client = await pool.connect();
  try {
    const { asset, usdAmount, kesAmount } = req.body || {};
    const quoteCurrency = String(req.body?.quoteCurrency || (kesAmount ? 'KES' : 'USD')).toUpperCase();
    if (!['USD', 'KES'].includes(quoteCurrency)) {
      return res.status(400).json({ error: 'quoteCurrency must be USD or KES' });
    }
    const quoteInput = quoteCurrency === 'KES' ? Number(kesAmount) : Number(usdAmount);
    if (!asset || !Number.isFinite(quoteInput) || quoteInput <= 0) {
      return res.status(400).json({ error: 'asset and a positive usdAmount or kesAmount are required' });
    }
    const quoteUsd = quoteCurrency === 'KES'
      ? Number((quoteInput / config.kesPerUsd).toFixed(2))
      : Number(quoteInput.toFixed(2));
    if (!Number.isFinite(quoteUsd) || quoteUsd <= 0) {
      return res.status(400).json({ error: 'Trade amount is too small' });
    }
    if (side === 'SELL' && quoteCurrency !== 'USD') {
      return res.status(400).json({ error: 'Crypto sells settle to the USD trading wallet for now' });
    }

    const user = (
      await client.query('SELECT usd_balance, kes_balance, kyc_tier FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const limits = TIER_LIMITS[user.kyc_tier] || TIER_LIMITS[1];
    if (quoteUsd > limits.perTxUsd) {
      await client.query(
        `INSERT INTO aml_cases (user_id, kind, subject, details)
         VALUES ($1,'limitBreach',$2,$3)`,
        [req.userId, `${side} ${asset}`, `Attempted $${quoteUsd} vs ${limits.label} limit $${limits.perTxUsd}`],
      );
      return res.status(403).json({
        error: `${limits.label} limit is $${limits.perTxUsd} per trade. Complete KYC to raise it.`,
      });
    }

    if (side === 'BUY' && quoteCurrency === 'USD' && Number(user.usd_balance) < quoteUsd) {
      return res.status(400).json({ error: 'Not enough USD balance' });
    }
    if (side === 'BUY' && quoteCurrency === 'KES' && Number(user.kes_balance) < quoteInput) {
      return res.status(400).json({ error: 'Not enough KES balance' });
    }

    // Execute against the exchange (testnet or internal fill at live price).
    const fill = await exchange.placeMarketOrder({ side, asset, quoteUsd });
    const upperAsset = String(asset).toUpperCase();

    if (side === 'SELL') {
      const held = (
        await client.query(
          'SELECT amount FROM crypto_balances WHERE user_id = $1 AND asset = $2',
          [req.userId, upperAsset],
        )
      ).rows[0];
      if (!held || Number(held.amount) < fill.qty) {
        return res.status(400).json({ error: `Not enough ${upperAsset} to sell` });
      }
    }

    await client.query('BEGIN');
    if (side === 'BUY') {
      if (quoteCurrency === 'KES') {
        await client.query(
          'UPDATE users SET kes_balance = kes_balance - $1 WHERE id = $2',
          [quoteInput, req.userId],
        );
      } else {
        await client.query(
          'UPDATE users SET usd_balance = usd_balance - $1 WHERE id = $2',
          [fill.quoteUsd, req.userId],
        );
      }
      await client.query(
        `INSERT INTO crypto_balances (user_id, asset, amount) VALUES ($1,$2,$3)
         ON CONFLICT (user_id, asset) DO UPDATE SET amount = crypto_balances.amount + $3`,
        [req.userId, upperAsset, fill.qty],
      );
    } else {
      await client.query(
        'UPDATE crypto_balances SET amount = amount - $1 WHERE user_id = $2 AND asset = $3',
        [fill.qty, req.userId, upperAsset],
      );
      await client.query(
        'UPDATE users SET usd_balance = usd_balance + $1 WHERE id = $2',
        [fill.quoteUsd, req.userId],
      );
    }
    const order = await client.query(
      `INSERT INTO orders (user_id, side, asset, qty, price, quote_usd, mode, exchange_order_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, created_at`,
      [req.userId, side, upperAsset, fill.qty, fill.price, fill.quoteUsd, fill.mode, fill.exchangeOrderId],
    );
    await client.query('COMMIT');

    // Double-entry: value moves between fiat and crypto liability books.
    const usd = Number(fill.quoteUsd.toFixed(2));
    await ledger.post(
      req.userId,
      { title: `${side} ${fill.qty.toFixed(6)} ${upperAsset} @ $${fill.price.toFixed(2)}`, rail: fill.mode },
      side === 'BUY'
        ? [
            { accountName: quoteCurrency === 'KES' ? 'Customer KES wallet' : 'Customer USD wallet', direction: 'debit', amountUsd: usd, memo: 'Trade settlement' },
            { accountName: 'Customer crypto liability', direction: 'credit', amountUsd: usd, memo: `+${fill.qty.toFixed(6)} ${upperAsset}` },
          ]
        : [
            { accountName: 'Customer crypto liability', direction: 'debit', amountUsd: usd, memo: `-${fill.qty.toFixed(6)} ${upperAsset}` },
            { accountName: 'Customer USD wallet', direction: 'credit', amountUsd: usd, memo: 'Trade settlement' },
          ],
    );

    res.json({
      orderId: order.rows[0].id,
      side,
      asset: upperAsset,
      qty: Number(fill.qty.toFixed(8)),
      price: Number(fill.price.toFixed(2)),
      usd,
      quoteCurrency,
      kes: quoteCurrency === 'KES' ? Number(quoteInput.toFixed(2)) : undefined,
      executionMode: customerExecutionMode(fill.mode),
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* not in tx */}
    next(err);
  } finally {
    client.release();
  }
}

router.post('/buy', (req, res, next) => executeTrade(req, res, next, 'BUY'));
router.post('/sell', (req, res, next) => executeTrade(req, res, next, 'SELL'));

/** GET /trade/orders — fill history. */
router.get('/orders', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT id, side, asset, qty, price, quote_usd, mode, status, created_at
         FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows.map((row) => ({
      ...row,
      executionMode: customerExecutionMode(row.mode),
      mode: undefined,
    })));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
