import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'account_detail_screen.dart';
import 'cash_in_screen.dart';
import 'ledger_screen.dart';
import 'receive_screen.dart';
import 'send_money_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _modeIndex = 0;
  int _networkModeIndex = 1; // 0 = Exchange, 1 = WEB3

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _titleRow(context),
            _waveHeader(context, appState),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BybitSearchBar(),
                    _onChainCustodyCard(),
                    _walletModeTabs(),
                    if (_modeIndex == 0) ...[
                      _accountTabs(context, appState.accounts),
                      _sectionTitle('Coins'),
                      _assetsList(),
                    ] else
                      _modePlaceholder(_modeIndex == 1 ? 'Funding' : 'Earn'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Wallet',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          Row(
            children: [
              _appBarAction(
                Icons.history_rounded,
                () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
              ),
              const SizedBox(width: 10),
              _appBarAction(
                Icons.qr_code_scanner_rounded,
                () => Navigator.of(context).push(kashRoute(const SendMoneyScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waveHeader(BuildContext context, KashAppState appState) {
    return ClipPath(
      clipper: const BybitWaveClipper(),
      child: Container(
        width: double.infinity,
        color: BybitPalette.accent,
        padding: const EdgeInsets.fromLTRB(24, 180, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: _networkModeSegment()),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Total assets',
                  style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.visibility_off_outlined, color: Colors.black54, size: 18),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(100)),
                  child: const Text(
                    'Web3',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    appState.totalBalance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text(
                    'USD',
                    style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '+0.00 today',
              style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _heroAction(context, Icons.north_east_rounded, 'Send', const SendMoneyScreen()),
                _heroAction(context, Icons.south_rounded, 'Receive', const ReceiveScreen()),
                _heroAction(context, Icons.phone_iphone_rounded, 'Cash-in', const CashInScreen()),
                _heroAction(context, Icons.receipt_long_rounded, 'Ledger', const LedgerScreen()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkModeSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _networkModeOption('Exchange', 0),
          _networkModeOption('WEB3', 1),
        ],
      ),
    );
  }

  Widget _networkModeOption(String label, int index) {
    final selected = _networkModeIndex == index;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _networkModeIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
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
          color: BybitPalette.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: BybitPalette.accent, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Live on-chain custody card — appears when the RoyallPay backend is
  /// running and the user has a real API session. Renders nothing in
  /// pure-sandbox mode, so the demo never breaks.
  Widget _onChainCustodyCard() {
    if (!ApiService.hasSession) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.walletSummary(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final address = data['depositAddress'] as String? ?? '';
        final eth = data['eth'] as Map<String, dynamic>? ?? {};
        final network = data['network'] as String? ?? 'Sepolia testnet';
        final balance = (eth['balance'] as String?) ?? '0';
        final usd = (eth['usd'] as num?)?.toDouble() ?? 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: BybitCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _BybitMiniIcon(Icons.link_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'On-chain custody',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            network,
                            style: const TextStyle(
                              color: BybitPalette.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${double.parse(balance).toStringAsFixed(5)} ETH',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${usd.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: BybitPalette.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TouchScale(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deposit address copied'),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BybitPalette.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded,
                            color: BybitPalette.accent, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _walletModeTabs() {
    const labels = ['Assets', 'Funding', 'Earn'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: _ModeTab(
                labels[i],
                _modeIndex == i,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _modeIndex = i);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _modePlaceholder(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: BybitCard(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: BybitPalette.surface2,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: BybitPalette.accent,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$label is coming soon',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is part of the RoyallPay Phase 2 roadmap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTabs(BuildContext context, List<KashAccount> accounts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children:
            accounts.map((account) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TouchScale(
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(AccountDetailScreen(account: account))),
                  child: BybitCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        _BybitMiniIcon(account.icon, color: account.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                account.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BybitPalette.muted,
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
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              account.currency,
                              style: const TextStyle(
                                color: BybitPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _assetsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: bybitTokens.take(6).map(_assetItem).toList(),
      ),
    );
  }

  Widget _assetItem(BybitTokenData token) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: BybitTokenRow(
        token: token,
        amount: token.symbol == 'ETH' ? '0.045' : '0.00',
        value: token.symbol == 'ETH' ? '139.05 USD' : '0 USD',
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab(this.label, this.selected, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BybitPalette.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BybitPalette.muted,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _BybitMiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _BybitMiniIcon(this.icon, {this.color = BybitPalette.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}
