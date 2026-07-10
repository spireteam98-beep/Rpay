import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'bybit_wallet_ui.dart';
import 'split_card_form.dart';
import 'touch_scale.dart';

/// Somali mobile numbers: 9 digits starting with 6, optionally prefixed
/// with the 252 country code (e.g. 611234567 or +252611234567).
final RegExp _somaliPhoneRegex = RegExp(r'^(?:\+?252|00252)?6\d{8}$');

bool _isValidSomaliPhone(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[\s-]'), '');
  return _somaliPhoneRegex.hasMatch(normalized);
}

/// Kenyan M-Pesa numbers: 9 digits starting with 1 or 7, optionally prefixed
/// with a leading 0 or the 254 country code (e.g. 0712345678, 254712345678).
final RegExp _kenyaPhoneRegex = RegExp(r'^(?:\+?254|0)?[17]\d{8}$');

bool _isValidKenyaPhone(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[\s-]'), '');
  return _kenyaPhoneRegex.hasMatch(normalized);
}

/// Self-contained "pay with Card, M-Pesa or Waafi" form: amount input,
/// gateway picker, phone/card capture, charge + verification flow, and the
/// loading/awaiting-approval states — all in one place so screens that need
/// to charge a payment gateway (Cash-in, Buy Crypto) don't each reimplement
/// it. Calls [onCredited] once money has actually landed (either an instant
/// gateway credit, or after the user confirms the Waafi/M-Pesa/Stripe
/// prompt), with the raw amount and currency that were charged — the caller
/// decides what a credited payment means for their screen (top up the
/// wallet, or spend it on a crypto trade).
class PaymentMethodForm extends StatefulWidget {
  final String initialAmountText;
  final String submitLabel;
  final Future<void> Function(
    double amount,
    String currency,
    String gateway,
    String gatewayLabel,
  )
  onCredited;

  /// When set, the amount field is hidden and this value is charged
  /// instead — for screens (like Buy) that collect the amount in their
  /// own UI above this form.
  final double? fixedAmount;

  /// Hide the built-in M-Pesa/Card/Waafi picker so a caller can render its
  /// own gateway selector and drive [gateway] externally instead.
  final bool showGatewaySelector;

  /// Externally-controlled gateway, used when [showGatewaySelector] is false.
  final String? gateway;

  const PaymentMethodForm({
    super.key,
    this.initialAmountText = '',
    required this.submitLabel,
    required this.onCredited,
    this.fixedAmount,
    this.showGatewaySelector = true,
    this.gateway,
  });

  @override
  State<PaymentMethodForm> createState() => PaymentMethodFormState();
}

class PaymentMethodFormState extends State<PaymentMethodForm> {
  late String _gateway;
  late final TextEditingController _amountController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final GlobalKey<SplitCardFormState> _splitCardKey = GlobalKey();
  bool _submitting = false;
  bool _awaitingApproval = false;
  bool _cardComplete = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? 'PAYSTACK';
    _amountController = TextEditingController(
      text: widget.fixedAmount?.toStringAsFixed(2) ?? widget.initialAmountText,
    );
  }

  @override
  void didUpdateWidget(covariant PaymentMethodForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gateway != null && widget.gateway != _gateway) {
      setState(() => _gateway = widget.gateway!);
    }
    if (widget.fixedAmount != null &&
        widget.fixedAmount != oldWidget.fixedAmount) {
      _amountController.text = widget.fixedAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  String get _currency => _gateway == 'PAYSTACK' ? 'KES' : 'USD';

  String get gatewayLabel {
    switch (_gateway) {
      case 'STRIPE':
        return 'Card by Stripe';
      case 'WAAFI':
        return 'Waafi Somali wallet';
      default:
        return 'M-Pesa by Paystack';
    }
  }

  bool _isPhoneValid(String phone) =>
      _gateway == 'WAAFI'
          ? _isValidSomaliPhone(phone)
          : _isValidKenyaPhone(phone);

  String? get _phoneErrorText {
    final phone = _phoneController.text;
    if (phone.isEmpty || _isPhoneValid(phone)) return null;
    return _gateway == 'WAAFI'
        ? 'Enter a valid Somalia number, e.g. 2526XXXXXXX'
        : 'Enter a valid Kenya number, e.g. 07XXXXXXXX';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showGatewaySelector) ...[
          _gatewaySelector(),
          const SizedBox(height: 20),
        ],
        if (widget.fixedAmount == null)
          BybitTextField(
            label: 'Amount ($_currency)',
            hint: '0.00',
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            controller: _amountController,
            onChanged: (_) => setState(() {}),
          ),
        if (_gateway == 'WAAFI' || _gateway == 'PAYSTACK') ...[
          const SizedBox(height: 18),
          BybitTextField(
            label:
                _gateway == 'WAAFI'
                    ? 'Waafi phone (Somalia only)'
                    : 'M-Pesa phone (Kenya only)',
            hint: _gateway == 'WAAFI' ? '2526XXXXXXX' : '07XXXXXXXX',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            controller: _phoneController,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            errorText: _phoneErrorText,
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_gateway == 'STRIPE') ...[
          const SizedBox(height: 18),
          SplitCardForm(
            key: _splitCardKey,
            nameController: _cardHolderController,
            onCompleteChanged:
                (complete) => setState(() => _cardComplete = complete),
          ),
        ],
        const SizedBox(height: 28),
        BybitPrimaryButton(
          label:
              _submitting || _awaitingApproval
                  ? 'Please wait…'
                  : widget.submitLabel,
          enabled: !(_submitting || _awaitingApproval),
          onTap: _submit,
        ),
      ],
    );
  }

  Widget _gatewaySelector() {
    final gateways = const [
      ('PAYSTACK', 'M-Pesa'),
      ('STRIPE', 'Card'),
      ('WAAFI', 'Waafi'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          gateways.map((gateway) {
            final selected = gateway.$1 == _gateway;
            return TouchScale(
              onTap: () => setState(() => _gateway = gateway.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      selected ? BybitPalette.selected : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  gateway.$2,
                  style: TextStyle(
                    color: selected ? Colors.white : BybitPalette.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Future<void> _verifyTopUp(String gateway, String reference) async {
    setState(() => _submitting = true);
    try {
      final response = await ApiService.verifyTopUp(
        gateway: gateway,
        reference: reference,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (response == null) {
        _showMessage('Verification failed', 'Unable to verify payment.');
        return;
      }

      final verified = response['verified'] == true;
      final credited = response['credited'] == true;
      final alreadyCredited = response['alreadyCredited'] == true;
      final topUp = response['topUp'] as Map<String, dynamic>?;
      final amount = (topUp?['amount'] as num?)?.toDouble() ?? 0;
      final currency = topUp?['currency'] as String? ?? _currency;

      if (verified && credited) {
        await widget.onCredited(amount, currency, gateway, gatewayLabel);
        return;
      }

      if (verified && alreadyCredited) {
        _showMessage(
          'Already credited',
          'This payment has already been credited to your account.',
        );
        return;
      }

      _showMessage(
        'Payment not verified',
        'The payment has not yet completed. Approve the prompt on your phone, then try verifying again.',
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('Verification error', err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage(
        'Verification failed',
        'Unexpected error during verification.',
      );
    }
  }

  Future<void> _showVerificationDialog(String gateway, String reference) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: BybitPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Verify payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check your phone for the payment prompt. Once you approve it, tap Verify to credit your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BybitPalette.muted2,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    BybitPrimaryButton(
                      label: 'Verify payment',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _verifyTopUp(gateway, reference);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: BybitPalette.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _submit() async {
    final amount =
        widget.fixedAmount ??
        double.tryParse(_amountController.text.trim()) ??
        0;
    final phone = _phoneController.text.trim();
    if (amount <= 0) {
      _showSnack('Enter an amount greater than 0');
      return;
    }
    if ((_gateway == 'WAAFI' || _gateway == 'PAYSTACK') &&
        !_isPhoneValid(phone)) {
      _showSnack(
        _gateway == 'WAAFI'
            ? 'Enter a valid Somalia phone number'
            : 'Enter a valid Kenya phone number',
      );
      return;
    }
    if (_gateway == 'STRIPE' && !_cardComplete) {
      _showSnack('Enter your card details');
      return;
    }
    if (!ApiService.hasSession) {
      _showSnack('Sign in to continue using the live backend.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await ApiService.createTopUp(
        gateway: _gateway,
        currency: _currency,
        amount: amount,
        phone: phone,
      );
      if (!mounted) return;
      if (response == null) {
        setState(() => _submitting = false);
        return;
      }

      final topUp = response['topUp'] as Map<String, dynamic>?;
      final chargedAmount = (topUp?['amount'] as num?)?.toDouble() ?? amount;
      final chargedCurrency = topUp?['currency'] as String? ?? _currency;

      if (_gateway == 'STRIPE') {
        final clientSecret = response['clientSecret'] as String?;
        if (clientSecret == null || clientSecret.isEmpty) {
          setState(() => _submitting = false);
          _showMessage('Payment error', 'Card payment could not be started.');
          return;
        }
        final result = await _splitCardKey.currentState!.confirmCardPayment(
          clientSecret,
        );
        if (!mounted) return;
        if (result.succeeded) {
          await _verifyTopUp('STRIPE', result.paymentIntentId!);
        } else {
          setState(() => _submitting = false);
          _showMessage(
            'Payment not completed',
            result.errorMessage ?? 'Your card was declined.',
          );
        }
        return;
      }

      setState(() => _submitting = false);
      final credited = response['credited'] == true;
      final providerRef = topUp?['providerRef'] as String?;

      if (credited) {
        await widget.onCredited(
          chargedAmount,
          chargedCurrency,
          _gateway,
          gatewayLabel,
        );
        return;
      }

      if (providerRef != null && providerRef.isNotEmpty) {
        setState(() => _awaitingApproval = true);
        await _showVerificationDialog(_gateway, providerRef);
        if (mounted) setState(() => _awaitingApproval = false);
        return;
      }

      final message =
          response['message'] as String? ??
          'Payment initialized. Reference: pending';
      _showMessage('Payment started', message);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(err.message);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BybitPalette.surface2),
    );
  }

  void _showMessage(String title, String message) {
    showDialog(
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
                    label: 'OK',
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
