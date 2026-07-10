const compliance = require('./compliance');

/**
 * Credits an agent's commission, splitting it with their parent (Super
 * Agent or principal Agent) if one is set. Mirrors Safaricom M-Pesa's
 * aggregated-line model: the transacting party keeps (1 - override_rate)
 * of the pool [default 80%] and their immediate parent gets the rest
 * [default 20%] — a single-level split, not a multi-tier cascade, same as
 * how Safaricom pays the sub-agent directly and the principal agent's cut
 * separately, with no further skim further up the chain.
 */
async function creditAgentCommission(client, agent, kind, currency, amount, relatedUserId) {
  const parent = agent.parent_agent_id
    ? (await client.query('SELECT * FROM agents WHERE id = $1', [agent.parent_agent_id])).rows[0]
    : null;

  const overrideRate = parent ? Number(agent.override_rate) : 0;
  const ownAmount = amount * (1 - overrideRate);
  const overrideAmount = amount - ownAmount;

  await creditOne(client, agent.id, kind, currency, ownAmount, relatedUserId);
  if (parent && overrideAmount > 0) {
    await creditOne(client, parent.id, 'override', currency, overrideAmount, agent.user_id);
  }
}

async function creditOne(client, agentId, kind, currency, amount, relatedUserId) {
  const amountUsd = compliance.toUsd(amount, currency);
  await client.query(
    `UPDATE agents SET commission_balance = commission_balance + $1 WHERE id = $2`,
    [amountUsd, agentId],
  );
  await client.query(
    `INSERT INTO agent_commissions (agent_id, kind, currency, amount, related_user_id)
     VALUES ($1,$2,$3,$4,$5)`,
    [agentId, kind, currency, amount, relatedUserId],
  );
}

module.exports = { creditAgentCommission };
