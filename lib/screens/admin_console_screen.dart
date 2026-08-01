import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'admin_partners_screen.dart';
import 'aml_queue_screen.dart';
import 'ledger_screen.dart';

/// Standalone, pushable "Ops console" screen (still reachable from Profile
/// for anyone who wants a back-button flow); wraps [AdminConsoleBody] in
/// its own Scaffold + AppBar. Admins mainly land on this content via the
/// Hub tab instead — see home_dashboard_screen.dart.
class AdminConsoleScreen extends StatelessWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: AppBar(
        backgroundColor: BybitPalette.bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Ops console',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: const SafeArea(child: AdminConsoleBody()),
    );
  }
}

/// The ops-console content on its own — metrics + admin task tiles — with
/// no Scaffold/AppBar of its own, so it can be embedded either inside
/// [AdminConsoleScreen]'s pushed route or directly in the Hub tab.
class AdminConsoleBody extends StatelessWidget {
  final EdgeInsets padding;
  const AdminConsoleBody({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 28),
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final balancedCount =
        appState.ledgerTransactions
            .where((transaction) => transaction.isBalanced)
            .length;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: padding,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: BybitPalette.accent,
                  size: 24,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Phase 1 controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Identity, AML and ledger health for the pilot.',
                style: TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _PlatformBalanceCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _metric('KYC tier', appState.kycTier)),
            const SizedBox(width: 10),
            Expanded(
              child: _metric(
                'Ledger',
                '$balancedCount/${appState.ledgerTransactions.length} balanced',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Phone',
                appState.phoneVerified ? 'Verified' : 'Pending',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metric(
                'AML cases',
                appState.openAmlCases == 0
                    ? 'None open'
                    : '${appState.openAmlCases} open',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _metric('Limits (${appState.kycTier})', appState.kycLimitSummary),
        const SizedBox(height: 18),
        _opsTile(
          context,
          Icons.account_tree_outlined,
          'Core ledger',
          'Review balanced debit and credit entries',
          () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
        ),
        _opsTile(
          context,
          Icons.manage_search_outlined,
          'Monitoring queue',
          appState.openAmlCases == 0
              ? 'No open sanctions, velocity or limit cases'
              : '${appState.openAmlCases} case(s) awaiting review',
          () => Navigator.of(context).push(kashRoute(const AmlQueueScreen())),
        ),
        _opsTile(
          context,
          Icons.groups_2_outlined,
          'Agents & Merchants',
          'Create, approve, deactivate and commissions',
          () => Navigator.of(
            context,
          ).push(kashRoute(const AdminPartnersScreen())),
        ),
        _opsTile(
          context,
          Icons.assignment_turned_in_outlined,
          'Regulatory pack',
          'MTB and mobile money evidence checklist',
          () {},
        ),
        _opsTile(
          context,
          Icons.restart_alt_rounded,
          'Reset sandbox',
          'Restore opening balances and clear cases',
          () {
            appState.resetSandbox();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sandbox reset to opening state.')),
            );
          },
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _opsTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: onTap,
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
                child: Icon(icon, color: BybitPalette.accent, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BybitPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

/// Total custodial funds Wayaki is holding across every wallet, broken
/// down by customer/agent/merchant — see backend routes/admin.js GET
/// /platform-balance for how each bucket is computed.
class _PlatformBalanceCard extends StatefulWidget {
  const _PlatformBalanceCard();

  @override
  State<_PlatformBalanceCard> createState() => _PlatformBalanceCardState();
}

class _PlatformBalanceCardState extends State<_PlatformBalanceCard> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.adminPlatformBalance();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child:
          _loading
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                ),
              )
              : data == null
              ? Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Couldn't load platform balance.",
                      style: TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  TouchScale(
                    onTap: _load,
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: BybitPalette.accent,
                      size: 20,
                    ),
                  ),
                ],
              )
              : _content(data),
    );
  }

  Widget _content(Map<String, dynamic> data) {
    final grandTotal = _num(data['grandTotalUsd']);
    final customers = Map<String, dynamic>.from(
      data['customers'] as Map? ?? {},
    );
    final agents = Map<String, dynamic>.from(data['agents'] as Map? ?? {});
    final merchants = Map<String, dynamic>.from(
      data['merchants'] as Map? ?? {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Platform balance (escrow)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TouchScale(
              onTap: _load,
              child: const Icon(
                Icons.refresh_rounded,
                color: BybitPalette.muted,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Total custodial funds held across every wallet on the platform.',
          style: TextStyle(
            color: BybitPalette.muted2,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '\$${grandTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        _categoryRow('Customers', customers),
        const SizedBox(height: 10),
        _categoryRow('Agents', agents, showCommission: true),
        const SizedBox(height: 10),
        _categoryRow('Merchants', merchants),
      ],
    );
  }

  Widget _categoryRow(
    String label,
    Map<String, dynamic> data, {
    bool showCommission = false,
  }) {
    final total = _num(data['totalUsd']);
    final count = _num(data['count']).toInt();
    final commission = showCommission ? _num(data['commission_usd']) : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'account' : 'accounts'}${commission > 0 ? ' · incl. \$${commission.toStringAsFixed(2)} commission' : ''}',
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: BybitPalette.accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
