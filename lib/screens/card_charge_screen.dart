import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/sound_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';
import '../widgets/kash_widgets.dart' show kashRoute;
import 'receipt_screen.dart';

enum _Stage { amount, tap, pin, charging, done }

/// Merchant point of sale for Fareenn tap cards: enter the amount, the
/// customer taps their card on this phone and enters their PIN, and the
/// money moves from their wallet to the merchant.
class CardChargeScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  const CardChargeScreen({super.key, required this.merchantId, required this.merchantName});

  @override
  State<CardChargeScreen> createState() => _CardChargeScreenState();
}

class _CardChargeScreenState extends State<CardChargeScreen> {
  _Stage _stage = _Stage.amount;
  String _amount = '';
  String _currency = 'USD';
  String _pin = '';
  NfcTap? _tap;
  String? _holder;
  String? _error;
  Map<String, dynamic>? _receipt;

  double get _value => double.tryParse(_amount) ?? 0;

  @override
  void dispose() {
    NfcService.stop();
    super.dispose();
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_stage == _Stage.pin) {
        if (k == '⌫') {
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        } else if (k != '.' && _pin.length < 4) {
          _pin += k;
        }
        return;
      }
      if (k == '⌫') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount = _amount.isEmpty ? '0.' : '$_amount.';
      } else {
        final dot = _amount.indexOf('.');
        if (dot >= 0 && _amount.length - dot > 2) return;
        if (_amount.replaceAll('.', '').length >= 7) return;
        _amount = _amount == '0' ? k : _amount + k;
      }
    });
    if (_stage == _Stage.pin && _pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _charge);
    }
  }

  Future<void> _startTap() async {
    if (_value <= 0) return;
    if (!NfcService.supported) {
      setState(() => _error = 'Use Chrome on an Android phone with NFC turned on to accept card payments.');
      return;
    }
    setState(() {
      _stage = _Stage.tap;
      _error = null;
    });
    try {
      final tap = await NfcService.read(timeout: const Duration(seconds: 60));
      HapticFeedback.mediumImpact();
      // Cards are recognised by serial number; the Fareenn link on the card
      // is optional. Without it the server asks for the customer's PIN.
      if (!mounted) return;
      setState(() {
        _tap = tap;
        _stage = _Stage.charging;
      });
      await _charge();
    } on NfcException catch (e) {
      if (mounted) setState(() { _stage = _Stage.amount; _error = e.message; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _stage = _Stage.amount; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _stage = _Stage.amount; _error = 'Card read failed. Try again.'; });
    }
  }

  Future<void> _charge() async {
    final tap = _tap;
    if (tap == null) return;
    final pin = _stage == _Stage.pin && _pin.length == 4 ? _pin : null;
    setState(() => _stage = _Stage.charging);
    try {
      final receipt = await ApiService.nfcCharge(
        merchantId: widget.merchantId,
        uid: tap.uid,
        token: tap.token,
        amount: _value,
        currency: _currency,
        pin: pin,
      );
      HapticFeedback.heavyImpact();
      SoundService.paymentSuccess();
      if (mounted) setState(() { _receipt = receipt; _holder = receipt['holder'] as String?; _stage = _Stage.done; });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PIN_REQUIRED') {
        // Serial-only card: the customer confirms with their Fareenn PIN.
        setState(() {
          _holder = e.data?['holder'] as String?;
          _pin = '';
          _error = null;
          _stage = _Stage.pin;
        });
        return;
      }
      final wrongPin = e.message.startsWith('Incorrect PIN') && !e.message.contains('frozen');
      setState(() {
        _error = wrongPin ? e.message : 'Declined: ${e.message}';
        _pin = '';
        // A wrong PIN keeps the customer on the PIN pad for another try.
        _stage = wrongPin ? _Stage.pin : _Stage.amount;
      });
    }
  }

  void _newSale() => setState(() {
        _stage = _Stage.amount;
        _amount = '';
        _pin = '';
        _tap = null;
        _holder = null;
        _receipt = null;
        _error = null;
      });

  void _cancel() {
    NfcService.stop();
    setState(() {
      _stage = _Stage.amount;
      _pin = '';
      _tap = null;
    });
  }

  String get _money => '${_currency == 'USD' ? '\$' : 'KES '}${_amount.isEmpty ? '0' : _amount}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: BybitSubHeader('Charge a card · ${widget.merchantName}'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: switch (_stage) {
            _Stage.amount => _amountView(),
            _Stage.tap => _tapView(),
            _Stage.pin => _pinView(),
            _Stage.charging => _chargingView(),
            _Stage.done => _doneView(),
          },
        ),
      ),
    );
  }

  Widget _errorBox() => _error == null
      ? const SizedBox(height: 0)
      : Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x1FFF4D57), borderRadius: BorderRadius.circular(14)),
          child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
        );

  Widget _amountView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in ['USD', 'KES'])
              TouchScale(
                onTap: () => setState(() => _currency = c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currency == c ? BybitPalette.accent : BybitPalette.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const Spacer(),
        const Text('Amount to charge', style: TextStyle(color: BybitPalette.muted, fontSize: 14)),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(_money, style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
        ),
        const Spacer(),
        _errorBox(),
        _keypad(withDot: true),
        const SizedBox(height: 14),
        BybitPrimaryButton(label: 'Tap card to pay', enabled: _value > 0, onTap: _startTap),
      ],
    );
  }

  Widget _tapView() {
    return Column(
      children: [
        const Spacer(),
        Text(_money, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        const SizedBox(height: 30),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BybitPalette.accent.withAlpha(30),
            border: Border.all(color: BybitPalette.accent, width: 2),
          ),
          child: const Icon(Icons.contactless_outlined, color: Colors.white, size: 90),
        ),
        const SizedBox(height: 30),
        const Text('Tap Fareenn card to pay', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Hold the card on the back of this phone.', style: TextStyle(color: BybitPalette.muted, fontSize: 14.5)),
        const Spacer(),
        TouchScale(
          onTap: _cancel,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _chargingView() {
    return Column(
      children: [
        const Spacer(),
        Text(_money, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        const SizedBox(height: 30),
        const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 4, color: BybitPalette.accent)),
        const SizedBox(height: 24),
        Text('Processing card •••• ${_tap?.last4 ?? ''}', style: const TextStyle(color: BybitPalette.muted, fontSize: 15)),
        const Spacer(),
      ],
    );
  }

  Widget _pinView() {
    final charging = _stage == _Stage.charging;
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(_money, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '${_holder ?? 'Customer'} · card •••• ${_tap?.last4 ?? ''}',
          style: const TextStyle(color: BybitPalette.muted, fontSize: 14.5),
        ),
        const Spacer(),
        const Text('Customer: enter your Fareenn PIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? BybitPalette.accent : Colors.transparent,
                  border: Border.all(color: i < _pin.length ? BybitPalette.accent : BybitPalette.muted, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 28,
          child: charging
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: BybitPalette.accent))
              : null,
        ),
        const Spacer(),
        _errorBox(),
        IgnorePointer(ignoring: charging, child: _keypad(withDot: false)),
        TouchScale(
          onTap: charging ? null : _cancel,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _doneView() {
    final r = _receipt ?? const {};
    final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? _amount;
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 110,
          height: 110,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: BybitPalette.green),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 64),
        ),
        const SizedBox(height: 24),
        const Text('Payment approved', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        if (_holder != null) ...[
          const SizedBox(height: 6),
          Text(_holder!, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 8),
        Text('${r['currency'] ?? _currency} $amount · card •••• ${r['last4'] ?? _tap?.last4 ?? ''}',
            style: const TextStyle(color: BybitPalette.muted, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Ref ${(r['id'] as String? ?? '').split('-').first.toUpperCase()}',
            style: const TextStyle(color: BybitPalette.muted, fontSize: 13)),
        const SizedBox(height: 14),
        const Text('E-receipt sent to the customer and to your inbox',
            style: TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
        const Spacer(),
        if (r['id'] is String)
          TouchScale(
            onTap: () => Navigator.of(context).push(kashRoute(ReceiptScreen(receiptId: r['id'] as String))),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('View e-receipt', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        BybitPrimaryButton(label: 'New sale', onTap: _newSale),
      ],
    );
  }

  Widget _keypad({required bool withDot}) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', withDot ? '.' : '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final k in keys)
          k.isEmpty
              ? const SizedBox()
              : TouchScale(
                  onTap: () => _key(k),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: BybitPalette.surface, borderRadius: BorderRadius.circular(16)),
                    child: k == '⌫'
                        ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 22)
                        : Text(k, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                  ),
                ),
      ],
    );
  }
}
