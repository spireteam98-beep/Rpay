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
import 'profile_screen.dart';
import 'receive_screen.dart';
import 'send_money_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBalanceCard(context, appState),
              const SizedBox(height: 20),
              _onChainCustodyCard(),
              _peopleRow(context, appState),
              _accountTabs(context, appState.accounts),
              _recentActivityCard(context, appState),
            ],
          ),
        ),
      ),
    );
  }

  /// Top balance card: consolidates identity, balance, and quick actions
  /// into a single lime card at the top of the wallet, per the reference
  /// design — replaces the old separate title row + wave header + dark
  /// balance card.
  Widget _topBalanceCard(BuildContext context, KashAppState appState) {
    final initial =
        appState.firstName.isEmpty
            ? 'A'
            : appState.firstName.substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FF3D), BybitPalette.accent],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TouchScale(
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const ProfileScreen())),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: BybitPalette.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _darkIconButton(
                    Icons.qr_code_scanner_rounded,
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const SendMoneyScreen())),
                  ),
                  const SizedBox(width: 10),
                  _darkIconButton(
                    Icons.notifications_none_rounded,
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No new notifications yet')),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Text(
                'Total balance',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.visibility_outlined, color: Colors.black87, size: 17),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  appState.totalBalance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '(USD)',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black87,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickActionCircle(
                context,
                Icons.arrow_upward_rounded,
                'Send',
                const SendMoneyScreen(),
              ),
              _quickActionCircle(
                context,
                Icons.arrow_downward_rounded,
                'Receive',
                const ReceiveScreen(),
              ),
              _quickActionCircle(
                context,
                Icons.history_rounded,
                'History',
                const LedgerScreen(),
              ),
              _quickActionCircle(
                context,
                Icons.add_rounded,
                'Cash-in',
                const CashInScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkIconButton(IconData icon, VoidCallback onTap) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: BybitPalette.accent, size: 18),
      ),
    );
  }

  Widget _quickActionCircle(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen,
  ) {
    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(screen)),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BybitPalette.accent, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: BybitPalette.accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<_PersonSample> _illustrativePeople = [
    _PersonSample('Anfac', avatarAsset: 'assets/images/Anfac.png'),
    _PersonSample('Theresa'),
    _PersonSample('Gladys'),
    _PersonSample('Jane'),
  ];

  /// Quick-send shortcuts built from real recipients of past transfers
  /// (ledger transactions with status 'Queued' carry the recipient as the
  /// title). Falls back to illustrative sample contacts until the user has
  /// actually sent money once — same convention as _recentActivityCard.
  Widget _peopleRow(BuildContext context, KashAppState appState) {
    final people = <_PersonSample>[];
    for (final t in appState.ledgerTransactions) {
      final name = t.title.trim();
      if (t.status == 'Queued' &&
          name.isNotEmpty &&
          !people.any((p) => p.name == name)) {
        people.add(_PersonSample(name));
      }
      if (people.length >= 5) break;
    }
    if (people.isEmpty) people.addAll(_illustrativePeople);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('People'),
        const SizedBox(height: 14),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final person in people) _personAvatar(context, person),
              _morePersonAvatar(context),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _personAvatar(BuildContext context, _PersonSample person) {
    final initial =
        person.name.isEmpty ? '?' : person.name.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: TouchScale(
        onTap:
            () =>
                Navigator.of(context).push(kashRoute(const SendMoneyScreen())),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child:
                    person.avatarAsset != null
                        ? Image.asset(
                          person.avatarAsset!,
                          fit: BoxFit.cover,
                          width: 66,
                          height: 66,
                        )
                        : Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
              ),
              const SizedBox(height: 8),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _morePersonAvatar(BuildContext context) {
    return TouchScale(
      onTap:
          () => Navigator.of(context).push(kashRoute(const SendMoneyScreen())),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BybitPalette.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'More',
              style: TextStyle(
                color: BybitPalette.muted2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent activity: real ledger transactions once the user has actually
  /// sent, received, or topped up. Until then we show illustrative everyday
  /// spend examples (card purchases, subscriptions) so the section reads
  /// like a live feed instead of a blank state — same convention the
  /// Trending Data screen already uses for its illustrative candles.
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
                'Recent Transaction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TouchScale(
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const LedgerScreen())),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: BybitPalette.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            ..._illustrativeActivity.map(_merchantRow)
          else
            ...recent.map((t) => _activityRow(context, t)),
        ],
      ),
    );
  }

  static final List<_MerchantActivity> _illustrativeActivity = [
    _MerchantActivity(
      'Starbucks',
      'Coffee & snacks',
      1.00,
      Icons.local_cafe_rounded,
      const Duration(hours: 2),
      logoAsset: 'assets/images/starbuxks.jpg',
    ),
    _MerchantActivity(
      'Netflix',
      'Monthly subscription',
      10.00,
      Icons.play_circle_fill_rounded,
      const Duration(hours: 9),
      logoAsset: 'assets/images/netflix.jpg',
    ),
    _MerchantActivity(
      'Spotify',
      'Premium subscription',
      9.99,
      Icons.music_note_rounded,
      const Duration(days: 1),
    ),
    _MerchantActivity(
      'Amazon',
      'Online purchase',
      24.50,
      Icons.shopping_bag_rounded,
      const Duration(days: 2),
    ),
  ];

  Widget _merchantRow(_MerchantActivity activity) {
    final subtitle = DateFormat(
      'MMM d, HH:mm',
    ).format(DateTime.now().subtract(activity.agoOffset));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child:
                activity.logoAsset != null
                    ? Image.asset(
                      activity.logoAsset!,
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                    )
                    : Icon(activity.icon, color: BybitPalette.muted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${activity.subtitle} · $subtitle',
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
                '-\$${activity.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: BybitPalette.red,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '\$${activity.amount.toStringAsFixed(2)} USD',
                style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
              ),
            ],
          ),
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
    final isPerson = !isTopUp;
    final initial = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();

    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BybitPalette.surface2,
                shape: BoxShape.circle,
              ),
              child:
                  isPerson
                      ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                      : const Icon(
                        Icons.add_rounded,
                        color: BybitPalette.muted,
                        size: 22,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
                  entry.amountLabel,
                  style: TextStyle(
                    color: isCredit ? BybitPalette.green : BybitPalette.red,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '\$${entry.amountUsd.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
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
                      const SnackBar(content: Text('Deposit address copied')),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                        const Icon(
                          Icons.copy_rounded,
                          color: BybitPalette.accent,
                          size: 16,
                        ),
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
                        child: Icon(
                          account.icon,
                          color: account.accent,
                          size: 16,
                        ),
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

class _PersonSample {
  final String name;
  final String? avatarAsset;

  const _PersonSample(this.name, {this.avatarAsset});
}

class _MerchantActivity {
  final String name;
  final String subtitle;
  final double amount;
  final IconData icon;
  final Duration agoOffset;
  final String? logoAsset;

  const _MerchantActivity(
    this.name,
    this.subtitle,
    this.amount,
    this.icon,
    this.agoOffset, {
    this.logoAsset,
  });
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
