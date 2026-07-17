import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cryptocurrency.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/payment_method_form.dart';
import '../widgets/touch_scale.dart';

/// Buy crypto directly with Card, M-Pesa or Waafi: pick an asset, pay, and
/// the payment is immediately spent on a real trade (Binance testnet when
/// configured, otherwise an internal fill at the live price — see
/// `backend/src/routes/trade.js`).
class BuyScreen extends StatefulWidget {
  final Cryptocurrency? selectedCrypto;

  const BuyScreen({super.key, this.selectedCrypto});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  static const _gateways = [
    ('PAYSTACK', 'M-Pesa by Paystack', Icons.phone_iphone_rounded),
    ('STRIPE', 'Card by Stripe', Icons.credit_card_rounded),
    ('WAAFI', 'Waafi Somali wallet', Icons.account_balance_wallet_rounded),
  ];

  List<Cryptocurrency> _coins = Cryptocurrency.assets;
  late Cryptocurrency _selectedCrypto;
  bool _amountMode = true; // true = enter USD amount, false = enter quantity
  String _gateway = 'PAYSTACK';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCrypto = widget.selectedCrypto ?? Cryptocurrency.assets[1]; // ETH
    _loadMarket();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadMarket() async {
    final response = await ApiService.market();
    if (!mounted || response == null) return;
    final coins = Cryptocurrency.withLiveData(
      response['assets'] as Map<String, dynamic>?,
    );
    setState(() {
      _coins = coins;
      _selectedCrypto = coins.firstWhere(
        (c) => c.symbol == _selectedCrypto.symbol,
        orElse: () => _selectedCrypto,
      );
    });
  }

  double get _usdAmount {
    if (_amountMode) return double.tryParse(_amountController.text) ?? 0;
    final qty = double.tryParse(_qtyController.text) ?? 0;
    return qty * _selectedCrypto.currentPrice;
  }

  double get _qtyReceived {
    if (_selectedCrypto.currentPrice <= 0) return 0;
    if (!_amountMode) return double.tryParse(_qtyController.text) ?? 0;
    final usd = double.tryParse(_amountController.text) ?? 0;
    return usd / _selectedCrypto.currentPrice;
  }

  String get _gatewayLabel => _gateways.firstWhere((g) => g.$1 == _gateway).$2;
  IconData get _gatewayIcon => _gateways.firstWhere((g) => g.$1 == _gateway).$3;

  String get _processingTime => switch (_gateway) {
    'STRIPE' => 'Instant',
    _ => 'A few minutes',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                child: Column(
                  children: [
                    _amountCard(),
                    const SizedBox(height: 16),
                    _paymentMethodRow(),
                    const SizedBox(height: 16),
                    _infoCard(),
                    const SizedBox(height: 20),
                    PaymentMethodForm(
                      submitLabel: 'Buy ${_selectedCrypto.symbol}',
                      fixedAmount: _usdAmount,
                      showGatewaySelector: false,
                      gateway: _gateway,
                      onCredited: _buyWith,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 20, 0),
          child: Row(
            children: [
              TouchScale(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: BybitPalette.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: BybitPalette.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _selectedCrypto.symbol.isEmpty
                                ? '?'
                                : _selectedCrypto.symbol.substring(0, 1),
                            style: const TextStyle(
                              color: BybitPalette.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Buy ${_selectedCrypto.symbol}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 42),
            ],
          ),
        ),
        SizedBox(
          height: 116,
          width: double.infinity,
          child: ClipPath(
            clipper: const BybitWaveClipper(),
            child: Container(
              color: BybitPalette.accent,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 44),
              child: _unitPricePill(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unitPricePill() {
    return TouchScale(
      onTap: _showCryptoPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unit price ',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              _selectedCrypto.formattedPrice,
              style: const TextStyle(
                color: BybitPalette.accent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountCard() {
    return BybitCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BybitPalette.surface2,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _amountModeTab('Amount', true),
                _amountModeTab('Quantity', false),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey(_amountMode),
                  controller: _amountMode ? _amountController : _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: BybitPalette.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(
                _amountMode ? 'USD' : _selectedCrypto.symbol,
                style: const TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '|',
                style: TextStyle(color: BybitPalette.surface2, fontSize: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Max',
                style: TextStyle(
                  color: BybitPalette.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: BybitPalette.surface2, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You receive',
                style: TextStyle(color: BybitPalette.muted, fontSize: 13.5),
              ),
              Text(
                '${_qtyReceived.toStringAsFixed(6)} ${_selectedCrypto.symbol.toUpperCase()}',
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountModeTab(String label, bool mode) {
    final selected = _amountMode == mode;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _amountMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? BybitPalette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : BybitPalette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _paymentMethodRow() {
    return TouchScale(
      onTap: _showGatewayPicker,
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
              child: Icon(_gatewayIcon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment method',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _gatewayLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BybitPalette.muted),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          BybitInfoLine('Processing time', _processingTime),
          const BybitInfoLine('Rail', 'Wayaki custody'),
          const BybitInfoLine('Status', 'Ready'),
        ],
      ),
    );
  }

  void _showGatewayPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Select payment method',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ..._gateways.map((gateway) {
                return ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: BybitPalette.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(gateway.$3, color: Colors.white),
                  ),
                  title: Text(
                    gateway.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  trailing:
                      gateway.$1 == _gateway
                          ? const Icon(
                            Icons.check_circle_rounded,
                            color: BybitPalette.accent,
                          )
                          : null,
                  onTap: () {
                    setState(() => _gateway = gateway.$1);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCryptoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Select an asset',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ..._coins.map((crypto) {
                return ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (crypto.isPriceUp
                              ? BybitPalette.green
                              : BybitPalette.red)
                          .withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.currency_bitcoin_rounded,
                      color:
                          crypto.isPriceUp
                              ? BybitPalette.green
                              : BybitPalette.red,
                    ),
                  ),
                  title: Text(
                    crypto.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${crypto.symbol} • ${crypto.formattedPrice}',
                    style: const TextStyle(color: BybitPalette.muted),
                  ),
                  onTap: () {
                    setState(() => _selectedCrypto = crypto);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buyWith(
    double amount,
    String currency,
    String gateway,
    String gatewayLabel,
  ) async {
    try {
      final fill = await ApiService.trade(
        side: 'buy',
        asset: _selectedCrypto.symbol,
        usdAmount: amount,
        quoteCurrency: currency,
      );
      if (!mounted) return;
      final qty = (fill['qty'] as num?)?.toDouble() ?? 0;
      final executionMode = fill['executionMode'] as String?;
      unawaited(context.read<KashAppState>().syncFromBackend());
      await _showResult(
        'Crypto purchased',
        '${qty.toStringAsFixed(6)} ${_selectedCrypto.symbol} added to your custody wallet'
            '${executionMode == 'external-market' ? ' via Binance testnet.' : '.'}',
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      unawaited(context.read<KashAppState>().syncFromBackend());
      await _showResult(
        'Payment received, purchase failed',
        'Your $currency ${amount.toStringAsFixed(2)} payment went through and is sitting in your wallet balance, but the trade could not complete: ${err.message}. Try again from Trading, or contact support.',
      );
    } catch (_) {
      if (!mounted) return;
      unawaited(context.read<KashAppState>().syncFromBackend());
      await _showResult(
        'Payment received, purchase failed',
        'Your $currency ${amount.toStringAsFixed(2)} payment went through and is sitting in your wallet balance, but the trade could not complete. Try again from Trading, or contact support.',
      );
    }
  }

  Future<void> _showResult(String title, String message) {
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
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 13,
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
