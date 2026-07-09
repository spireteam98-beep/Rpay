/**
 * Live USD prices for the wallet screen — delegates to `exchange.market()`
 * so it shares the same Binance-backed cache as the trading endpoints
 * instead of polling a price feed a second time.
 */
const exchange = require('./exchange');

async function getPrices() {
  const market = await exchange.market();
  const out = {};
  for (const [asset, data] of Object.entries(market)) {
    out[asset] = { usd: data.price, change24h: data.change24h };
  }
  return out;
}

module.exports = { getPrices };
