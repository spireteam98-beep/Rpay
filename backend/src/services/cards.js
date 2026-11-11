const crypto = require('crypto');

/**
 * Issuing a Fareenn card to a user by its serial number (UID) — used when a
 * reviewer scans a card while approving a customer's KYC. The card needs no
 * data written on it: it is recognised by serial at the till (see
 * routes/nfcCards.js). Card number, expiry and CVC are filled in the first
 * time the holder opens their cards.
 */
const MAX_CARDS_PER_USER = 2;

function cleanUid(value) {
  const uid = String(value || '').replace(/[^0-9a-fA-F]/g, '').toUpperCase();
  if (uid.length < 8 || uid.length > 20 || uid.length % 2) return null;
  return uid;
}

/** Inserts the card inside the caller's transaction. Returns { card } or { error: [status, message] }. */
async function issueCardToUser(client, { uid, userId, issuedBy, label = 'Fareenn card' }) {
  const clean = cleanUid(uid);
  if (!clean) return { error: [400, 'The card could not be read. Scan it again.'] };
  const taken = (await client.query('SELECT user_id FROM nfc_cards WHERE uid = $1', [clean])).rows[0];
  if (taken) {
    return {
      error: [409, taken.user_id === userId
        ? 'This card is already linked to this customer.'
        : 'This card is already linked to another Fareenn account.'],
    };
  }
  const count = (
    await client.query(`SELECT COUNT(*)::int AS n FROM nfc_cards WHERE user_id = $1 AND status <> 'BLOCKED'`, [userId])
  ).rows[0].n;
  if (count >= MAX_CARDS_PER_USER) {
    return { error: [400, `This customer already has ${MAX_CARDS_PER_USER} cards. Block an old card first.`] };
  }
  const card = (
    await client.query(
      `INSERT INTO nfc_cards (uid, token, user_id, label, issued_by, chip_type)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, uid, status`,
      [clean, crypto.randomBytes(16).toString('base64url'), userId, label, issuedBy,
        clean.length === 8 ? 'MIFARE_CLASSIC_1K' : 'NTAG'],
    )
  ).rows[0];
  return { card };
}

module.exports = { cleanUid, issueCardToUser, MAX_CARDS_PER_USER };
