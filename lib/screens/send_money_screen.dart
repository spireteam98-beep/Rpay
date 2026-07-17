import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

/// Mobile money providers offered on the "Mobile money" rail: display name,
/// icon, brand-ish accent color, and a recipient-number hint per provider.
const List<(String, IconData, Color, String)> _mobileMoneyProviders = [
  (
    'EVC Plus',
    Icons.phone_iphone_rounded,
    Color(0xFF00A651),
    '+252 61 000 0000',
  ),
  ('Zaad', Icons.sim_card_rounded, Color(0xFFEE3224), '+252 63 000 0000'),
  (
    'Sahal',
    Icons.account_balance_wallet_rounded,
    Color(0xFF1565C0),
    '+252 90 000 0000',
  ),
  ('M-Pesa', Icons.smartphone_rounded, Color(0xFF4CAF50), '+254 7XX XXX XXX'),
  ('Waafi', Icons.contactless_rounded, Color(0xFFFF6B35), '+252 61 000 0000'),
  (
    'MTN',
    Icons.signal_cellular_alt_rounded,
    Color(0xFFFFCC00),
    '+234 8XX XXX XXXX',
  ),
  ('Paytm', Icons.qr_code_2_rounded, Color(0xFF00BAF2), '+91 98XXX XXXXX'),
];

class SendMoneyScreen extends StatefulWidget {
  final KashAccount? sourceAccount;

  const SendMoneyScreen({super.key, this.sourceAccount});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  late KashAccountType _sourceType;
  String _rail = 'Crypto address';
  String _mobileMoneyProvider = _mobileMoneyProviders.first.$1;
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sourceType = widget.sourceAccount?.type ?? KashAccountType.crypto;
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
                'Send assets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Route crypto, wallet balance, mobile money or bank transfers from one Bybit-style flow.',
                style: TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              _sourceSelector(appState.accounts),
              const SizedBox(height: 16),
              _railSelector(),
              if (_rail == 'Mobile money') ...[
                const SizedBox(height: 18),
                const Text(
                  'Choose provider',
                  style: TextStyle(
                    color: BybitPalette.muted2,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _mobileMoneyGrid(),
              ],
              const SizedBox(height: 16),
              _inputCard(
                label:
                    _rail == 'Mobile money'
                        ? '$_mobileMoneyProvider number'
                        : 'Recipient address',
                hint: _recipientHint,
                icon: Icons.qr_code_scanner_rounded,
                controller: _recipientController,
              ),
              const SizedBox(height: 16),
              _inputCard(
                label: 'Amount',
                hint: '0.00',
                icon: Icons.all_inclusive_rounded,
                controller: _amountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
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
    switch (_rail) {
      case 'Mobile money':
        return _mobileMoneyProviders
            .firstWhere((p) => p.$1 == _mobileMoneyProvider)
            .$4;
      case 'Crypto address':
        return '0x... or wallet address';
      case 'Bank account':
        return 'Account number or IBAN';
      default:
        return '@username or phone';
    }
  }

  Widget _sourceSelector(List<KashAccount> accounts) {
    return BybitCard(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<KashAccountType>(
          value: _sourceType,
          dropdownColor: BybitPalette.surface,
          iconEnabledColor: BybitPalette.muted,
          isExpanded: true,
          items:
              accounts.map((account) {
                return DropdownMenuItem(
                  value: account.type,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: account.accent.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          account.icon,
                          color: account.accent,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              account.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              account.balance,
                              style: const TextStyle(
                                color: BybitPalette.muted2,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (account) {
            if (account != null) setState(() => _sourceType = account);
          },
        ),
      ),
    );
  }

  Widget _railSelector() {
    final rails = ['Crypto address', 'Wayaki', 'Mobile money', 'Bank account'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          rails.map((rail) {
            final selected = rail == _rail;
            return TouchScale(
              onTap: () => setState(() => _rail = rail),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      selected ? BybitPalette.selected : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  rail,
                  style: TextStyle(
                    color: selected ? Colors.white : BybitPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _mobileMoneyGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children:
          _mobileMoneyProviders.map((provider) {
            final (name, icon, color, _) = provider;
            final selected = name == _mobileMoneyProvider;
            return TouchScale(
              onTap: () => setState(() => _mobileMoneyProvider = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      selected ? BybitPalette.selected : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? BybitPalette.accent : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 19),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : BybitPalette.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _inputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted2,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: BybitPalette.muted),
              filled: true,
              fillColor: BybitPalette.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(color: BybitPalette.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(KashAppState appState, KashAccount source) {
    final fee = appState.transferFee(_rail);
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfer details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          BybitInfoLine(
            'Route',
            '${source.title} -> ${_rail == 'Mobile money' ? _mobileMoneyProvider : _rail}',
          ),
          BybitInfoLine(
            'Speed',
            _rail == 'Crypto address' ? 'Network dependent' : 'Instant sandbox',
          ),
          BybitInfoLine(
            'Fee',
            fee == 0 ? 'Free' : '\$${fee.toStringAsFixed(2)} estimated',
          ),
          BybitInfoLine('Available', source.balance),
          BybitInfoLine(
            'Limits (${appState.kycTier})',
            '\$${appState.remainingDailyLimit.toStringAsFixed(0)} left today',
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
      builder:
          (_) => Dialog(
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
                    result.message,
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
                  'Payment Confirmation',
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
            const SizedBox(height: 24),
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

/// Final gate before a transfer actually fires — a 6-digit transaction PIN,
/// same shape as the payment confirmation step every major wallet app uses.
class _SecurityVerificationSheet extends StatefulWidget {
  const _SecurityVerificationSheet();

  @override
  State<_SecurityVerificationSheet> createState() =>
      _SecurityVerificationSheetState();
}

class _SecurityVerificationSheetState
    extends State<_SecurityVerificationSheet> {
  static const _pinLength = 6;
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
  /// user enters a PIN here (no PIN set yet), those same 6 digits become
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
            _keypad(),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Column(
      children:
          rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children:
                    row.map((key) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _keypadButton(key),
                        ),
                      );
                    }).toList(),
              ),
            );
          }).toList(),
    );
  }

  Widget _keypadButton(String key) {
    if (key.isEmpty) return const SizedBox(height: 52);
    final isDelete = key == 'del';
    return TouchScale(
      onTap: isDelete ? _backspace : () => _tapDigit(key),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BybitPalette.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            isDelete
                ? const Icon(
                  Icons.backspace_outlined,
                  color: BybitPalette.muted2,
                  size: 20,
                )
                : Text(
                  key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
      ),
    );
  }
}
