/**
 * One place that turns whatever a person typed to identify someone — email,
 * phone, @username or Fareenn ID (wallet_number) — into a user row. Sending
 * money, messages, follows and admin lookups all go through this so every
 * identifier a user hands out works everywhere.
 */
async function resolveUserByIdentifier(db, identifier, columns = 'id, full_name, email, phone, username, wallet_number, avatar_url, status') {
  const raw = String(identifier || '').trim();
  if (!raw) return null;
  const value = raw.replace(/^@/, '');
  const rows = await db.query(
    `SELECT ${columns} FROM users
      WHERE deletion_requested_at IS NULL
        AND (LOWER(email) = LOWER($1) OR phone = $1 OR LOWER(username) = LOWER($2)
             OR wallet_number = $2)
      LIMIT 1`,
    [raw, value],
  );
  return rows.rows[0] || null;
}

/** Public-safe view of another user: no email, phone or balances. */
function publicProfile(row) {
  if (!row) return null;
  return {
    id: row.id,
    fullName: row.full_name,
    username: row.username || null,
    fareennId: row.wallet_number || null,
    avatarUrl: row.avatar_url || null,
    agentTier: row.agent_tier || null,
  };
}

module.exports = { resolveUserByIdentifier, publicProfile };
