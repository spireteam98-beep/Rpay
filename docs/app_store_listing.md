# Wayaki — App Store Connect Listing

Copy-paste source for the App Store Connect "App Information" and "Version" pages. Fields marked **[CONFIRM]** need a decision from you before submission — see the note at the bottom.

## App Information

| Field | Value |
|---|---|
| App name | Wayaki |
| Subtitle (30 chars) | Crypto, Wallet & Bank in One |
| Bundle ID | `com.wayaki.app` (fixed — was a `com.cryptoexchange.*` template leftover) |
| Primary category | Finance |
| Secondary category | Business |
| Copyright | © 2026 Wayaki. All rights reserved. **[CONFIRM legal entity name]** |
| Support URL | https://wayaki.com/support |
| Marketing URL | https://wayaki.com |
| Privacy Policy URL | https://wayaki.com/privacy |

## Promotional text (170 chars, editable without a new build)

```
Send money, hold crypto, and bank — all from one Wayaki account. Fast mobile-money cash in/out, live crypto prices, and a virtual bank account built for East Africa and the diaspora.
```

## Description (4000 char max)

```
Wayaki is the one app where your money arrives, lives and moves.

Every Wayaki account gives you three balances in a single login:

CRYPTO WALLET
Buy, sell and hold BTC, ETH, USDT and more with live market pricing. Track your portfolio, watch real-time charts, and move between crypto and cash whenever you need to.

MOBILE MONEY WALLET
Cash in and out through the mobile-money providers you already use — EVC Plus, Zaad, Sahal, M-Pesa and more. Send money to friends and family instantly, whether they're on Wayaki or on a mobile-money rail.

VIRTUAL BANK ACCOUNT
Get a named account with its own account number for receiving and holding funds — a foundation for full bank-grade features as Wayaki's banking license roadmap rolls out.

BUILT FOR HOW YOU ACTUALLY MOVE MONEY
- Send to another Wayaki user or straight to a mobile-money number
- Pay bills and merchants directly from your wallet
- Cash in via mobile money or card
- Track every transaction in one place, with clear statuses and receipts
- Tiered identity verification (KYC) unlocks higher limits as you verify more

SECURITY YOU CAN CHECK
- Identity verification and transaction monitoring designed around financial-industry AML practices
- Account security controls in Settings, including session and device management
- Your funds and data are never sold to third parties

Whether you're a diaspora sender getting money home fast, a merchant getting paid, or someone who wants crypto, mobile money and banking in one place — Wayaki brings it together.

Questions or need help? Reach us any time at support@wayaki.com.
```

## Keywords (100 chars, comma-separated, no spaces needed)

```
crypto,wallet,mobile money,remittance,send money,bank,fintech,bitcoin,ethereum,p2p,Africa,diaspora
```

## What's New in This Version (release notes — update per submission)

```
- Rebranded to Wayaki with a refreshed look
- Reworked Send Money flow with mobile-money provider picker (EVC Plus, Zaad, Sahal, M-Pesa, Waafi, MTN)
- Bug fixes and performance improvements
```

## App Privacy questionnaire (App Store Connect → App Privacy)

Recommended answers based on what the app actually collects (see `web/privacy.html`). Confirm against your final backend behavior before submitting — Apple checks this against real app behavior.

| Data type | Collected? | Linked to identity? | Used for tracking? |
|---|---|---|---|
| Name, email, phone number | Yes | Yes | No |
| Government ID / KYC documents | Yes | Yes | No |
| Financial info (balances, transaction history) | Yes | Yes | No |
| Crypto wallet address / on-chain activity | Yes | Yes | No |
| Precise/coarse location | No (not currently collected) | — | — |
| Device ID / crash data | Yes | Yes | No |
| Customer support content | Yes | Yes | No |

Apple will also ask about **Account Deletion** (Guideline 5.1.1(v)) — answer "Yes, users can delete their account" (Settings → Delete account, see below).

## Account Deletion (Guideline 5.1.1(v))

Implemented: Settings → Delete account, with a confirmation dialog, calls `POST /auth/delete-account`, and signs the user out. The backend sets a `deletion_requested_at` timestamp and blocks that account from signing in again immediately; financial/KYC records are retained for the compliance period described in the Privacy Policy rather than hard-deleted on the spot (this matches how most regulated fintech apps satisfy the guideline — Apple's requirement is that the request be initiated in-app, not that data vanish instantly).

---

## Before you submit — remaining flags

1. **wayaki.com isn't live yet from what I can tell.** The Privacy Policy and Support URLs above only work once `wayaki.com` is registered, DNS-pointed at your Vercel project, and the site is deployed — App Store review will click these links. The app's welcome screen now links to `/privacy.html` and `/support.html` directly (verified working), so they're also reachable without signing in once the domain is live.
2. **Support inbox** — `support@wayaki.com` needs to actually exist and be monitored; App Store reviewers do test it.
3. **Illustrative sample data** — the Wallet screen's "Recent Activities" falls back to Starbucks/Netflix/Spotify/Amazon-branded sample transactions when a user has no real history yet. Real transactions always take priority, but using third-party brand logos/names in sample data is worth a legal look before shipping — it's a trademark question, not something I changed.
