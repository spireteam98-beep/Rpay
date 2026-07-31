import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/receipt_ticket.dart';
import '../widgets/touch_scale.dart';

class SendMoneyScreen extends StatefulWidget {
  final KashAccount? sourceAccount;
  final String? initialRecipient;

  const SendMoneyScreen({super.key, this.sourceAccount, this.initialRecipient});

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
    if (widget.initialRecipient != null) {
      _recipientController.text = widget.initialRecipient!;
    }
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
              if (_sourceType != KashAccountType.walletKes) ...[
                const SizedBox(height: 8),
                const Text(
                  'M-Pesa and Till are only available from your KES balance.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 11.5),
                ),
              ],
              const SizedBox(height: 16),
              if (_rail == 'Wayaki' && appState.frequentRecipients.isNotEmpty) ...[
                _frequentRecipientsRow(appState),
                const SizedBox(height: 12),
              ],
              BybitTextField(
                label: _recipientLabel,
                hint: _recipientHint,
                icon:
                    _rail == 'M-Pesa Till'
                        ? Icons.storefront_outlined
                        : Icons.qr_code_scanner_rounded,
                keyboardType:
                    _rail == 'M-Pesa Till'
                        ? TextInputType.number
                        : TextInputType.text,
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

  /// Tap a saved recipient (people you've sent to before) to fill the
  /// field instead of typing a phone/email/username every time.
  Widget _frequentRecipientsRow(KashAppState appState) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: appState.frequentRecipients.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final person = appState.frequentRecipients[index];
          final label = person['label'] as String? ?? '';
          final identifier = person['identifier'] as String? ?? '';
          return TouchScale(
            onTap: () => setState(() => _recipientController.text = identifier),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String get _recipientLabel {
    switch (_rail) {
      case 'M-Pesa':
        return 'M-Pesa number';
      case 'M-Pesa Till':
        return 'Till number';
      default:
        return 'Wayaki number or email';
    }
  }

  String get _recipientHint {
    switch (_rail) {
      case 'M-Pesa':
        return '+254 7XX XXX XXX';
      case 'M-Pesa Till':
        return 'e.g. 123456';
      default:
        return 'Username, phone or email';
    }
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

  /// Wayaki-to-Wayaki transfer is always available. M-Pesa/Till cash-out is
  /// KES-wallet-only: the payout draws from Paystack's real account
  /// balance, which only Paystack top-ups (the same gateway, settling into
  /// the same real account) actually fund. USD funded via Stripe or Waafi
  /// settles into a completely separate real-money account with no bridge
  /// into Paystack, so it can never reliably back an M-Pesa payout even
  /// though the in-app balance looks sufficient.
  Widget _channelList() {
    final channels = [
      const _ChannelOption('Wayaki', Icons.account_balance_wallet_rounded),
      if (_sourceType == KashAccountType.walletKes) ...[
        const _ChannelOption('M-Pesa', Icons.phone_iphone_rounded),
        const _ChannelOption('M-Pesa Till', Icons.storefront_outlined),
      ],
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A1418),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: BybitPalette.red, width: 1),
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_rounded,
              color: BybitPalette.red,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(KashAppState appState, KashAccount source) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty || amount <= 0) {
      _showErrorSnackBar('Enter a recipient and a positive amount');
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
      _showErrorSnackBar(result.message);
      return;
    }

    final fee = appState.transferFee(_rail);
    await showReceiptDialog(
      context,
      statusTitle: 'Payment Success',
      reference: result.transactionId ?? _nextFallbackReference(),
      dateTime: DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now()),
      paymentMethod: _rail,
      details: [ReceiptLine('Sent to', recipient)],
      amountLines: [
        ReceiptLine('Amount', '${source.currency} ${amount.toStringAsFixed(2)}'),
        ReceiptLine('Fee', fee == 0 ? 'Free' : '${source.currency} ${fee.toStringAsFixed(2)}'),
      ],
      total: ReceiptLine(
        'Total',
        '${source.currency} ${(amount + fee).toStringAsFixed(2)}',
        emphasize: true,
      ),
    );
  }

  String _nextFallbackReference() =>
      DateTime.now().millisecondsSinceEpoch.toString();
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Security Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TouchScale(
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
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Transaction PIN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                final filled = index < _pin.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
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
                textAlign: TextAlign.center,
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
