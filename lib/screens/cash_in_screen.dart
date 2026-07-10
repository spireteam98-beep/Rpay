import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/payment_method_form.dart';

class CashInScreen extends StatelessWidget {
  const CashInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final wallet = appState.accountByType(KashAccountType.mobileMoney);
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Cash In'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add money',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cash in with card, M-Pesa or Waafi, then trade or transfer from your Web3 wallet.',
                style: TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              BybitCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: wallet.accent.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(wallet.icon, color: wallet.accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destination wallet',
                            style: TextStyle(
                              color: BybitPalette.muted2,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            wallet.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      wallet.balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BybitCard(
                padding: const EdgeInsets.all(18),
                child: PaymentMethodForm(
                  initialAmountText: '1000',
                  submitLabel: 'Cash in now',
                  onCredited: (amount, currency, gateway, gatewayLabel) async {
                    final amountUsd = currency == 'KES' ? amount / 130 : amount;
                    await appState.syncFromBackend();
                    if (!context.mounted) return;
                    await _showDone(
                      context,
                      'Cash in complete',
                      '${amountUsd.toStringAsFixed(2)} USD credited to your wallet.',
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              const BybitCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Funding rails',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    BybitInfoLine('Card', 'Instant'),
                    BybitInfoLine('M-Pesa', 'KES supported'),
                    BybitInfoLine('Waafi', 'Somalia rail'),
                  ],
                ),
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
      builder:
          (dialogContext) => Dialog(
            backgroundColor: BybitPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: BybitPalette.accent,
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  BybitPrimaryButton(
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
