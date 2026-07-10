import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../models/ledger_entry.dart';
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
            _waveHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BybitSearchBar(),
                    _balanceCard(context, appState),
                    _onChainCustodyCard(),
                    _walletModeTabs(),
                    if (_modeIndex == 0) ...[
                      _peopleRow(context, appState),
                      _accountTabs(context, appState.accounts),
                      _recentActivityCard(context, appState),
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

  Widget _waveHeader() {
    return SizedBox(
      height: 108,
      width: double.infinity,
      child: ClipPath(
        clipper: const BybitWaveClipper(),
        child: Container(
          color: BybitPalette.accent,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 40),
          child: _networkModeSegment(),
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

  Widget _balanceCard(BuildContext context, KashAppState appState) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Total assets',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.visibility_off_outlined,
                  color: BybitPalette.muted, size: 18),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Web3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  'USD',
                  style: TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '+0.00 today',
            style: TextStyle(
              color: BybitPalette.green,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
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
                const ReceiveScreen(),
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
          decoration: BoxDecoration(
            color: BybitPalette.surface2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
      ),
    );
  }

  /// Quick-send shortcuts built from real recipients of past transfers
  /// (ledger transactions with status 'Queued' carry the recipient as the
  /// title). Renders nothing until the user has actually sent money once.
  /// Cards deliberately duplicate the _accountTabs card layout below so the
  /// two horizontal scrollers feel like the same family of component.
  Widget _peopleRow(BuildContext context, KashAppState appState) {
    final people = <MapEntry<String, String>>[];
    for (final t in appState.ledgerTransactions) {
      final name = t.title.trim();
      if (t.status == 'Queued' && name.isNotEmpty && !people.any((p) => p.key == name)) {
        people.add(MapEntry(name, t.entries.first.amountLabel));
      }
      if (people.length >= 6) break;
    }
    if (people.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('People'),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _personCard(context, people[i].key, people[i].value),
          ),
        ),
      ],
    );
  }

  Widget _personCard(BuildContext context, String name, String lastSentLabel) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(const SendMoneyScreen())),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF242832)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BybitPalette.accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(color: BybitPalette.accent, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.north_east_rounded, color: BybitPalette.muted, size: 14),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BybitPalette.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Sent $lastSentLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent activity pulled straight from the real ledger — no illustrative
  /// data here, since cash-in and send flows already write real entries.
  Widget _recentActivityCard(BuildContext context, KashAppState appState) {
    final recent = appState.ledgerTransactions.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
              ),
              TouchScale(
                onTap: () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
                child: const Text(
                  'See all',
                  style: TextStyle(color: BybitPalette.accent, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Text(
              'Send, receive, or top up to see activity here.',
              style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
            )
          else
            ...recent.map((t) => _activityRow(context, t)),
        ],
      ),
    );
  }

  Widget _activityRow(BuildContext context, LedgerTransaction transaction) {
    final isTopUp = transaction.title.toLowerCase().contains('cash-in');
    final entry = transaction.entries.first;
    final isCredit = entry.direction == LedgerDirection.credit;
    final label = isTopUp ? '${transaction.rail} Top-up' : transaction.title;
    final subtitle = DateFormat('MMM d, HH:mm').format(transaction.postedAt);

    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
              child: Icon(
                isTopUp
                    ? Icons.add_rounded
                    : (isCredit ? Icons.south_west_rounded : Icons.north_east_rounded),
                color: BybitPalette.muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: BybitPalette.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Text(
              entry.amountLabel,
              style: TextStyle(
                color: isCredit ? BybitPalette.green : BybitPalette.red,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final account = accounts[i];
          return TouchScale(
            onTap:
                () => Navigator.of(
                  context,
                ).push(kashRoute(AccountDetailScreen(account: account))),
            child: Container(
              width: 156,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BybitPalette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF242832)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: account.accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(account.icon, color: account.accent, size: 16),
                      ),
                      const Spacer(),
                      Text(
                        account.currency,
                        style: const TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    account.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    account.balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
