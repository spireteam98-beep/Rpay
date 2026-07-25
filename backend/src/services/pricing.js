const config = require('../config');

/**
 * Agent-withdrawal fee bands — mirrors Safaricom M-Pesa's published tariff
 * for "Withdrawal from M-PESA Agent" (KES), since that's the transaction
 * Wayaki's agent-assisted withdrawal is directly analogous to. Deposits stay
 * free to the customer (M-Pesa's "All Deposits FREE" policy) — the agent's
 * deposit commission is a Wayaki-funded incentive instead, see agents.js.
 */
const WITHDRAWAL_FEE_BANDS_KES = [
  { max: 100, fee: 11 },
  { max: 500, fee: 29 },
  { max: 1000, fee: 29 },
  { max: 1500, fee: 29 },
  { max: 2500, fee: 29 },
  { max: 3500, fee: 52 },
  { max: 5000, fee: 69 },
  { max: 7500, fee: 87 },
  { max: 10000, fee: 115 },
  { max: 15000, fee: 167 },
  { max: 20000, fee: 185 },
  { max: 35000, fee: 197 },
  { max: 50000, fee: 278 },
  { max: 250000, fee: 309 },
];

const MIN_WITHDRAWAL_KES = 50;
const MAX_WITHDRAWAL_KES = 250000;

/** Withdrawal fee in KES for a KES cash-out amount at an agent. */
function withdrawalFeeKes(amountKes) {
  if (amountKes < MIN_WITHDRAWAL_KES) {
    throw new Error(`Minimum agent withdrawal is KES ${MIN_WITHDRAWAL_KES}`);
  }
  if (amountKes > MAX_WITHDRAWAL_KES) {
    throw new Error(`Maximum agent withdrawal is KES ${MAX_WITHDRAWAL_KES.toLocaleString()}`);
  }
  const band = WITHDRAWAL_FEE_BANDS_KES.find((b) => amountKes <= b.max);
  return band.fee;
}

/** Same fee schedule, applied to a withdrawal denominated in KES or USD. */
function withdrawalFee(amount, currency) {
  const amountKes = currency === 'KES' ? amount : amount * config.kesPerUsd;
  const feeKes = withdrawalFeeKes(amountKes);
  return currency === 'KES' ? feeKes : feeKes / config.kesPerUsd;
}

module.exports = { withdrawalFee, withdrawalFeeKes, MIN_WITHDRAWAL_KES, MAX_WITHDRAWAL_KES };
