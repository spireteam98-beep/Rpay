import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/cryptocurrency.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'account_detail_screen.dart';
import 'cash_in_screen.dart';
import 'ledger_screen.dart';
import 'send_money_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Wallets', style: Theme.of(context).textTheme.displaySmall),
        actions: [
          _appBarAction(Icons.history_rounded, () {}),
          const SizedBox(width: 8),
          _appBarAction(
            Icons.qr_code_scanner_rounded,
            () =>
                Navigator.of(context).push(kashRoute(const SendMoneyScreen())),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _balanceCard(context, appState),
            _accountTabs(context, appState.accounts),
            _sectionTitle('Custodied crypto assets'),
            _assetsList(),
          ],
        ),
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.cardDarkBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.glassStroke),
        ),
        child: Icon(icon, color: AppTheme.textWhite, size: 19),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, KashAppState appState) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: AppTheme.heroCard,
      child: Column(
        children: [
          const Text(
            'All wallet balances',
            style: TextStyle(
              color: AppTheme.onLime,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            appState.totalBalance,
            style: const TextStyle(
              color: AppTheme.onLime,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.6,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _heroAction(
                context,
                Icons.north_east_rounded,
                'Send',
                const SendMoneyScreen(),
              ),
              _heroAction(
                context,
                Icons.south_rounded,
                'Receive',
                const LedgerScreen(),
              ),
              _heroAction(
                context,
                Icons.phone_iphone_rounded,
                'Cash-in',
                const CashInScreen(),
              ),
              _heroAction(
                context,
                Icons.receipt_long_rounded,
                'Ledger',
                const LedgerScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroAction(
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
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.onLime,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.onLime,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTabs(BuildContext context, List<KashAccount> accounts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children:
            accounts.map((account) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassTile(
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(AccountDetailScreen(account: account))),
                  child: Row(
                    children: [
                      CircleIcon(account.icon, color: account.accent, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.title,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              account.subtitle,
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            account.balance,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            account.currency,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppTheme.textWhite,
        ),
      ),
    );
  }

  Widget _assetsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: Cryptocurrency.mockData.take(3).map(_assetItem).toList(),
      ),
    );
  }

  Widget _assetItem(Cryptocurrency crypto) {
    final ownedAmount =
        crypto.currentPrice > 1000
            ? 0.01 * (crypto.currentPrice / 1000)
            : 1.5 * (1000 / crypto.currentPrice);
    final valueUsd = ownedAmount * crypto.currentPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassTile(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cardLightBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.glassStroke),
              ),
              child: Center(
                child: Text(
                  crypto.symbol.substring(0, 1),
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crypto.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${crypto.symbol.toUpperCase()} custody',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${valueUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ownedAmount.toStringAsFixed(ownedAmount < 1 ? 4 : 2)} ${crypto.symbol.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
