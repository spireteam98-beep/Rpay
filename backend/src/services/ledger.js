const { pool } = require('../db');

/**
 * Post a balanced double-entry transaction.
 * entries: [{ accountName, direction: 'debit'|'credit', amountUsd, memo }]
 * Throws if debits !== credits (to the cent).
 */
async function post(userId, { title, rail, status = 'Posted' }, entries) {
  const debits = entries
    .filter((e) => e.direction === 'debit')
    .reduce((sum, e) => sum + Number(e.amountUsd), 0);
  const credits = entries
    .filter((e) => e.direction === 'credit')
    .reduce((sum, e) => sum + Number(e.amountUsd), 0);
  if (Math.abs(debits - credits) > 0.005) {
    throw new Error(`Unbalanced ledger transaction: D ${debits} vs C ${credits}`);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const tx = await client.query(
      `INSERT INTO ledger_transactions (user_id, title, rail, status)
       VALUES ($1,$2,$3,$4) RETURNING id, posted_at`,
      [userId, title, rail, status],
    );
    const txId = tx.rows[0].id;
    for (const entry of entries) {
      await client.query(
        `INSERT INTO ledger_entries (transaction_id, account_name, direction, amount_usd, memo)
         VALUES ($1,$2,$3,$4,$5)`,
        [txId, entry.accountName, entry.direction, entry.amountUsd, entry.memo || ''],
      );
    }
    await client.query('COMMIT');
    return { id: txId, postedAt: tx.rows[0].posted_at };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function listForUser(userId, limit = 50) {
  const txs = await pool.query(
    `SELECT id, title, rail, status, posted_at
       FROM ledger_transactions WHERE user_id = $1
      ORDER BY posted_at DESC LIMIT $2`,
    [userId, limit],
  );
  const ids = txs.rows.map((row) => row.id);
  let entries = { rows: [] };
  if (ids.length > 0) {
    entries = await pool.query(
      `SELECT transaction_id, account_name, direction, amount_usd, memo
         FROM ledger_entries WHERE transaction_id = ANY($1)`,
      [ids],
    );
  }
  return txs.rows.map((tx) => ({
    ...tx,
    entries: entries.rows.filter((entry) => entry.transaction_id === tx.id),
  }));
}

module.exports = { post, listForUser };
