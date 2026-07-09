import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'aml_queue_screen.dart';
import 'ledger_screen.dart';

class AdminConsoleScreen extends StatelessWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final balancedCount = appState.ledgerTransactions
        .where((transaction) => transaction.isBalanced)
        .length;
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
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
            Row(
              children: [
                Expanded(child: _metric('KYC tier', appState.kycTier)),
                const SizedBox(width: 10),
                Expanded(child: _metric('Ledger', '$balancedCount/${appState.ledgerTransactions.length} balanced')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _metric('Phone', appState.phoneVerified ? 'Verified' : 'Pending')),
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
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 12)),
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
                      style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BybitPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
