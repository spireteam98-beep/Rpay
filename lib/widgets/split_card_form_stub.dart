import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'bybit_wallet_ui.dart';
import 'card_confirm_result.dart';

/// Mobile fallback: Stripe's native combined [CardField] (number, expiry
/// and CVC in one row) — the split-field web layout has no equivalent
/// native widget, and the native SDK's own field is already a polished,
/// platform-appropriate control. Grouped into the same card-shaped panel
/// (with a live preview above it) as the web split-field layout for visual
/// parity. The cardholder name comes from the signed-in profile, not a
/// separate field — see [PaymentMethodFormState].
class SplitCardForm extends StatefulWidget {
  final TextEditingController nameController;
  final ValueChanged<bool> onCompleteChanged;

  const SplitCardForm({
    super.key,
    required this.nameController,
    required this.onCompleteChanged,
  });

  @override
  State<SplitCardForm> createState() => SplitCardFormState();
}

class SplitCardFormState extends State<SplitCardForm> {
  CardFieldInputDetails? _details;

  void _notifyComplete() {
    widget.onCompleteChanged(
      _details?.complete == true &&
          widget.nameController.text.trim().isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BybitPalette.surface2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A2E35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Card details',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CardField(
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  cursorColor: Colors.black87,
                  numberHintText: '1234 1234 1234 1234',
                  expirationHintText: 'MM/YY',
                  cvcHintText: 'CVC',
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.credit_card_rounded,
                      color: Colors.black45,
                      size: 20,
                    ),
                  ),
                  onCardChanged: (card) {
                    setState(() => _details = card);
                    _notifyComplete();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<CardConfirmResult> confirmCardPayment(String clientSecret) async {
    if (_details?.complete != true) {
      return const CardConfirmResult.failure('Enter your card details.');
    }
    try {
      final intent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(name: widget.nameController.text),
          ),
        ),
      );
      if (intent.status == PaymentIntentsStatus.Succeeded) {
        return CardConfirmResult.success(intent.id);
      }
      return CardConfirmResult.failure(
        'Card payment status: ${intent.status.name}',
      );
    } on StripeException catch (err) {
      return CardConfirmResult.failure(
        err.error.localizedMessage ??
            err.error.message ??
            'Your card was declined.',
      );
    }
  }
}
