/**
 * Live USD prices via CoinGecko public API (no key needed),
 * cached for 60 seconds to stay well inside rate limits.
 */
const IDS = 'bitcoin,ethereum,tether,binancecoin,solana,cardano';
const URL = `https://api.coingecko.com/api/v3/simple/price?ids=${IDS}&vs_currencies=usd&include_24hr_change=true`;

let cache = { at: 0, data: null };

async function getPrices() {
  const now = Date.now();
  if (cache.data && now - cache.at < 60_000) return cache.data;

  const res = await fetch(URL, { headers: { accept: 'application/json' } });
  if (!res.ok) {
    if (cache.data) return cache.data; // serve stale on upstream failure
    throw new Error(`Price feed unavailable (${res.status})`);
  }
  const raw = await res.json();
  const data = {
    BTC: shape(raw.bitcoin),
    ETH: shape(raw.ethereum),
    USDT: shape(raw.tether),
    BNB: shape(raw.binancecoin),
    SOL: shape(raw.solana),
    ADA: shape(raw.cardano),
  };
  cache = { at: now, data };
  return data;
}

function shape(entry) {
  if (!entry) return { usd: 0, change24h: 0 };
  return {
    usd: entry.usd ?? 0,
    change24h: Number((entry.usd_24h_change ?? 0).toFixed(2)),
  };
}

module.exports = { getPrices };
