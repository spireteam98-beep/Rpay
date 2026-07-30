import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/touch_scale.dart';

class SendMoneyScreen extends StatefulWidget {
  final KashAccount? sourceAccount;

  const SendMoneyScreen({super.key, this.sourceAccount});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  late KashAccountType _sourceType;
  String _rail = 'Wayaki';
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sourceType = widget.sourceAccount?.type ?? KashAccountType.walletUsd;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final source = appState.accountByType(_sourceType);
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Send'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You send',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _amountCurrencyRow(appState, source),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Available ${source.balance}',
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select channel',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _channelList(),
              const SizedBox(height: 16),
              BybitTextField(
                label:
                    _rail == 'M-Pesa' ? 'M-Pesa number' : 'Wayaki number or email',
                hint: _recipientHint,
                icon: Icons.qr_code_scanner_rounded,
                controller: _recipientController,
              ),
              const SizedBox(height: 20),
              _summary(appState, source),
              const SizedBox(height: 24),
              BybitPrimaryButton(
                label: _submitting ? 'Submitting...' : 'Review transfer',
                enabled: !_submitting,
                onTap: () => _confirm(appState, source),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _recipientHint {
    return _rail == 'M-Pesa'
        ? '+254 7XX XXX XXX'
        : 'Username, phone or email';
  }

  /// Amount input with the source currency picker inline on the same row —
  /// tapping the pill cycles between the visible accounts (there are only
  /// two: Wayaki USD and Wayaki KES) instead of opening a whole picker.
  Widget _amountCurrencyRow(KashAppState appState, KashAccount source) {
    return BybitCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TouchScale(
            onTap: () => _cycleSourceAccount(appState.visibleAccounts),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(source.icon, color: source.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    source.currency,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (appState.visibleAccounts.length > 1) ...[
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.unfold_more_rounded,
                      color: BybitPalette.muted,
                      size: 15,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleSourceAccount(List<KashAccount> accounts) {
    if (accounts.length < 2) return;
    final index = accounts.indexWhere((a) => a.type == _sourceType);
    final next = accounts[(index + 1) % accounts.length];
    setState(() {
      _sourceType = next.type;
      _rail = 'Wayaki';
    });
  }

  /// Wayaki-to-Wayaki transfer is always available. M-Pesa cash-out is too,
  /// from either wallet — a USD-sourced payout converts to KES at the live
  /// rate before it's sent (KashAppState.submitTransfer), since M-Pesa only
  /// ever settles in KES regardless of which balance it's drawn from.
  Widget _channelList() {
    const channels = [
      _ChannelOption('Wayaki', Icons.account_balance_wallet_rounded),
      _ChannelOption('M-Pesa', Icons.phone_iphone_rounded),
    ];
    return Column(children: channels.map(_channelRow).toList());
  }

  Widget _channelRow(_ChannelOption option) {
    final selected = option.name == _rail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: () => setState(() => _rail = option.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? BybitPalette.accent : const Color(0xFF242832),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: BybitPalette.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? BybitPalette.accent : BybitPalette.muted2,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(KashAppState appState, KashAccount source) {
    final fee = appState.transferFee(_rail);
    return BybitCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BybitInfoLine('Available', source.balance),
          BybitInfoLine(
            'Fee',
            fee == 0 ? 'Free' : '\$${fee.toStringAsFixed(2)} estimated',
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(KashAppState appState, KashAccount source) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a recipient and a positive amount'),
          backgroundColor: BybitPalette.surface2,
        ),
      );
      return;
    }

    final fee = appState.transferFee(_rail);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _PaymentConfirmationSheet(
            recipient: recipient,
            amount: amount,
            currency: source.currency,
            source: source,
            fee: fee,
          ),
    );
    if (confirmed != true || !mounted) return;

    final verified = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SecurityVerificationSheet(),
    );
    if (verified != true || !mounted) return;

    await _submitTransfer(appState, source, recipient, amount);
  }

  Future<void> _submitTransfer(
    KashAppState appState,
    KashAccount source,
    String recipient,
    double amount,
  ) async {
    setState(() => _submitting = true);
    final result = await appState.submitTransfer(
      sourceType: source.type,
      rail: _rail,
      recipient: recipient,
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: BybitPalette.surface2,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DoneGlassDialog(message: result.message),
    );
  }
}

/// Success dialog after a transfer clears the PIN step — a frosted-glass
/// card (blurred backdrop, translucent surface, thin light border) instead
/// of a flat solid dialog, since this is the one moment worth a bit of
/// visual flourish.
class _DoneGlassDialog extends StatelessWidget {
  final String message;

  const _DoneGlassDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  BybitPalette.accent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BybitPalette.accent.withValues(alpha: 0.16),
                    border: Border.all(
                      color: BybitPalette.accent.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: BybitPalette.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transfer queued',
                  style: TextStyle(
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
                const SizedBox(height: 24),
                BybitPrimaryButton(
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
      ),
    );
  }
}

/// Review step before a transfer goes out — recipient, amount, and funding
/// source, matching the confirm-before-you-send pattern most wallet apps
/// use so a mistyped recipient or amount gets caught before the PIN step.
class _PaymentConfirmationSheet extends StatefulWidget {
  final String recipient;
  final double amount;
  final String currency;
  final KashAccount source;
  final double fee;

  const _PaymentConfirmationSheet({
    required this.recipient,
    required this.amount,
    required this.currency,
    required this.source,
    required this.fee,
  });

  @override
  State<_PaymentConfirmationSheet> createState() =>
      _PaymentConfirmationSheetState();
}

class _PaymentConfirmationSheetState extends State<_PaymentConfirmationSheet> {
  bool _combined = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TouchScale(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: BybitPalette.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: BybitPalette.muted2,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Send to',
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Note: Wayaki transfer',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Amount',
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Recipient receives',
                  style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fee == 0
                          ? 'No fee'
                          : 'Fee \$${widget.fee.toStringAsFixed(2)} included',
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pay with',
                  style: TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Combined',
                      style: TextStyle(
                        color: BybitPalette.muted2,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Switch(
                      value: _combined,
                      onChanged: (v) => setState(() => _combined = v),
                      activeThumbColor: Colors.black,
                      activeTrackColor: BybitPalette.accent,
                      inactiveThumbColor: BybitPalette.muted,
                      inactiveTrackColor: BybitPalette.surface2,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            _payWithRow('Deduct From', widget.source.title),
            const SizedBox(height: 10),
            _payWithRow('Currency', widget.currency),
            const SizedBox(height: 20),
            const CustomPaint(
              size: Size(double.infinity, 1),
              painter: _DashedLinePainter(),
            ),
            const SizedBox(height: 20),
            BybitPrimaryButton(
              label: 'Confirm',
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payWithRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: BybitPalette.muted2, fontSize: 13.5),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Final gate before a transfer actually fires — a 4-digit transaction PIN,
/// same shape as the payment confirmation step every major wallet app uses.
class _SecurityVerificationSheet extends StatefulWidget {
  const _SecurityVerificationSheet();

  @override
  State<_SecurityVerificationSheet> createState() =>
      _SecurityVerificationSheetState();
}

class _SecurityVerificationSheetState
    extends State<_SecurityVerificationSheet> {
  static const _pinLength = 4;
  String _pin = '';
  bool _verifying = false;
  String? _error;

  void _tapDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 180), _submit);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  /// Checks the PIN against the real backend hash. The very first time a
  /// user enters a PIN here (no PIN set yet — e.g. an account created
  /// before PIN setup was part of signup), those same 4 digits become
  /// their PIN — no separate mandatory setup screen blocking a first send.
  Future<void> _submit() async {
    if (!mounted || _pin.length != _pinLength) return;
    if (!ApiService.hasSession) {
      Navigator.of(context).pop(true);
      return;
    }

    final appState = context.read<KashAppState>();
    setState(() => _verifying = true);
    try {
      if (!appState.hasPin) {
        await ApiService.setPin(pin: _pin);
        appState.markPinSet();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final verified = await ApiService.verifyPin(_pin);
      if (!mounted) return;
      if (verified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _pin = '';
          _verifying = false;
          _error = 'Incorrect PIN — try again';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _verifying = false;
        _error = 'Could not verify PIN — try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Security Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TouchScale(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: BybitPalette.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: BybitPalette.muted2,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Transaction PIN',
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_pinLength, (index) {
                final filled = index < _pin.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 42,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BybitPalette.input,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          filled
                              ? Border.all(color: BybitPalette.accent)
                              : null,
                    ),
                    child:
                        filled
                            ? const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 12,
                            )
                            : null,
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: BybitPalette.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
            BybitPrimaryButton(
              label: _verifying ? 'Verifying...' : 'Confirm',
              enabled: _pin.length == _pinLength && !_verifying,
              onTap: _submit,
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Having problems with verification?',
                style: TextStyle(
                  color: BybitPalette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            NumericKeypad(onDigit: _tapDigit, onBackspace: _backspace),
          ],
        ),
      ),
    );
  }
}

class _ChannelOption {
  final String name;
  final IconData icon;

  const _ChannelOption(this.name, this.icon);
}

/// Perforated-edge line above the confirm button on the Receipt sheet.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = BybitPalette.muted.withValues(alpha: 0.3)
          ..strokeWidth = 1;
    const dashWidth = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
