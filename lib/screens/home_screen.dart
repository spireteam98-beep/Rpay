import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'account_detail_screen.dart';
import 'buy_screen.dart';
import 'cash_in_screen.dart';
import 'ledger_screen.dart';
import 'profile_screen.dart';
import 'send_money_screen.dart';
import 'swap_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, appState),
              _totalBalanceCard(appState),
              _quickActions(context),
              _sectionHeader('Your money identities', 'Phase 1'),
              const SizedBox(height: 12),
              _accountCarousel(context, appState.accounts),
              const SizedBox(height: 24),
              _phaseOneStrip(),
              const SizedBox(height: 24),
              _sectionHeader('Recent movement', 'Ledger'),
              const SizedBox(height: 12),
              _recentActivity(appState.recentTransactions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, KashAppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appState.firstName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _appBarAction(Icons.notifications_none_rounded, () {}),
              const SizedBox(width: 8),
              _appBarAction(
                Icons.person_outline_rounded,
                () => Navigator.of(
                  context,
                ).push(kashRoute(const ProfileScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: BybitPalette.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _totalBalanceCard(KashAppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Unified balance',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: BybitPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'KYC ${appState.kycTier}',
                  style: const TextStyle(
                    color: BybitPalette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            appState.totalBalance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Crypto custody + mobile money + virtual bank account',
            style: TextStyle(
              color: BybitPalette.muted2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _actionButton(
            context,
            Icons.north_east_rounded,
            'Send',
            const SendMoneyScreen(),
          ),
          _actionButton(context, Icons.add_rounded, 'Add', const CashInScreen()),
          _actionButton(
            context,
            Icons.currency_bitcoin_rounded,
            'Buy',
            const BuyScreen(),
          ),
          _actionButton(
            context,
            Icons.sync_alt_rounded,
            'Swap',
            const SwapScreen(),
          ),
          _actionButton(
            context,
            Icons.receipt_long_rounded,
            'Ledger',
            const LedgerScreen(),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen,
  ) {
    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(screen)),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted2,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: BybitPalette.surface2,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BybitPalette.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCarousel(BuildContext context, List<KashAccount> accounts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < accounts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _accountCard(context, accounts[i]),
          ],
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, KashAccount account) {
    return TouchScale(
      onTap:
          () => Navigator.of(
            context,
          ).push(kashRoute(AccountDetailScreen(account: account))),
      child: BybitCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: account.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(account.icon, color: account.accent, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    account.balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: account.accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      account.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: account.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: BybitPalette.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseOneStrip() {
    final items = [
      _PhaseItem(Icons.person_add_alt_rounded, 'Signup'),
      _PhaseItem(Icons.sms_outlined, 'OTP'),
      _PhaseItem(Icons.badge_outlined, 'KYC'),
      _PhaseItem(Icons.account_balance_wallet_outlined, 'Ledger'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BybitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 1 foundation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  items.map((item) {
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: BybitPalette.surface2,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.icon,
                              color: BybitPalette.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: BybitPalette.muted2,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentActivity(List<KashTransaction> transactions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children:
            transactions.map((transaction) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BybitCard(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: BybitPalette.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          transaction.icon,
                          color: BybitPalette.accent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              transaction.subtitle,
                              style: const TextStyle(
                                color: BybitPalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        transaction.amount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _PhaseItem {
  final IconData icon;
  final String label;

  const _PhaseItem(this.icon, this.label);
}
