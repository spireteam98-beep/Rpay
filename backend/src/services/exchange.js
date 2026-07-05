/**
 * Exchange connectivity.
 *
 * MARKET DATA: always real — Binance public REST API (no key required).
 * ORDERS: two modes, chosen automatically:
 *   - "binance-testnet": BINANCE_API_KEY/SECRET set in .env → signed
 *     MARKET orders on Binance Spot Testnet (real matching engine,
 *     test funds). Get free keys at https://testnet.binance.vision
 *   - "internal": no keys → the order fills instantly on our own book
 *     at the live Binance price (clearly labeled in order history).
 *
 * Mainnet order routing is the same code with the base URL swapped —
 * gated behind licensing/audit like everything else.
 */
const crypto = require('crypto');
const fs = require('fs');

const MAINNET_BASE = 'https://api.binance.com';
const TESTNET_BASE = 'https://testnet.binance.vision';

const SUPPORTED = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'USDT'];

const apiKey = (process.env.BINANCE_API_KEY || '').trim();
const apiSecret = (process.env.BINANCE_SECRET || '').trim();
const keyType = (process.env.BINANCE_KEY_TYPE || 'hmac').trim().toLowerCase();
const privateKeyPath = (process.env.BINANCE_PRIVATE_KEY_PATH || '').trim();
const privateKeyInline = (process.env.BINANCE_PRIVATE_KEY || '').trim().replace(/\\n/g, '\n');
const binanceEnv = (process.env.BINANCE_ENV || 'testnet').trim().toLowerCase();
const tradingEnabled =
  String(process.env.BINANCE_ENABLE_TRADING || '').trim().toLowerCase() === 'true';
const recvWindow = (process.env.BINANCE_RECV_WINDOW || '10000').trim();

function orderMode() {
  if (!apiKey || !tradingEnabled) return 'internal';
  if (keyType === 'hmac' && !apiSecret) return 'internal';
  if (keyType === 'rsa' && !privateKeyInline && !privateKeyPath) return 'internal';
  return binanceEnv === 'mainnet' ? 'binance-mainnet' : 'binance-testnet';
}

function tradingBaseUrl() {
  return binanceEnv === 'mainnet' ? MAINNET_BASE : TESTNET_BASE;
}

function symbolFor(asset) {
  const upper = String(asset || '').toUpperCase();
  if (!SUPPORTED.includes(upper)) {
    throw new Error(`Unsupported asset ${upper}. Supported: ${SUPPORTED.join(', ')}`);
  }
  if (upper === 'USDT') throw new Error('USDT is the quote currency');
  return `${upper}USDT`;
}

// Binance's public market-data API returns 451 (blocked) for requests from
// the US, which is where this backend is hosted (Render free tier) — so
// market data comes from CoinGecko instead, which has no such restriction.
// Actual order placement below still targets Binance (testnet or, later,
// licensed mainnet), since that's unaffected while BINANCE_API_KEY is unset.
const COINGECKO_BASE = 'https://api.coingecko.com/api/v3';
const COINGECKO_IDS = {
  BTC: 'bitcoin',
  ETH: 'ethereum',
  BNB: 'binancecoin',
  SOL: 'solana',
  ADA: 'cardano',
};

/** Live prices + 24h stats for all supported assets (CoinGecko). */
async function market() {
  const ids = Object.values(COINGECKO_IDS).join(',');
  const res = await fetch(`${COINGECKO_BASE}/coins/markets?vs_currency=usd&ids=${ids}`);
  if (!res.ok) throw new Error(`Market data unavailable (${res.status})`);
  const rows = await res.json();
  const idToAsset = Object.fromEntries(
    Object.entries(COINGECKO_IDS).map(([asset, id]) => [id, asset]),
  );
  const out = {};
  for (const row of rows) {
    const asset = idToAsset[row.id];
    if (!asset) continue;
    out[asset] = {
      price: Number(row.current_price),
      change24h: Number(Number(row.price_change_percentage_24h || 0).toFixed(2)),
      high24h: Number(row.high_24h),
      low24h: Number(row.low_24h),
      volume24h: Number(row.total_volume),
    };
  }
  out.USDT = { price: 1, change24h: 0, high24h: 1, low24h: 1, volume24h: 0 };
  return out;
}

/** Live last price for one asset. */
async function lastPrice(asset) {
  const upper = String(asset || '').toUpperCase();
  if (upper === 'USDT') return 1;
  if (!SUPPORTED.includes(upper)) {
    throw new Error(`Unsupported asset ${upper}. Supported: ${SUPPORTED.join(', ')}`);
  }
  const data = await market();
  const entry = data[upper];
  if (!entry) throw new Error(`Price unavailable for ${upper}`);
  return entry.price;
}

async function publicPing() {
  const res = await fetch(`${MAINNET_BASE}/api/v3/ping`);
  if (!res.ok) throw new Error(`Binance ping failed (${res.status})`);
  return { ok: true };
}

/** Signed request against the configured Binance Spot API environment. */
async function signedRequest(method, path, params = {}) {
  if (!apiKey) {
    throw new Error('Binance API key is required');
  }
  const query = new URLSearchParams({
    ...params,
    timestamp: Date.now().toString(),
    recvWindow,
  }).toString();
  const signature = signPayload(query);
  const res = await fetch(`${tradingBaseUrl()}${path}?${query}&signature=${signature}`, {
    method,
    headers: { 'X-MBX-APIKEY': apiKey },
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(body.msg || `Exchange rejected the order (${res.status})`);
  }
  return body;
}

function signPayload(payload) {
  if (keyType === 'rsa') {
    const privateKey = privateKeyInline || fs.readFileSync(privateKeyPath, 'utf8');
    return encodeURIComponent(
      crypto.sign('RSA-SHA256', Buffer.from(payload), privateKey).toString('base64'),
    );
  }

  if (!apiSecret) throw new Error('Binance HMAC secret is required');
  return crypto.createHmac('sha256', apiSecret).update(payload).digest('hex');
}

async function accountSnapshot() {
  if (orderMode() === 'internal') {
    return { mode: orderMode(), connected: false, reason: 'Trading disabled or keys missing' };
  }
  const account = await signedRequest('GET', '/api/v3/account');
  return {
    mode: orderMode(),
    connected: true,
    canTrade: Boolean(account.canTrade),
    balances: (account.balances || [])
      .filter((row) => Number(row.free) > 0 || Number(row.locked) > 0)
      .map((row) => ({
        asset: row.asset,
        free: Number(row.free),
        locked: Number(row.locked),
      })),
  };
}

/**
 * Execute a market order for `quoteUsd` worth of `asset`.
 * side: 'BUY' | 'SELL'. Returns { qty, price, quoteUsd, mode, exchangeOrderId }.
 */
async function placeMarketOrder({ side, asset, quoteUsd }) {
  const symbol = symbolFor(asset);
  const price = await lastPrice(asset);

  if (orderMode().startsWith('binance-')) {
    const params =
      side === 'BUY'
        ? { symbol, side, type: 'MARKET', quoteOrderQty: quoteUsd.toFixed(2), newOrderRespType: 'FULL' }
        : { symbol, side, type: 'MARKET', quoteOrderQty: quoteUsd.toFixed(2), newOrderRespType: 'FULL' };
    const order = await signedRequest('POST', '/api/v3/order', params);
    const executedQty = Number(order.executedQty || 0);
    const cumQuote = Number(order.cummulativeQuoteQty || 0);
    return {
      qty: executedQty || quoteUsd / price,
      price: executedQty > 0 && cumQuote > 0 ? cumQuote / executedQty : price,
      quoteUsd: cumQuote || quoteUsd,
      mode: orderMode(),
      exchangeOrderId: String(order.orderId || ''),
    };
  }

  // Internal fill at the live exchange price.
  return {
    qty: quoteUsd / price,
    price,
    quoteUsd,
    mode: 'internal',
    exchangeOrderId: null,
  };
}

module.exports = {
  accountSnapshot,
  market,
  lastPrice,
  placeMarketOrder,
  publicPing,
  orderMode,
  SUPPORTED,
};
