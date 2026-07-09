import 'dart:async';

import 'package:flutter/material.dart';
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
  List<Cryptocurrency> _coins = Cryptocurrency.assets;
  late Cryptocurrency _selectedCrypto;

  @override
  void initState() {
    super.initState();
    _selectedCrypto = widget.selectedCrypto ?? Cryptocurrency.assets[1]; // ETH
    _loadMarket();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Buy Crypto'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buy crypto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick an asset and pay with Card, M-Pesa or Waafi — it lands straight in your custody wallet.',
                style: TextStyle(color: BybitPalette.muted2, fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 24),
              _cryptoSelector(),
              const SizedBox(height: 18),
              BybitCard(
                padding: const EdgeInsets.all(18),
                child: PaymentMethodForm(
                  initialAmountText: '',
                  submitLabel: 'Buy ${_selectedCrypto.symbol}',
                  onCredited: _buyWith,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cryptoSelector() {
    return TouchScale(
      onTap: _showCryptoPicker,
      child: BybitCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (_selectedCrypto.isPriceUp
                        ? BybitPalette.green
                        : BybitPalette.red)
                    .withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.currency_bitcoin_rounded,
                color: _selectedCrypto.isPriceUp
                    ? BybitPalette.green
                    : BybitPalette.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asset',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_selectedCrypto.name} (${_selectedCrypto.symbol})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _selectedCrypto.formattedPrice,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: BybitPalette.muted),
          ],
        ),
      ),
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
                      color: crypto.isPriceUp
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
      builder: (dialogContext) => Dialog(
        backgroundColor: BybitPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: BybitPalette.accent,
                child: Icon(Icons.check_rounded, color: Colors.black, size: 38),
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
                style: const TextStyle(color: BybitPalette.muted2, fontSize: 13),
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
