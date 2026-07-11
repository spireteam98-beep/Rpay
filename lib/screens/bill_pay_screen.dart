import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

const _quickBillers = ['KPLC Prepaid', 'Nairobi Water', 'DSTV', 'Zuku'];

/// Pay a biller (utility, pay-TV, water) straight from the wallet — the
/// M-Pesa PayBill pattern, minus a live utility-provider integration: this
/// debits the wallet and books it through the ledger against a "Bill
/// payments clearing" account, same as a merchant till payment.
class BillPayScreen extends StatefulWidget {
  const BillPayScreen({super.key});

  @override
  State<BillPayScreen> createState() => _BillPayScreenState();
}

class _BillPayScreenState extends State<BillPayScreen> {
  final _billerController = TextEditingController();
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;
  int _refreshTick = 0;

  @override
  void dispose() {
    _billerController.dispose();
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final biller = _billerController.text.trim();
    final account = _accountController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (biller.isEmpty) {
      BybitToast.error(context, 'Choose or enter a biller');
      return;
    }
    if (account.isEmpty) {
      BybitToast.error(context, 'Enter the account / meter number');
      return;
    }
    if (amount <= 0) {
      BybitToast.error(context, 'Enter an amount greater than 0');
      return;
    }
    if (!ApiService.hasSession) {
      BybitToast.error(context, 'Sign in to continue using the live backend.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.payBill(
        billerName: biller,
        accountNumber: account,
        currency: 'KES',
        amount: amount,
      );
      if (!mounted) return;
      _accountController.clear();
      _amountController.clear();
      setState(() => _refreshTick++);
      BybitToast.success(
        context,
        'Paid $biller — KES ${amount.toStringAsFixed(2)}',
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Pay bills'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a biller',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _quickBillers.map((biller) {
                      final selected = _billerController.text == biller;
                      return TouchScale(
                        onTap:
                            () =>
                                setState(() => _billerController.text = biller),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? BybitPalette.selected
                                    : BybitPalette.surface2,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            biller,
                            style: TextStyle(
                              color:
                                  selected ? Colors.white : BybitPalette.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              BybitTextField(
                label: 'Biller name',
                hint: 'e.g. KPLC Prepaid',
                icon: Icons.storefront_rounded,
                controller: _billerController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              BybitTextField(
                label: 'Account / meter number',
                hint: 'e.g. 5467 8821 09',
                icon: Icons.tag_rounded,
                controller: _accountController,
              ),
              const SizedBox(height: 16),
              BybitTextField(
                label: 'Amount (KES)',
                hint: '0.00',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: _amountController,
              ),
              const SizedBox(height: 28),
              BybitPrimaryButton(
                label: _submitting ? 'Paying...' : 'Pay bill',
                enabled: !_submitting,
                onTap: _pay,
              ),
              const SizedBox(height: 32),
              const Text(
                'Recent payments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>?>(
                key: ValueKey(_refreshTick),
                future: ApiService.myBillPayments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const BybitSkeletonList(count: 3);
                  }
                  final payments = snapshot.data ?? const [];
                  if (payments.isEmpty) {
                    return BybitCard(
                      child: const Text(
                        'No bill payments yet — pick a biller above to get started.',
                        style: TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children:
                        payments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final payment = Map<String, dynamic>.from(
                            entry.value as Map,
                          );
                          final biller =
                              payment['biller_name'] as String? ?? 'Biller';
                          final account =
                              payment['account_number'] as String? ?? '';
                          final amount =
                              (payment['amount'] as num?)?.toDouble() ?? 0;
                          final currency =
                              payment['currency'] as String? ?? 'KES';
                          final createdAt =
                              DateTime.tryParse(
                                payment['created_at'] as String? ?? '',
                              ) ??
                              DateTime.now();
                          return StaggeredFadeIn(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: BybitCard(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: BybitPalette.surface2,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: BybitPalette.accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            biller,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$account · ${DateFormat('MMM d, HH:mm').format(createdAt)}',
                                            style: const TextStyle(
                                              color: BybitPalette.muted,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '-${amount.toStringAsFixed(2)} $currency',
                                      style: const TextStyle(
                                        color: BybitPalette.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
