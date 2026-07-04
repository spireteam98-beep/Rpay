# RoyalPay API — real backend (Phase 2)

Node.js + cloud PostgreSQL + self-hosted HD-wallet custody (testnet-first).
One signup provisions a real on-chain Ethereum wallet for the user; the app
shows the live balance and can broadcast real (Sepolia testnet) transactions.

## One-time setup (10 minutes)

1. **Create the database** — go to https://neon.tech, sign up free,
   create a project, and copy the connection string
   (`postgresql://...neon.tech/neondb?sslmode=require`).

2. **Configure** — double-click `run_backend.bat` in the project root.
   The first run creates `.env` and opens it in Notepad. Fill in:
   - `DATABASE_URL` — the Neon connection string
   - `JWT_SECRET` — any long random string
   - `MASTER_MNEMONIC` — generate offline:
     `node -e "console.log(require('ethers').Wallet.createRandom().mnemonic.phrase)"`
     (run this inside the `backend` folder after the first `npm install`)

3. **Run** — double-click `run_backend.bat` again. It installs packages and
   starts the API on `http://localhost:8080`. The database schema creates
   itself on first boot.

4. **Use it** — run the app (`setup_and_run.bat`). Signup now registers in
   Postgres and provisions the user's custody wallet; the Wallet tab shows
   the live on-chain card with the deposit address. Get free test ETH from
   a Sepolia faucet (e.g. https://sepolia-faucet.pk910.de) to see deposits
   and try withdrawals.

## Endpoints

| Method | Path                | What it does                                   |
|--------|---------------------|------------------------------------------------|
| POST   | /auth/signup        | Create user + provision custody wallet         |
| POST   | /auth/login         | Password login → JWT                           |
| POST   | /auth/verify-phone  | OTP check (sandbox: any 6 digits)              |
| POST   | /auth/kyc           | Raise to full KYC tier                         |
| GET    | /auth/me            | Profile                                        |
| GET    | /wallet/summary     | Deposit address, on-chain balance, live prices |
| GET    | /wallet/prices      | Live market prices (CoinGecko)                 |
| POST   | /wallet/withdraw    | Sign + broadcast ETH withdrawal (KYC limits)   |
| GET    | /wallet/withdrawals | Withdrawal history                             |
| GET    | /ledger             | Double-entry transaction history               |

## Security model (and what changes for production)

- Customer wallets derive from ONE master seed (BIP44 `m/44'/60'/0'/0/{index}`).
  Today the seed lives in `.env` — fine for testnet, **never for mainnet**.
  Production: move signing to an HSM / cloud KMS (or MPC), keep hot balances
  minimal, add withdrawal allow-lists and quorum approval.
- KYC tiers enforce per-withdrawal USD limits server-side; breaches open
  AML cases in the `aml_cases` table.
- The ledger is double-entry and refuses unbalanced postings.
- Before mainnet: security audit, rate limiting, 2FA, and the licensing
  track from the roadmap (Kenya VASP for custody).
