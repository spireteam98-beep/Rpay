/**
 * Shared agent-hierarchy constants — Country Agent (one per country) sits
 * above Super Agent, which sits above Agent (the customer-facing retail
 * tier), which sits above Sub-Agent. See agents.js and admin.js.
 */
const TIER_ORDER = ['COUNTRY_AGENT', 'SUPER_AGENT', 'AGENT', 'SUB_AGENT'];

/** Which tier a given tier may recruit/sponsor directly beneath itself. */
const RECRUIT_TIER = {
  COUNTRY_AGENT: 'SUPER_AGENT',
  SUPER_AGENT: 'AGENT',
  AGENT: 'SUB_AGENT',
};

/**
 * Country Agent and Super Agent manage their network's float and
 * commissions but don't serve walk-in customers directly — mirrors M-Pesa's
 * Dealer model, where Dealers manage liquidity and retail agents handle cash.
 */
const CAN_TRANSACT = { AGENT: true, SUB_AGENT: true };

/** Placeholder float/limit defaults — tune once real usage data exists. */
const TIER_LIMITS_USD = {
  SUPER_AGENT: { minFloatUsd: 1500, dailyLimitUsd: 15000 },
  AGENT: { minFloatUsd: 750, dailyLimitUsd: 5000 },
  SUB_AGENT: { minFloatUsd: 150, dailyLimitUsd: 1000 },
};

function tierRank(tier) {
  return TIER_ORDER.indexOf(tier);
}

/** True if `parentTier` sits strictly above `childTier` in the ladder. */
function isValidParentTier(parentTier, childTier) {
  const p = tierRank(parentTier);
  const c = tierRank(childTier);
  return p !== -1 && c !== -1 && p < c;
}

module.exports = { TIER_ORDER, RECRUIT_TIER, CAN_TRANSACT, TIER_LIMITS_USD, tierRank, isValidParentTier };
