/**
 * KYC review and Fareenn account numbers (Wallet IDs).
 *
 * A Wallet ID is issued the moment a customer's KYC is approved:
 *   [approver][region][serial]
 *   approver: 1 = Agent, 2 = Trustee Agent, 0 = Fareenn HQ (admin)
 *   region:   Banadir 2, Galmudug 3, Hirshabelle 4, Puntland 5,
 *             Jubaland 6, South West 7, Somaliland 8, Outside Somalia 9
 *   serial:   next number in that approver+region group, at least 2 digits
 * Example: 1202 = approved by an Agent, Banadir, 2nd customer in that group.
 */

const REGIONS = {
  '2': 'Banadir',
  '3': 'Galmudug',
  '4': 'Hirshabelle',
  '5': 'Puntland',
  '6': 'Jubaland',
  '7': 'South West',
  '8': 'Somaliland',
  '9': 'Outside Somalia',
};

function approverDigit(agent) {
  if (!agent) return '0';
  return agent.tier === 'TRUSTEE_AGENT' ? '2' : '1';
}

async function nextWalletNumber(client, approver, regionCode) {
  const region = REGIONS[regionCode] ? regionCode : '9';
  const prefix = `${approver}${region}`;
  const row = (
    await client.query(
      `INSERT INTO wallet_number_counters (prefix, last_serial) VALUES ($1, 1)
       ON CONFLICT (prefix) DO UPDATE SET last_serial = wallet_number_counters.last_serial + 1
       RETURNING last_serial`,
      [prefix],
    )
  ).rows[0];
  return `${prefix}${String(row.last_serial).padStart(2, '0')}`;
}

/** Pending customers for a reviewer. agent = null means Fareenn HQ (admin),
 * which reviews customers who joined without an agent. */
async function listPending(client, agent) {
  const where = agent
    ? 'u.referred_by_agent_id = $1'
    : 'u.referred_by_agent_id IS NULL';
  const params = agent ? [agent.id] : [];
  const rows = await client.query(
    `SELECT u.id, u.full_name, u.phone, u.email, u.gender, u.address, u.region_code,
            u.kyc_submitted_at, d.doc_type, d.doc_number
       FROM users u
       LEFT JOIN LATERAL (
         SELECT doc_type, doc_number FROM kyc_documents
          WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1
       ) d ON TRUE
      WHERE ${where} AND u.kyc_status = 'PENDING_REVIEW'
      ORDER BY u.kyc_submitted_at ASC`,
    params,
  );
  return rows.rows.map((r) => ({ ...r, region: REGIONS[r.region_code] || 'Unknown' }));
}

/** The latest document photos for one customer, as base64. */
async function documentImages(client, userId) {
  const d = (
    await client.query(
      `SELECT image, content_type, back_image, back_content_type,
              selfie_image, selfie_content_type
         FROM kyc_documents WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [userId],
    )
  ).rows[0];
  if (!d) return null;
  const enc = (buf, type) => (buf ? { base64: buf.toString('base64'), contentType: type } : null);
  return {
    front: enc(d.image, d.content_type),
    back: enc(d.back_image, d.back_content_type),
    selfie: enc(d.selfie_image, d.selfie_content_type),
  };
}

/** Checks the reviewer may act on this customer; returns the customer row. */
async function loadForReview(client, agent, userId) {
  const u = (
    await client.query('SELECT * FROM users WHERE id = $1 FOR UPDATE', [userId])
  ).rows[0];
  if (!u) return { error: [404, 'Customer not found'] };
  const mine = agent ? u.referred_by_agent_id === agent.id : !u.referred_by_agent_id;
  if (!mine) return { error: [403, 'This customer is not in your review list'] };
  if (u.kyc_status !== 'PENDING_REVIEW') {
    return { error: [409, 'This customer has already been reviewed'] };
  }
  return { user: u };
}

async function approve(client, agent, reviewerUserId, userId) {
  const { user, error } = await loadForReview(client, agent, userId);
  if (error) return { error };
  const walletNumber =
    user.wallet_number || (await nextWalletNumber(client, approverDigit(agent), user.region_code));
  await client.query(
    `UPDATE users
        SET kyc_status = 'APPROVED', kyc_tier = GREATEST(kyc_tier, 2),
            wallet_number = $1, kyc_reviewed_by = $2, kyc_reviewed_at = now(),
            kyc_reject_reason = NULL
      WHERE id = $3`,
    [walletNumber, reviewerUserId, userId],
  );
  await client.query(
    `UPDATE kyc_documents SET status = 'APPROVED'
      WHERE id = (SELECT id FROM kyc_documents WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1)`,
    [userId],
  );
  return { walletNumber, fullName: user.full_name };
}

async function reject(client, agent, reviewerUserId, userId, reason) {
  const { error } = await loadForReview(client, agent, userId);
  if (error) return { error };
  await client.query(
    `UPDATE users
        SET kyc_status = 'REJECTED', kyc_reviewed_by = $1, kyc_reviewed_at = now(),
            kyc_reject_reason = $2
      WHERE id = $3`,
    [reviewerUserId, reason, userId],
  );
  await client.query(
    `UPDATE kyc_documents SET status = 'REJECTED'
      WHERE id = (SELECT id FROM kyc_documents WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1)`,
    [userId],
  );
  return { rejected: true };
}

module.exports = { REGIONS, listPending, documentImages, approve, reject };
