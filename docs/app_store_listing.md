# Wayaki — App Store Connect Listing

Copy-paste source for the App Store Connect "App Information" and "Version" pages. Fields marked **[CONFIRM]** need a decision from you before submission — see the note at the bottom.

## App Information

| Field | Value |
|---|---|
| App name | Wayaki |
| Subtitle (30 chars) | Crypto, Wallet & Bank in One |
| Bundle ID | **[CONFIRM]** — currently `com.cryptoexchange.cryptoExchangeApp`, a leftover from the app's original template name. Should be changed to something like `com.wayaki.app` before you create the App Store Connect record — see note below. |
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

Apple will also ask about **Account Deletion** (Guideline 5.1.1(v)) — see the flag below.

---

## Before you submit — flags from reviewing the codebase

1. **Bundle identifier is still a template placeholder** (`com.cryptoexchange.cryptoExchangeApp` in `ios/Runner.xcodeproj` and `com.cryptoexchange.crypto_exchange_app` in `android/app/build.gradle.kts`). This needs to become the real production identifier (e.g. `com.wayaki.app`) before you create the App Store Connect app record — changing it later means a new App Store Connect listing, not an update to an existing one.
2. **No in-app account deletion.** Apple requires (Guideline 5.1.1(v)) that any app supporting account creation also let users delete their account from within the app, not just by emailing support. Right now `web/support.html` documents an email-based deletion process, which is a stopgap, not a substitute — this is likely to trigger a rejection.
3. **wayaki.com isn't live yet from what I can tell.** The Privacy Policy and Support URLs above only work once `wayaki.com` is registered, DNS-pointed at your Vercel project, and the site is deployed — App Store review will click these links.
4. **Support inbox** — `support@wayaki.com` needs to actually exist and be monitored; App Store reviewers do test it.
