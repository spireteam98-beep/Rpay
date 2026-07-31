import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../models/ledger_entry.dart';
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
        // A one-off sync failure at app launch (weak connection, etc.)
        // otherwise leaves balances/activity stuck stale for the rest of
        // the session — syncFromBackend only runs once, in
        // MainNavigation.initState, with no other way to retry it.
        child: RefreshIndicator(
          color: BybitPalette.accent,
          backgroundColor: BybitPalette.surface,
          onRefresh: () => appState.syncFromBackend(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBalanceCard(context, appState),
                const SizedBox(height: 20),
                _peopleRow(context, appState),
                _accountsHeader(context, appState),
                const SizedBox(height: 14),
                _accountTabs(context, appState.visibleAccounts),
                _recentActivityCard(context, appState),
              ],
            ),
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

  /// Quick-send shortcuts built from the user's real saved frequent
  /// recipients (backend-tracked — see ApiService.frequentRecipients),
  /// refreshed every time a P2P transfer completes. No illustrative sample
  /// contacts: a new user with no transfer history simply sees the "Add"
  /// shortcut on its own.
  Widget _peopleRow(BuildContext context, KashAppState appState) {
    final people = appState.frequentRecipients;
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

  Widget _personAvatar(BuildContext context, Map<String, dynamic> person) {
    final label = person['label'] as String? ?? '?';
    final identifier = person['identifier'] as String? ?? '';
    final initial = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: TouchScale(
        onTap:
            () => Navigator.of(context).push(
              kashRoute(SendMoneyScreen(initialRecipient: identifier)),
            ),
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
                child: Text(
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
                label,
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
  /// sent, received, or topped up. Until then a plain empty state is shown
  /// rather than illustrative sample purchases, so new users never mistake
  /// placeholder data for their own transaction history.
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
            _emptyActivityState()
          else
            ...recent.map((t) => _activityRow(context, t)),
        ],
      ),
    );
  }

  Widget _emptyActivityState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: BybitPalette.muted,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Send, receive or top up to see activity here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
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

  /// "Accounts" section title with a Convert action — the only way to move
  /// value between Wayaki USD and Wayaki KES, since they're now two
  /// separate currency accounts rather than one blended wallet.
  Widget _accountsHeader(BuildContext context, KashAppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          TouchScale(
            onTap: () => _openConvertSheet(context, appState),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync_alt_rounded,
                  color: BybitPalette.accent,
                  size: 16,
                ),
                SizedBox(width: 5),
                Text(
                  'Convert',
                  style: TextStyle(
                    color: BybitPalette.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openConvertSheet(BuildContext context, KashAppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ConvertSheet(),
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


/// Bottom sheet that moves value between the user's own Wayaki USD and
/// Wayaki KES accounts — the one deliberate bridge between the two
/// currencies (everything else stays strictly separated).
class _ConvertSheet extends StatefulWidget {
  const _ConvertSheet();

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _kesToUsd = true;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final from = _kesToUsd ? 'KES' : 'USD';
    final to = _kesToUsd ? 'USD' : 'KES';
    final fromAccount = appState.accountByType(
      _kesToUsd ? KashAccountType.walletKes : KashAccountType.walletUsd,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BybitPalette.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Convert currency',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${fromAccount.balance}',
              style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _CurrencyPill(label: from)),
                TouchScale(
                  onTap:
                      _submitting
                          ? null
                          : () => setState(() => _kesToUsd = !_kesToUsd),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BybitPalette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(child: _CurrencyPill(label: to)),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: BybitPalette.surface2,
                hintText: 'Amount in $from',
                hintStyle: const TextStyle(color: BybitPalette.muted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            BybitPrimaryButton(
              label: _submitting ? 'Converting…' : 'Convert',
              enabled: !_submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0.')));
      return;
    }
    setState(() => _submitting = true);
    final result = await context.read<KashAppState>().convertCurrency(
      from: _kesToUsd ? 'KES' : 'USD',
      to: _kesToUsd ? 'USD' : 'KES',
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop();
  }
}

class _CurrencyPill extends StatelessWidget {
  final String label;

  const _CurrencyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
