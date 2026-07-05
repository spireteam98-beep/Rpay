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
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    CREATE TABLE IF NOT EXISTS users (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      full_name     TEXT NOT NULL,
      email         TEXT,
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
    ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower
      ON users (LOWER(email))
      WHERE email IS NOT NULL;

    -- Trading: sandbox USD funding + custody asset balances + order history
    ALTER TABLE users ADD COLUMN IF NOT EXISTS usd_balance NUMERIC(18,2) NOT NULL DEFAULT 10000;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS kes_balance NUMERIC(18,2) NOT NULL DEFAULT 0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'customer';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

    CREATE TABLE IF NOT EXISTS crypto_balances (
      user_id UUID NOT NULL REFERENCES users(id),
      asset   TEXT NOT NULL,
      amount  NUMERIC(28,10) NOT NULL DEFAULT 0 CHECK (amount >= 0),
      PRIMARY KEY (user_id, asset)
    );

    CREATE TABLE IF NOT EXISTS orders (
      id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id           UUID NOT NULL REFERENCES users(id),
      side              TEXT NOT NULL CHECK (side IN ('BUY','SELL')),
      asset             TEXT NOT NULL,
      qty               NUMERIC(28,10) NOT NULL,
      price             NUMERIC(18,2) NOT NULL,
      quote_usd         NUMERIC(18,2) NOT NULL,
      mode              TEXT NOT NULL,
      exchange_order_id TEXT,
      status            TEXT NOT NULL DEFAULT 'Filled',
      created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS mobile_money_movements (
      id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id        UUID NOT NULL REFERENCES users(id),
      type           TEXT NOT NULL CHECK (type IN ('DEPOSIT','WITHDRAWAL')),
      rail           TEXT NOT NULL,
      phone          TEXT,
      amount_kes     NUMERIC(18,2) NOT NULL CHECK (amount_kes > 0),
      reference      TEXT,
      status         TEXT NOT NULL DEFAULT 'PENDING_ADMIN',
      admin_note     TEXT,
      approved_by    UUID REFERENCES users(id),
      created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_mobile_money_user ON mobile_money_movements(user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_mobile_money_status ON mobile_money_movements(status, created_at DESC);

    CREATE TABLE IF NOT EXISTS payment_topups (
      id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id          UUID NOT NULL REFERENCES users(id),
      gateway          TEXT NOT NULL CHECK (gateway IN ('STRIPE','PAYSTACK','WAAFI')),
      currency         TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount           NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      provider_ref     TEXT,
      provider_status  TEXT,
      phone            TEXT,
      metadata         JSONB NOT NULL DEFAULT '{}'::jsonb,
      status           TEXT NOT NULL DEFAULT 'PENDING',
      credited_at      TIMESTAMPTZ,
      created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_payment_topups_user ON payment_topups(user_id, created_at DESC);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_topups_provider_ref
      ON payment_topups(gateway, provider_ref)
      WHERE provider_ref IS NOT NULL;

    CREATE TABLE IF NOT EXISTS virtual_accounts (
      id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id        UUID NOT NULL REFERENCES users(id),
      account_name   TEXT NOT NULL,
      account_number TEXT NOT NULL UNIQUE,
      currency       TEXT NOT NULL DEFAULT 'USD',
      status         TEXT NOT NULL DEFAULT 'ACTIVE',
      created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_virtual_accounts_user ON virtual_accounts(user_id);

    CREATE TABLE IF NOT EXISTS p2p_transfers (
      id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      sender_user_id    UUID NOT NULL REFERENCES users(id),
      recipient_user_id UUID NOT NULL REFERENCES users(id),
      currency          TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount            NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      memo              TEXT,
      status            TEXT NOT NULL DEFAULT 'COMPLETED',
      created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_p2p_sender ON p2p_transfers(sender_user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_p2p_recipient ON p2p_transfers(recipient_user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS merchants (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id    UUID NOT NULL REFERENCES users(id),
      name        TEXT NOT NULL,
      till_number TEXT NOT NULL UNIQUE,
      status      TEXT NOT NULL DEFAULT 'ACTIVE',
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_merchants_owner ON merchants(owner_id);

    CREATE TABLE IF NOT EXISTS payment_links (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      merchant_id UUID NOT NULL REFERENCES merchants(id),
      currency    TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount      NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      description TEXT,
      status      TEXT NOT NULL DEFAULT 'OPEN',
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_payment_links_merchant ON payment_links(merchant_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS merchant_payments (
      id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      merchant_id  UUID NOT NULL REFERENCES merchants(id),
      payer_id     UUID NOT NULL REFERENCES users(id),
      payment_link_id UUID REFERENCES payment_links(id),
      currency     TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount       NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      status       TEXT NOT NULL DEFAULT 'COMPLETED',
      created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_merchant_payments_merchant ON merchant_payments(merchant_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_merchant_payments_payer ON merchant_payments(payer_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS remittances (
      id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      sender_user_id       UUID NOT NULL REFERENCES users(id),
      recipient_user_id    UUID REFERENCES users(id),
      recipient_phone      TEXT NOT NULL,
      source_currency      TEXT NOT NULL DEFAULT 'USD',
      destination_currency TEXT NOT NULL CHECK (destination_currency IN ('KES','USD')),
      source_amount        NUMERIC(18,2) NOT NULL CHECK (source_amount > 0),
      destination_amount   NUMERIC(18,2) NOT NULL CHECK (destination_amount > 0),
      rate                 NUMERIC(18,6) NOT NULL,
      status               TEXT NOT NULL DEFAULT 'COMPLETED',
      created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_remittances_sender ON remittances(sender_user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_remittances_recipient ON remittances(recipient_user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS email_otps (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id     UUID REFERENCES users(id),
      email       TEXT NOT NULL,
      code_hash   TEXT NOT NULL,
      purpose     TEXT NOT NULL DEFAULT 'email_verify',
      attempts    INT NOT NULL DEFAULT 0,
      consumed_at TIMESTAMPTZ,
      expires_at  TIMESTAMPTZ NOT NULL,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_email_otps_email ON email_otps(LOWER(email), purpose, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_email_otps_user ON email_otps(user_id, created_at DESC);
  `);
  console.log('[db] schema ready');
}

module.exports = { pool, migrate };
