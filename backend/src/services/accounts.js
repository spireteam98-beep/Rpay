/**
 * Separate money accounts besides a person's own wallet (users.*_balance):
 *
 *   Business account — merchants.balance_usd / balance_kes. Every card,
 *     till and payment-link sale lands here, not in the owner's wallet.
 *     The owner moves money to their wallet when they choose.
 *   Agent account — agents.float_usd / float_kes (cash float) plus the
 *     existing agents.commission_balance (USD). A cash-in spends float, a
 *     cash-out adds to it; the agent tops it up from their wallet.
 *
 * All helpers run inside the caller's transaction and lock the row first.
 */

const CURRENCIES = ['USD', 'KES'];
const merchantCol = (currency) => (currency === 'KES' ? 'balance_kes' : 'balance_usd');
const floatCol = (currency) => (currency === 'KES' ? 'float_kes' : 'float_usd');
const walletCol = (currency) => (currency === 'KES' ? 'kes_balance' : 'usd_balance');

function cleanAmount(value) {
  const amount = Math.round(Number(value) * 100) / 100;
  return Number.isFinite(amount) && amount > 0 ? amount : null;
}

async function creditMerchant(client, merchantId, currency, amount) {
  await client.query(
    `UPDATE merchants SET ${merchantCol(currency)} = ${merchantCol(currency)} + $1 WHERE id = $2`,
    [amount, merchantId],
  );
}

/** Returns false (and changes nothing) when the business balance is short. */
async function debitMerchant(client, merchantId, currency, amount) {
  const col = merchantCol(currency);
  const row = (await client.query(`SELECT ${col} AS bal FROM merchants WHERE id = $1 FOR UPDATE`, [merchantId])).rows[0];
  if (!row || Number(row.bal) < amount) return false;
  await client.query(`UPDATE merchants SET ${col} = ${col} - $1 WHERE id = $2`, [amount, merchantId]);
  return true;
}

async function creditAgentFloat(client, agentId, currency, amount) {
  await client.query(`UPDATE agents SET ${floatCol(currency)} = ${floatCol(currency)} + $1 WHERE id = $2`, [amount, agentId]);
}

/** Returns false (and changes nothing) when the agent's float is short. */
async function debitAgentFloat(client, agentId, currency, amount) {
  const col = floatCol(currency);
  const row = (await client.query(`SELECT ${col} AS bal FROM agents WHERE id = $1 FOR UPDATE`, [agentId])).rows[0];
  if (!row || Number(row.bal) < amount) return false;
  await client.query(`UPDATE agents SET ${col} = ${col} - $1 WHERE id = $2`, [amount, agentId]);
  return true;
}

/** Returns false (and changes nothing) when the wallet is short. */
async function debitWallet(client, userId, currency, amount) {
  const col = walletCol(currency);
  const row = (await client.query(`SELECT ${col} AS bal FROM users WHERE id = $1 FOR UPDATE`, [userId])).rows[0];
  if (!row || Number(row.bal) < amount) return false;
  await client.query(`UPDATE users SET ${col} = ${col} - $1 WHERE id = $2`, [amount, userId]);
  return true;
}

async function creditWallet(client, userId, currency, amount) {
  await client.query(`UPDATE users SET ${walletCol(currency)} = ${walletCol(currency)} + $1 WHERE id = $2`, [amount, userId]);
}

module.exports = {
  CURRENCIES, cleanAmount, merchantCol, floatCol, walletCol,
  creditMerchant, debitMerchant, creditAgentFloat, debitAgentFloat, debitWallet, creditWallet,
};
