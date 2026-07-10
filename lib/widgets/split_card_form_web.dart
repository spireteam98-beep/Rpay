import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'package:stripe_js/stripe_api.dart' as js;
import 'package:stripe_js/stripe_js.dart' as js;
import 'package:web/web.dart' as web;

import 'bybit_wallet_ui.dart';
import 'card_confirm_result.dart';
import 'card_preview.dart';

/// Raw shape of a Stripe Element's `change` event — just the fields we need
/// to know whether the field is usable yet (and, for the card-number
/// element, which network it detected — never the digits themselves).
extension type _ChangeEvent(JSObject _) implements JSObject {
  external bool get complete;
  external JSAny? get error;
  external JSString? get brand;
}

/// [js.StripeElement.on] is typed against stripe_js's internal, unexported
/// `JSMap` event type, so it isn't callable from outside the package. This
/// talks to the same underlying JS `on` method directly with an untyped
/// handler instead.
extension _RawChangeListener on js.StripeElement {
  @JS('on')
  external void _onRaw(JSString event, JSFunction handler);

  void onChange(void Function(_ChangeEvent) handler) {
    _onRaw(
      'change'.toJS,
      ((JSAny? e) => handler(_ChangeEvent(e as JSObject))).toJS,
    );
  }
}

/// Three separate, PCI-compliant Stripe Elements (card number, expiry, CVC)
/// grouped into one card-shaped panel — with a live preview card above it —
/// instead of Stripe's single combined [CardField]. Raw card digits never
/// reach Dart — each Element is Stripe-hosted, same PCI SAQ-A posture as the
/// combined field, just laid out differently.
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
  late final js.StripeElements _elements;
  late final js.StripeElement _numberElement;
  late final js.StripeElement _expiryElement;
  late final js.StripeElement _cvcElement;

  late final web.HTMLDivElement _numberDiv;
  late final web.HTMLDivElement _expiryDiv;
  late final web.HTMLDivElement _cvcDiv;

  late final String _numberViewType;
  late final String _expiryViewType;
  late final String _cvcViewType;

  bool _numberComplete = false;
  bool _expiryComplete = false;
  bool _cvcComplete = false;
  String _brand = 'unknown';

  @override
  void initState() {
    super.initState();
    final id = identityHashCode(this);
    _numberViewType = 'stripe_card_number_$id';
    _expiryViewType = 'stripe_card_expiry_$id';
    _cvcViewType = 'stripe_card_cvc_$id';

    _numberDiv = _registerDiv(_numberViewType, 'split-card-number-$id');
    _expiryDiv = _registerDiv(_expiryViewType, 'split-card-expiry-$id');
    _cvcDiv = _registerDiv(_cvcViewType, 'split-card-cvc-$id');

    _elements = WebStripe.js.elements();
    _numberElement = _elements.create(
      'cardNumber',
      _options(placeholder: '1234 1234 1234 1234').jsify(),
    );
    _expiryElement = _elements.create('cardExpiry', _options().jsify());
    _cvcElement = _elements.create(
      'cardCvc',
      _options(placeholder: 'CVC').jsify(),
    );

    widget.nameController.addListener(_notifyComplete);
    _mountWhenConnected();
  }

  web.HTMLDivElement _registerDiv(String viewType, String id) {
    final div =
        web.HTMLDivElement()
          ..id = id
          ..style.border = 'none';
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) => div);
    return div;
  }

  Map<String, dynamic> _options({String? placeholder}) => {
    'style': {
      'base': {
        'color': _cssColor(Colors.white),
        'fontSize': '15px',
        '::placeholder': {'color': _cssColor(BybitPalette.muted)},
      },
      'invalid': {'color': _cssColor(BybitPalette.red)},
    },
    if (placeholder != null) 'placeholder': placeholder,
  };

  String _cssColor(Color color) {
    final argb = color.toARGB32();
    return 'rgba(${(argb >> 16) & 0xFF}, ${(argb >> 8) & 0xFF}, '
        '${argb & 0xFF}, ${((argb >> 24) & 0xFF) / 255})';
  }

  void _mountWhenConnected() {
    if (!mounted) return;
    if (_numberDiv.isConnected &&
        _expiryDiv.isConnected &&
        _cvcDiv.isConnected) {
      _numberElement
        ..mount(_numberDiv)
        ..onChange(_onNumberChange);
      _expiryElement
        ..mount(_expiryDiv)
        ..onChange((e) => _onChange(e, (v) => _expiryComplete = v));
      _cvcElement
        ..mount(_cvcDiv)
        ..onChange((e) => _onChange(e, (v) => _cvcComplete = v));
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mountWhenConnected(),
      );
    }
  }

  void _onNumberChange(_ChangeEvent event) {
    if (!mounted) return;
    setState(() {
      _numberComplete = event.complete;
      _brand = event.brand?.toDart ?? 'unknown';
    });
    _notifyComplete();
  }

  void _onChange(_ChangeEvent event, void Function(bool) setComplete) {
    if (!mounted) return;
    setState(() => setComplete(event.complete));
    _notifyComplete();
  }

  void _notifyComplete() {
    widget.onCompleteChanged(
      _numberComplete &&
          _expiryComplete &&
          _cvcComplete &&
          widget.nameController.text.trim().isNotEmpty,
    );
  }

  Future<CardConfirmResult> confirmCardPayment(String clientSecret) async {
    final response = await WebStripe.js.confirmCardPayment(
      clientSecret,
      data: js.ConfirmCardPaymentData(
        paymentMethod: js.CardPaymentMethodDetails(
          card: _numberElement,
          billingDetails: js.BillingDetails(
            name: widget.nameController.text.trim(),
          ),
        ),
      ),
    );
    if (response.paymentIntent?.status == js.PaymentIntentsStatus.succeeded) {
      return CardConfirmResult.success(response.paymentIntent?.id);
    }
    return CardConfirmResult.failure(
      response.error?.message ?? 'Your card was declined.',
    );
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_notifyComplete);
    _numberElement.unmount();
    _expiryElement.unmount();
    _cvcElement.unmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: widget.nameController,
          builder:
              (context, _) => CardPreview(
                holderName: widget.nameController.text,
                brand: _brand,
                numberComplete: _numberComplete,
                expiryComplete: _expiryComplete,
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
              _fieldLabel('Card number'),
              const SizedBox(height: 6),
              _fieldBox(height: 48, viewType: _numberViewType),
              const SizedBox(height: 16),
              _fieldLabel('Card holder'),
              const SizedBox(height: 6),
              _nameField(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Expiry (MM/YY)'),
                        const SizedBox(height: 6),
                        _fieldBox(height: 48, viewType: _expiryViewType),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('CVV'),
                        const SizedBox(height: 6),
                        _fieldBox(height: 48, viewType: _cvcViewType),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: BybitPalette.muted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _fieldBox({required double height, required String viewType}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: BybitPalette.input,
        borderRadius: BorderRadius.circular(14),
      ),
      child: HtmlElementView(viewType: viewType),
    );
  }

  Widget _nameField() {
    return Container(
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
    );
  }
}
