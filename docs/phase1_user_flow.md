# Kashflip Phase 1 User Flow

```mermaid
flowchart TD
  A[Welcome] --> B[Sign up]
  A --> C[Sign in]
  B --> D[Phone OTP]
  D --> E[Tiered KYC]
  E --> F[Accounts created]
  C --> F
  F --> G[All-accounts dashboard]
  G --> H[Crypto custody wallet]
  G --> I[Mobile money wallet]
  G --> J[Virtual bank account]
  G --> K[Unified send flow]
  H --> K
  I --> K
  J --> K
  K --> L{Destination rail}
  L --> M[Kashflip user]
  L --> N[Mobile money: EVC Plus, Zaad, Sahal, M-Pesa]
  L --> O[Crypto address]
  L --> P[Bank account or future IBAN]
```

## Phase 1 App Screens

- Welcome
- Sign up
- Sign in
- OTP verification
- Tiered KYC
- Dashboard with crypto custody, mobile money and virtual bank balances
- Account detail for each money identity
- Unified send flow across internal wallet, mobile money, crypto and bank rails
- Profile and compliance status
