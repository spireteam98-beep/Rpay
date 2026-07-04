import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';

class CashInScreen extends StatefulWidget {
  const CashInScreen({super.key});

  @override
  State<CashInScreen> createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  String _rail = 'EVC Plus';
  final TextEditingController _amountController = TextEditingController(text: '100');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
                'Fund domestic wallet',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sandbox cash-in through Somali mobile money rails.',
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
              _railSelector(),
              const SizedBox(height: 20),
              KashTextField(
                label: 'Amount',
                hint: '0.00',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: _amountController,
              ),
              const SizedBox(height: 22),
              GlassTile(
                child: Column(
                  children: [
                    _row('Rail', _rail),
                    const SizedBox(height: 12),
                    _row('Posting', 'Instant sandbox ledger'),
                    const SizedBox(height: 12),
                    _row('Fee', 'Free in pilot'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Add money', onTap: () => _submit(appState)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railSelector() {
    final rails = ['EVC Plus', 'Zaad', 'Sahal', 'M-Pesa'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rails.map((rail) {
        final selected = rail == _rail;
        return GestureDetector(
          onTap: () => setState(() => _rail = rail),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryColor : AppTheme.cardDarkBackground,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.glassStroke,
              ),
            ),
            child: Text(
              rail,
              style: TextStyle(
                color: selected ? AppTheme.onLime : AppTheme.textLightGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _submit(KashAppState appState) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final result = appState.submitCashIn(
      destinationType: KashAccountType.mobileMoney,
      rail: _rail,
      amount: amount,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.cardLightBackground,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
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
              const Text(
                'Money added',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Done',
                onTap: () {
                  Navigator.of(context).pop();
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
