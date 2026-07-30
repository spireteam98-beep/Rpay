import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
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
  final Future<void> Function()? onPaymentNotCredited;

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
    this.onPaymentNotCredited,
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
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? 'PAYSTACK';
    _amountController = TextEditingController(
      text: widget.fixedAmount?.toStringAsFixed(2) ?? widget.initialAmountText,
    );
    // The card form no longer asks for the holder's name separately — reuse
    // the name already on file from signup so Stripe still gets a billing
    // name without making the user retype it.
    _cardHolderController.text = context.read<KashAppState>().profileName;
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
        if (_submitting || _awaitingApproval) ...[
          Center(
            child: Column(
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: BybitPalette.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _progressMessage.isEmpty
                      ? 'Starting payment...'
                      : _progressMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BybitPalette.muted2,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
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

  Future<void> _waitForPaymentResult(String gateway, String reference) async {
    if (mounted) {
      setState(() {
        _submitting = true;
        _awaitingApproval = true;
        _progressMessage =
            gateway == 'STRIPE'
                ? 'Completing your card payment...'
                : 'Waiting for approval on your phone...';
      });
    }
    try {
      // Render's signed webhook is the primary completion path. Polling this
      // endpoint is the fallback and also observes a top-up already credited
      // by that webhook (`alreadyCredited`). Keep the UI in one loading state
      // long enough for delayed mobile-money confirmations.
      const maxAttempts = 120;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        Map<String, dynamic>? response;
        try {
          response = await ApiService.verifyTopUp(
            gateway: gateway,
            reference: reference,
          );
        } on ApiException {
          // A temporary Render/provider error must not become a false payment
          // failure while the webhook may still be processing.
          if (attempt == maxAttempts - 1) rethrow;
          setState(
            () =>
                _progressMessage =
                    'Payment is processing. Reconnecting securely...',
          );
          continue;
        }
        if (!mounted) return;
        if (response == null) continue;

        final verified = response['verified'] == true;
        final credited = response['credited'] == true;
        final alreadyCredited = response['alreadyCredited'] == true;
        final topUp = response['topUp'] as Map<String, dynamic>?;
        final amount = (topUp?['amount'] as num?)?.toDouble() ?? 0;
        final currency = topUp?['currency'] as String? ?? _currency;
        final topUpStatus = (topUp?['status'] as String? ?? '').toUpperCase();
        final succeeded = verified || topUpStatus == 'SUCCEEDED';

        if (succeeded &&
            (credited || alreadyCredited || topUpStatus == 'SUCCEEDED')) {
          setState(() {
            _progressMessage = 'Payment successful. Updating your wallet...';
          });
          await widget.onCredited(amount, currency, gateway, gatewayLabel);
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _awaitingApproval = false;
            _progressMessage = '';
          });
          return;
        }

        if (response['failed'] == true || response['pending'] == false) {
          final status =
              response['providerStatus'] as String? ?? 'Payment declined';
          setState(() {
            _submitting = false;
            _awaitingApproval = false;
            _progressMessage = '';
          });
          await widget.onPaymentNotCredited?.call();
          if (!mounted) return;
          _showMessage(
            'Payment not completed',
            'M-Pesa reported: $status. Your wallet was not charged.',
          );
          return;
        }

        setState(() {
          _progressMessage =
              gateway == 'STRIPE'
                  ? 'Completing your card payment...'
                  : 'Approve the prompt on your phone. This may take a moment...';
        });
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _awaitingApproval = false;
        _progressMessage = '';
      });
      await widget.onPaymentNotCredited?.call();
      if (!mounted) return;
      _showMessage(
        'Payment is still processing',
        'The provider has not returned a final result yet. Your balance has not been changed. You can safely check your wallet again shortly.',
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _awaitingApproval = false;
        _progressMessage = '';
      });
      await widget.onPaymentNotCredited?.call();
      if (!mounted) return;
      _showMessage('Payment could not be completed', err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _awaitingApproval = false;
        _progressMessage = '';
      });
      await widget.onPaymentNotCredited?.call();
      if (!mounted) return;
      _showMessage(
        'Payment could not be completed',
        'We could not receive the final payment result. Your balance has not been changed.',
      );
    }
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

    setState(() {
      _submitting = true;
      _progressMessage = 'Starting secure payment...';
    });
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
          await _waitForPaymentResult('STRIPE', result.paymentIntentId!);
        } else {
          setState(() => _submitting = false);
          _showMessage(
            'Payment not completed',
            result.errorMessage ?? 'Your card was declined.',
          );
        }
        return;
      }

      final credited = response['credited'] == true;
      final providerRef = topUp?['providerRef'] as String?;

      if (credited) {
        setState(() {
          _awaitingApproval = true;
          _progressMessage = 'Payment successful. Updating your wallet...';
        });
        await widget.onCredited(
          chargedAmount,
          chargedCurrency,
          _gateway,
          gatewayLabel,
        );
        return;
      }

      if (providerRef != null && providerRef.isNotEmpty) {
        setState(() {
          _awaitingApproval = true;
          _progressMessage = 'Check your phone and approve the prompt.';
        });
        await _waitForPaymentResult(_gateway, providerRef);
        return;
      }

      setState(() => _submitting = false);
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
