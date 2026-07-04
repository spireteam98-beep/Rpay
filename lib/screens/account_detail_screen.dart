import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
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
      backgroundColor: AppTheme.darkBackground,
      appBar: KashBackBar(liveAccount.title),
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
      decoration:
          account.type == KashAccountType.crypto
              ? AppTheme.heroCard
              : BoxDecoration(
                color: AppTheme.cardDarkBackground,
                borderRadius: BorderRadius.circular(AppTheme.rHero),
                border: Border.all(color: AppTheme.glassStroke),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleIcon(
            account.icon,
            bg:
                account.type == KashAccountType.crypto
                    ? AppTheme.onLime.withOpacity(0.10)
                    : AppTheme.cardLightBackground,
            color:
                account.type == KashAccountType.crypto
                    ? AppTheme.onLime
                    : account.accent,
            size: 52,
          ),
          const SizedBox(height: 22),
          Text(
            account.balance,
            style: TextStyle(
              color:
                  account.type == KashAccountType.crypto
                      ? AppTheme.onLime
                      : AppTheme.textWhite,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            account.currency,
            style: TextStyle(
              color:
                  account.type == KashAccountType.crypto
                      ? AppTheme.onLime.withOpacity(0.72)
                      : AppTheme.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            account.subtitle,
            style: TextStyle(
              color:
                  account.type == KashAccountType.crypto
                      ? AppTheme.onLime.withOpacity(0.78)
                      : AppTheme.textLightGrey,
              fontSize: 14,
            ),
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
        decoration: AppTheme.glassCard,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
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
        color: AppTheme.cardDarkBackground,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textLightGrey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _transactionTile(KashTransaction transaction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassTile(
        child: Row(
          children: [
            CircleIcon(transaction.icon, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              transaction.amount,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textWhite,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}
