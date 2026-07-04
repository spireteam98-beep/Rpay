import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Ops console', style: Theme.of(context).textTheme.displaySmall),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: AppTheme.heroCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleIcon(Icons.admin_panel_settings_outlined, color: AppTheme.onLime, size: 52),
                  const SizedBox(height: 18),
                  const Text(
                    'Phase 1 controls',
                    style: TextStyle(
                      color: AppTheme.onLime,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Identity, AML and ledger health for the pilot.',
                    style: TextStyle(
                      color: AppTheme.onLime,
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
                Expanded(child: _metric('AML', 'Rules active')),
              ],
            ),
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
              '0 sanctions hits, 0 high-risk cases',
              () {},
            ),
            _opsTile(
              context,
              Icons.assignment_turned_in_outlined,
              'Regulatory pack',
              'MTB and mobile money evidence checklist',
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return GlassTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
      child: GlassTile(
        onTap: onTap,
        child: Row(
          children: [
            CircleIcon(icon, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }
}
