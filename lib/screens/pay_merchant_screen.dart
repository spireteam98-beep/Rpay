import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';

/// Reached by scanning a merchant's QR code or opening their payment link
/// (wayaki.com/app/ with a `pay` query param set to the till number — see
/// main.dart, which routes here) or by typing in a till number directly.
/// Shows who you're about to pay before
/// asking for an amount.
class PayMerchantScreen extends StatefulWidget {
  final String tillNumber;
  const PayMerchantScreen({super.key, required this.tillNumber});

  @override
  State<PayMerchantScreen> createState() => _PayMerchantScreenState();
}

class _PayMerchantScreenState extends State<PayMerchantScreen> {
  bool _loading = true;
  Map<String, dynamic>? _merchant;
  final _amountController = TextEditingController();
  String _currency = 'KES';
  bool _paying = false;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final merchant = await ApiService.merchantByTill(widget.tillNumber);
    if (!mounted) return;
    setState(() {
      _merchant = merchant;
      _loading = false;
    });
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      BybitToast.error(context, 'Enter a positive amount');
      return;
    }
    setState(() => _paying = true);
    try {
      await ApiService.payMerchantTill(
        tillNumber: widget.tillNumber,
        currency: _currency,
        amount: amount,
      );
      if (!mounted) return;
      unawaited(context.read<KashAppState>().syncFromBackend());
      setState(() => _paid = true);
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Pay merchant'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : _merchant == null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Business ID ${widget.tillNumber} was not found or is not active.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BybitPalette.muted),
                    ),
                  ),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: _paid ? _successView(_merchant!) : _payForm(_merchant!),
                ),
      ),
    );
  }

  Widget _payForm(Map<String, dynamic> merchant) {
    final name = merchant['name'] as String? ?? 'Merchant';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: BybitPalette.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ${widget.tillNumber}',
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: BybitTextField(
                label: 'Amount',
                hint: '0.00',
                icon: Icons.payments_outlined,
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Currency',
                    style: TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: BybitPalette.input,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        dropdownColor: BybitPalette.surface2,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'KES',
                            child: Center(child: Text('KES')),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Center(child: Text('USD')),
                          ),
                        ],
                        onChanged:
                            (value) => setState(() => _currency = value ?? 'KES'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(
          label: _paying ? 'Paying...' : 'Pay $name',
          enabled: !_paying,
          onTap: _pay,
        ),
      ],
    );
  }

  Widget _successView(Map<String, dynamic> merchant) {
    final name = merchant['name'] as String? ?? 'Merchant';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const CircleAvatar(
          radius: 40,
          backgroundColor: BybitPalette.accent,
          child: Icon(Icons.check_rounded, color: Colors.black, size: 40),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment sent',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$name has been paid.',
          style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(
          label: 'Done',
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
