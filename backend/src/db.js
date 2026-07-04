const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: config.databaseUrl.includes('localhost') ? false : { rejectUnauthorized: false },
  max: 10,
});

/** Auto-migration: idempotent schema, runs at boot. */
async function migrate() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      full_name     TEXT NOT NULL,
      phone         TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      kyc_tier      INT  NOT NULL DEFAULT 1,
      phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
      wallet_index  SERIAL,
      eth_address   TEXT,
      created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS ledger_transactions (
      id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id   UUID NOT NULL REFERENCES users(id),
      title     TEXT NOT NULL,
      rail      TEXT NOT NULL,
      status    TEXT NOT NULL DEFAULT 'Posted',
      posted_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS ledger_entries (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      transaction_id UUID NOT NULL REFERENCES ledger_transactions(id),
      account_name  TEXT NOT NULL,
      direction     TEXT NOT NULL CHECK (direction IN ('debit','credit')),
      amount_usd    NUMERIC(18,2) NOT NULL CHECK (amount_usd >= 0),
      memo          TEXT NOT NULL DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS withdrawals (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id    UUID NOT NULL REFERENCES users(id),
      chain      TEXT NOT NULL DEFAULT 'sepolia',
      to_address TEXT NOT NULL,
      amount_eth NUMERIC(28,18) NOT NULL,
      tx_hash    TEXT,
      status     TEXT NOT NULL DEFAULT 'Submitted',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS aml_cases (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id    UUID REFERENCES users(id),
      kind       TEXT NOT NULL,
      subject    TEXT NOT NULL,
      details    TEXT NOT NULL,
      status     TEXT NOT NULL DEFAULT 'Open',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS idx_ledger_tx_user ON ledger_transactions(user_id, posted_at DESC);
    CREATE INDEX IF NOT EXISTS idx_entries_tx ON ledger_entries(transaction_id);
  `);
  console.log('[db] schema ready');
}

module.exports = { pool, migrate };
