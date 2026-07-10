import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'send_money_screen.dart';

class AccountDetailScreen extends StatelessWidget {
  final KashAccount account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final liveAccount = context.watch<KashAppState>().accountByType(
      account.type,
    );
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: BybitSubHeader(liveAccount.title),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(liveAccount),
              const SizedBox(height: 18),
              _actions(context, liveAccount),
              const SizedBox(height: 22),
              _sectionTitle('Connected rails'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: liveAccount.rails.map(_railChip).toList(),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Recent activity'),
              const SizedBox(height: 12),
              if (liveAccount.transactions.isEmpty)
                _emptyActivity()
              else
                ...liveAccount.transactions.map(_transactionTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(KashAccount account) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              account.type == KashAccountType.crypto
                  ? BybitPalette.accent.withOpacity(0.4)
                  : const Color(0xFF242832),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: account.accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(account.icon, color: account.accent, size: 24),
          ),
          const SizedBox(height: 22),
          Text(
            account.balance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            account.currency,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            account.subtitle,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, KashAccount account) {
    return Row(
      children: [
        Expanded(
          child: _action(
            context,
            Icons.north_east_rounded,
            'Send',
            () => Navigator.of(
              context,
            ).push(kashRoute(SendMoneyScreen(sourceAccount: account))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _action(context, Icons.south_rounded, 'Add', () {})),
        const SizedBox(width: 10),
        Expanded(
          child: _action(context, Icons.receipt_long_rounded, 'Details', () {}),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF242832)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BybitPalette.accent, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BybitPalette.muted2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _transactionTile(KashTransaction transaction) {
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
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyActivity() {
    return BybitCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, color: BybitPalette.muted),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No transactions yet on this account.',
              style: TextStyle(color: BybitPalette.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    );
  }
}
