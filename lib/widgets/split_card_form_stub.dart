import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'bybit_wallet_ui.dart';
import 'card_confirm_result.dart';
import 'card_preview.dart';

/// Mobile fallback: Stripe's native combined [CardField] (number, expiry
/// and CVC in one row) — the split-field web layout has no equivalent
/// native widget, and the native SDK's own field is already a polished,
/// platform-appropriate control. Grouped into the same card-shaped panel
/// (with a live preview above it, and the card-holder name field it was
/// missing) as the web split-field layout for visual parity.
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
  String _brand = 'unknown';

  String _mapBrand(String? brand) {
    final raw = brand?.toLowerCase() ?? '';
    if (raw.contains('visa')) return 'visa';
    if (raw.contains('master')) return 'mastercard';
    if (raw.contains('amex') || raw.contains('american')) return 'amex';
    if (raw.contains('discover')) return 'discover';
    return 'unknown';
  }

  void _notifyComplete() {
    widget.onCompleteChanged(
      _details?.complete == true && widget.nameController.text.trim().isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: widget.nameController,
          builder: (context, _) => CardPreview(
            holderName: widget.nameController.text,
            brand: _brand,
            numberComplete: _details?.complete == true,
            expiryComplete: _details?.complete == true,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BybitPalette.surface2,
            borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 6),
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
                    setState(() {
                      _details = card;
                      _brand = _mapBrand(card?.brand);
                    });
                    _notifyComplete();
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Card holder',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: BybitPalette.input,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: widget.nameController,
                  onChanged: (_) => _notifyComplete(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Name on card',
                    hintStyle: TextStyle(color: BybitPalette.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
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
        err.error.localizedMessage ?? err.error.message ?? 'Your card was declined.',
      );
    }
  }
}
