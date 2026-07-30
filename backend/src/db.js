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

    -- Trading: USD funding + custody asset balances + order history.
    -- New users start at 0 — they fund the wallet for real via Card/M-Pesa/Waafi.
    ALTER TABLE users ADD COLUMN IF NOT EXISTS usd_balance NUMERIC(18,2) NOT NULL DEFAULT 10000;
    ALTER TABLE users ALTER COLUMN usd_balance SET DEFAULT 0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS kes_balance NUMERIC(18,2) NOT NULL DEFAULT 0;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'customer';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

    -- Sign-in is now email + one-time code, not a password — new accounts
    -- never set password_hash, so it can no longer be required.
    ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

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

    -- Business onboarding fields on merchants (till_number already doubles
    -- as the "merchant number" / business account for receiving payments).
    ALTER TABLE merchants ADD COLUMN IF NOT EXISTS business_type TEXT;
    ALTER TABLE merchants ADD COLUMN IF NOT EXISTS phone TEXT;

    -- Agents: onboard customers (personal + business), earn commission on
    -- assisted deposits/withdrawals and referred signups.
    CREATE TABLE IF NOT EXISTS agents (
      id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id            UUID NOT NULL REFERENCES users(id),
      business_name      TEXT NOT NULL,
      agent_code         TEXT NOT NULL UNIQUE,
      phone              TEXT,
      status             TEXT NOT NULL DEFAULT 'ACTIVE',
      commission_balance NUMERIC(18,2) NOT NULL DEFAULT 0,
      created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_agents_user ON agents(user_id);

    CREATE TABLE IF NOT EXISTS agent_commissions (
      id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_id         UUID NOT NULL REFERENCES agents(id),
      kind             TEXT NOT NULL CHECK (kind IN ('deposit','withdrawal','onboarding')),
      currency         TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount           NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      related_user_id  UUID REFERENCES users(id),
      created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_agent_commissions_agent ON agent_commissions(agent_id, created_at DESC);

    -- Which agent onboarded this customer, if any (drives onboarding commission).
    ALTER TABLE users ADD COLUMN IF NOT EXISTS referred_by_agent_id UUID REFERENCES agents(id);

    -- Admin approval workflow: who approved this partner and when.
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
    ALTER TABLE merchants ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);
    ALTER TABLE merchants ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

    -- P2P: customer buys crypto from an agent's float using mobile money —
    -- Binance-P2P style: customer pays the agent directly (outside the app),
    -- uploads proof, agent confirms receipt and releases the crypto.
    CREATE TABLE IF NOT EXISTS p2p_orders (
      id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id       UUID NOT NULL REFERENCES users(id),
      agent_id          UUID NOT NULL REFERENCES agents(id),
      asset             TEXT NOT NULL,
      crypto_amount     NUMERIC(28,8) NOT NULL CHECK (crypto_amount > 0),
      fiat_currency     TEXT NOT NULL CHECK (fiat_currency IN ('KES','USD')),
      fiat_amount       NUMERIC(18,2) NOT NULL CHECK (fiat_amount > 0),
      rate_usd          NUMERIC(28,8) NOT NULL,
      status            TEXT NOT NULL DEFAULT 'PENDING_PAYMENT'
                         CHECK (status IN ('PENDING_PAYMENT','PROOF_SUBMITTED','RELEASED','REJECTED','CANCELLED')),
      payment_proof     TEXT,
      payment_reference TEXT,
      admin_note        TEXT,
      created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_p2p_orders_customer ON p2p_orders(customer_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_p2p_orders_agent ON p2p_orders(agent_id, status, created_at DESC);
  `);

  // agent_commissions.kind — widened over time (p2p, override, then
  // merchant_onboarding/card_issuance below); kept as one canonical
  // definition here since re-narrowing it between migrate() runs would
  // break on whatever kind values already exist in the table.
  await pool.query(`
    ALTER TABLE agent_commissions DROP CONSTRAINT IF EXISTS agent_commissions_kind_check;
    ALTER TABLE agent_commissions
      ADD CONSTRAINT agent_commissions_kind_check
      CHECK (kind IN ('deposit','withdrawal','onboarding','merchant_onboarding','card_issuance','p2p','override'));
  `);

  // Agent tier hierarchy — mirrors Safaricom M-Pesa's Super Agent / Agent /
  // Sub-Agent model: a Super Agent (dealer/country/area lead) contracts and
  // manages a network of Agents, an Agent can recruit Sub-Agents under
  // itself, and every recruited tier's commission is split 80/20 with its
  // immediate parent on the same aggregated-line convention Safaricom uses.
  await pool.query(`
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS tier TEXT NOT NULL DEFAULT 'AGENT';
    -- Kept as one canonical definition further below (widened to add
    -- COUNTRY_AGENT) since re-narrowing it between migrate() runs would
    -- break on whatever tier values already exist in the table.

    ALTER TABLE agents ADD COLUMN IF NOT EXISTS parent_agent_id UUID REFERENCES agents(id);
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS override_rate NUMERIC(5,4) NOT NULL DEFAULT 0.20;
    ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_override_rate_check;
    ALTER TABLE agents ADD CONSTRAINT agents_override_rate_check
      CHECK (override_rate >= 0 AND override_rate < 1);

    CREATE INDEX IF NOT EXISTS idx_agents_parent ON agents(parent_agent_id);
  `);

  // Pay Bills: generic biller/account-number payment, debited from the
  // user's wallet like a merchant till payment but with no merchant record
  // on the other side — settles to a clearing account instead.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bill_payments (
      id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id        UUID NOT NULL REFERENCES users(id),
      biller_name    TEXT NOT NULL,
      account_number TEXT NOT NULL,
      currency       TEXT NOT NULL CHECK (currency IN ('KES','USD')),
      amount         NUMERIC(18,2) NOT NULL CHECK (amount > 0),
      status         TEXT NOT NULL DEFAULT 'COMPLETED',
      created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_bill_payments_user ON bill_payments(user_id, created_at DESC);
  `);

  // Security: transaction PIN, checked for real before a transfer is
  // allowed to go through (see auth.js POST /auth/pin and /auth/pin/verify).
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash TEXT;
  `);

  // Account deletion (App Store Guideline 5.1.1(v)): marks the account for
  // deletion in-app; login is blocked from this timestamp on. Financial/KYC
  // records are retained for the compliance period described in the privacy
  // policy rather than hard-deleted immediately.
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;
  `);

  // Admin moderation: suspend/reactivate a user account outright — distinct
  // from the App-Store-required self-service deletion above. A suspended
  // user is blocked at login and on every authenticated request (see
  // middleware/auth.js requireAuth and routes/auth.js login routes).
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE';
    ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
    ALTER TABLE users ADD CONSTRAINT users_status_check CHECK (status IN ('ACTIVE','SUSPENDED'));
    ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES users(id);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS suspension_reason TEXT;
  `);

  // Transaction revocation: an admin can reverse a completed P2P transfer or
  // merchant payment (dispute, fraud finding, wrong recipient). Reversal
  // moves the money back and posts a compensating ledger transaction — see
  // POST /admin/p2p-transfers/:id/reverse and /admin/merchant-payments/:id/reverse.
  await pool.query(`
    ALTER TABLE p2p_transfers ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ;
    ALTER TABLE p2p_transfers ADD COLUMN IF NOT EXISTS reversed_by UUID REFERENCES users(id);
    ALTER TABLE p2p_transfers ADD COLUMN IF NOT EXISTS reversal_reason TEXT;

    ALTER TABLE merchant_payments ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ;
    ALTER TABLE merchant_payments ADD COLUMN IF NOT EXISTS reversed_by UUID REFERENCES users(id);
    ALTER TABLE merchant_payments ADD COLUMN IF NOT EXISTS reversal_reason TEXT;
  `);

  // Agent revenue-sharing expansion: agents also earn for onboarding
  // merchants (not just customers) and — once the Wayaki Card ships — for
  // card issuance ('merchant_onboarding'/'card_issuance' added to the
  // canonical kind check above). 'merchant_onboarding' mirrors the existing
  // customer 'onboarding' flow (see merchants.js referredByAgent).
  await pool.query(`
    ALTER TABLE merchants ADD COLUMN IF NOT EXISTS referred_by_agent_id UUID REFERENCES agents(id);
  `);

  // Scoped staff: a merchant can have tellers who accept/request payments
  // on the till without ever seeing the owner's personal settlement wallet
  // balance (that balance isn't exposed through any merchant-scoped route
  // to begin with, so no extra restriction is needed there). An agent can
  // have cashiers scoped to deposit/withdraw only — no recruiting, no
  // override-commission visibility, no agent settings. Both are existing
  // Wayaki users added by the owner, same convention as agents.js recruit.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS merchant_staff (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      merchant_id UUID NOT NULL REFERENCES merchants(id),
      user_id     UUID NOT NULL REFERENCES users(id),
      role        TEXT NOT NULL DEFAULT 'TELLER' CHECK (role IN ('TELLER')),
      status      TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED')),
      added_by    UUID REFERENCES users(id),
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (merchant_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_merchant_staff_user ON merchant_staff(user_id, status);
    CREATE INDEX IF NOT EXISTS idx_merchant_staff_merchant ON merchant_staff(merchant_id, status);

    CREATE TABLE IF NOT EXISTS agent_staff (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_id   UUID NOT NULL REFERENCES agents(id),
      user_id    UUID NOT NULL REFERENCES users(id),
      role       TEXT NOT NULL DEFAULT 'CASHIER' CHECK (role IN ('CASHIER')),
      status     TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED')),
      added_by   UUID REFERENCES users(id),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (agent_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_agent_staff_user ON agent_staff(user_id, status);
    CREATE INDEX IF NOT EXISTS idx_agent_staff_agent ON agent_staff(agent_id, status);
  `);

  // Location-scoped agent hierarchy: Country Agent (one per country) ->
  // Super Agent -> Agent -> Sub-Agent. Self-serve "become an agent"
  // applications (see agents.js POST /) are routed to the right sponsor by
  // country/region and sit in PENDING_REVIEW until that sponsor (or admin,
  // if no sponsor exists yet in that location) approves them — replacing
  // the old free-text status with a real state machine.
  await pool.query(`
    ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_tier_check;
    ALTER TABLE agents ADD CONSTRAINT agents_tier_check
      CHECK (tier IN ('COUNTRY_AGENT','SUPER_AGENT','AGENT','SUB_AGENT'));

    ALTER TABLE agents ADD COLUMN IF NOT EXISTS country_code TEXT;
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS region TEXT;
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS city TEXT;

    UPDATE agents SET status = 'PENDING_REVIEW' WHERE status = 'PENDING';
    ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_status_check;
    ALTER TABLE agents ADD CONSTRAINT agents_status_check
      CHECK (status IN ('PENDING_REVIEW','ACTIVE','REJECTED','SUSPENDED'));

    ALTER TABLE agents ADD COLUMN IF NOT EXISTS min_float_usd NUMERIC(18,2);
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS daily_limit_usd NUMERIC(18,2);

    CREATE UNIQUE INDEX IF NOT EXISTS idx_agents_one_country_agent
      ON agents (country_code) WHERE tier = 'COUNTRY_AGENT';
    CREATE INDEX IF NOT EXISTS idx_agents_location ON agents(country_code, region, tier, status);
  `);

  // Telegram Mini App sign-in (see routes/auth.js POST /auth/telegram):
  // identifies returning users without a password. phone stays NOT NULL, so
  // a Telegram-only signup gets a synthetic 'tg:<id>' placeholder there.
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_id TEXT;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_username TEXT;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_photo_url TEXT;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_telegram_id
      ON users (telegram_id)
      WHERE telegram_id IS NOT NULL;
  `);

  // Sole super-admin: keep this the only account with role='admin'. Runs
  // every boot so it's self-healing across environments/DB resets.
  await pool.query(
    `UPDATE users SET role = 'admin' WHERE LOWER(email) = $1 AND role IS DISTINCT FROM 'admin'`,
    [config.adminEmail],
  );
  await pool.query(
    `UPDATE users SET role = 'customer' WHERE LOWER(email) IS DISTINCT FROM $1 AND role = 'admin'`,
    [config.adminEmail],
  );

  console.log('[db] schema ready');
}

module.exports = { pool, migrate };
