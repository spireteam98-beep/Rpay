import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/payment_method_form.dart';

class CashInScreen extends StatelessWidget {
  const CashInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final wallet = appState.accountByType(KashAccountType.mobileMoney);
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Cash-in'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top up your account',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add money with Card, M-Pesa or Waafi, then use it for transfers, merchants and crypto.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GlassTile(
                child: Row(
                  children: [
                    CircleIcon(wallet.icon, color: wallet.accent, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destination',
                            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            wallet.title,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      wallet.balance,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PaymentMethodForm(
                initialAmountText: '1000',
                submitLabel: 'Add money',
                onCredited: (amount, currency, gateway, gatewayLabel) async {
                  final amountUsd = currency == 'KES' ? amount / 130 : amount;
                  appState.submitCashIn(
                    destinationType: KashAccountType.mobileMoney,
                    rail: gatewayLabel,
                    amount: amountUsd,
                  );
                  // Reconcile with the real backend balance (the line above
                  // is just an optimistic local update for instant feedback).
                  unawaited(appState.syncFromBackend());
                  await _showDone(
                    context,
                    'Money added',
                    '${amountUsd.toStringAsFixed(2)} USD credited to your account.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDone(BuildContext context, String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.cardDarkBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.onLime, size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Done',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
