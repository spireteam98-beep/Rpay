import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

enum _Step { idle, writing, verifying, linking }

/// The customer's physical Fareenn tap cards: link a new card by tapping it
/// on the phone (the app writes the card's secure link and checks it),
/// then freeze, unfreeze or block cards.
class PhysicalCardScreen extends StatefulWidget {
  const PhysicalCardScreen({super.key});

  @override
  State<PhysicalCardScreen> createState() => _PhysicalCardScreenState();
}

class _PhysicalCardScreenState extends State<PhysicalCardScreen> {
  List<Map<String, dynamic>>? _cards;
  String? _error;
  _Step _step = _Step.idle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    NfcService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cards = await ApiService.nfcMyCards();
      if (mounted) setState(() => _cards = cards);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _link() async {
    if (!NfcService.supported) {
      _toast('Open fareenn.com in Chrome on an Android phone with NFC turned on to link a card.');
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.writing;
    });
    try {
      final prep = await ApiService.nfcPrepare();
      final token = prep['token'] as String, url = prep['url'] as String;
      await NfcService.writeUrl(url);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _step = _Step.verifying);
      final tap = await NfcService.read();
      if (tap.token != token) {
        throw const NfcException('That was a different card, or the card was not saved. Try again with the same card.');
      }
      if (!mounted) return;
      final pin = await _askPin();
      if (pin == null) {
        setState(() => _step = _Step.idle);
        return;
      }
      setState(() => _step = _Step.linking);
      await ApiService.nfcLink(uid: tap.uid, token: token, pin: pin);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _step = _Step.idle);
      _toast('Card •••• ${tap.last4} is linked and ready to use.');
      _load();
    } on NfcException catch (e) {
      if (mounted) setState(() { _step = _Step.idle; _error = e.message; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _step = _Step.idle; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _step = _Step.idle; _error = 'Something went wrong. Please try again.'; });
    }
  }

  void _cancel() {
    NfcService.stop();
    setState(() => _step = _Step.idle);
  }

  Future<String?> _askPin({String action = 'Link card'}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BybitPalette.surface,
        title: const Text('Confirm with your PIN', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', hintText: '••••', hintStyle: TextStyle(color: BybitPalette.muted)),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: BybitPalette.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(action, style: const TextStyle(color: BybitPalette.accent))),
        ],
      ),
    );
  }

  Future<void> _setFrozen(Map<String, dynamic> card, bool frozen) async {
    try {
      await ApiService.nfcFreeze(card['id'] as String, frozen);
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _block(Map<String, dynamic> card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BybitPalette.surface,
        title: const Text('Block this card?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Card •••• ${card['last4']} will stop working permanently. Use this if the card is lost or stolen.',
          style: const TextStyle(color: BybitPalette.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: BybitPalette.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Block card', style: TextStyle(color: BybitPalette.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.nfcBlock(card['id'] as String);
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Fareenn tap card'),
      body: _step == _Step.idle ? _list() : _tapView(),
    );
  }

  Widget _list() {
    final cards = _cards;
    return RefreshIndicator(
      color: BybitPalette.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Pay at Fareenn merchants by tapping your card on their phone and entering your PIN. '
            'Payments come from your wallet balance.',
            style: TextStyle(color: BybitPalette.muted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x1FFF4D57), borderRadius: BorderRadius.circular(14)),
              child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
            ),
            const SizedBox(height: 14),
          ],
          if (cards == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: BybitPalette.accent)),
            )
          else
            for (final c in cards) ...[_cardRow(c), const SizedBox(height: 10)],
          const SizedBox(height: 10),
          BybitPrimaryButton(label: 'Link a new card', onTap: _link),
        ],
      ),
    );
  }

  /// Card details sheet: the card face, with the full number, expiry and
  /// CVC revealed after the PIN.
  Future<void> _details(Map<String, dynamic> c) async {
    Map<String, dynamic>? shown;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final number = shown?['number'] as String? ?? (c['maskedNumber'] as String? ?? '•••• •••• •••• ${c['last4']}');
          final expiry = shown?['expiry'] as String? ?? (c['expiry'] as String? ?? '••/••');
          final cvc = shown?['cvc'] as String? ?? '•••';
          TextStyle mono(double s) => TextStyle(color: Colors.white, fontSize: s, fontWeight: FontWeight.w700, letterSpacing: 1.6, fontFamily: 'monospace');
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.586,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE60000), Color(0xFFB30000)]),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/images/fareenn_wordmark_plain.png', height: 24),
                            const Spacer(),
                            const Icon(Icons.contactless_outlined, color: Colors.white, size: 28),
                          ],
                        ),
                        const Spacer(),
                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(number, style: mono(21))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('VALID THRU', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                              Text(expiry, style: mono(15)),
                            ]),
                            const SizedBox(width: 28),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('CVC', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                              Text(cvc, style: mono(15)),
                            ]),
                            const Spacer(),
                            Text((shown?['name'] as String?) ?? '', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (shown == null)
                  BybitPrimaryButton(
                    label: 'Show card details',
                    onTap: () async {
                      final pin = await _askPin(action: 'Show details');
                      if (pin == null) return;
                      try {
                        final d = await ApiService.nfcReveal(c['id'] as String, pin);
                        setSheet(() => shown = d);
                      } on ApiException catch (e) {
                        _toast(e.message);
                      }
                    },
                  )
                else
                  BybitPrimaryButton(
                    label: 'Copy card number',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: (shown!['number'] as String).replaceAll(' ', '')));
                      _toast('Card number copied');
                    },
                  ),
                const SizedBox(height: 10),
                const Text(
                  'This card works on the Fareenn network: tap at Fareenn businesses and pay from your wallet balance. Never share your PIN or CVC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BybitPalette.muted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardRow(Map<String, dynamic> c) {
    final status = c['status'] as String? ?? 'ACTIVE';
    final (Color color, String label) = switch (status) {
      'ACTIVE' => (BybitPalette.green, 'Active'),
      'FROZEN' => (BybitPalette.credit, 'Frozen'),
      _ => (BybitPalette.red, 'Blocked'),
    };
    return TouchScale(
      onTap: () => _details(c),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFE60000), Color(0xFFB30000)]),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.contactless_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['maskedNumber'] as String? ?? '${c['label'] ?? 'Fareenn card'} •••• ${c['last4']}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Exp ${c['expiry'] ?? '--/--'} · limit \$${(c['perTxLimitUsd'] as num).toStringAsFixed(0)} a payment, \$${(c['dailyLimitUsd'] as num).toStringAsFixed(0)} a day',
                  style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withAlpha(36), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          if (status != 'BLOCKED')
            PopupMenuButton<String>(
              color: BybitPalette.surface,
              icon: const Icon(Icons.more_vert_rounded, color: BybitPalette.muted),
              onSelected: (v) => v == 'block' ? _block(c) : _setFrozen(c, v == 'freeze'),
              itemBuilder: (_) => [
                if (status == 'ACTIVE')
                  const PopupMenuItem(value: 'freeze', child: Text('Freeze card', style: TextStyle(color: Colors.white)))
                else
                  const PopupMenuItem(value: 'unfreeze', child: Text('Unfreeze card', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'block', child: Text('Block (lost or stolen)', style: TextStyle(color: BybitPalette.red))),
              ],
            ),
        ],
      ),
      ),
    );
  }

  Widget _tapView() {
    final (title, sub) = switch (_step) {
      _Step.writing => ('Hold your card on the phone', 'Place a blank Fareenn card flat on the back of the phone and keep it still.'),
      _Step.verifying => ('Tap the card again', 'Lift the card away, then tap it once more to confirm it was saved.'),
      _ => ('Linking your card…', 'Almost done.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      child: Column(
        children: [
          const Spacer(),
          const _TapPulse(),
          const SizedBox(height: 36),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: BybitPalette.muted, fontSize: 15, height: 1.4)),
          const Spacer(),
          if (_step != _Step.linking)
            TouchScale(
              onTap: _cancel,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card icon with expanding contactless rings.
class _TapPulse extends StatefulWidget {
  const _TapPulse();

  @override
  State<_TapPulse> createState() => _TapPulseState();
}

class _TapPulseState extends State<_TapPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 220,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(builder: (_) {
                final t = (_c.value + i / 3) % 1;
                return Container(
                  width: 110 + 110 * t,
                  height: 110 + 110 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: BybitPalette.accent.withAlpha((180 * (1 - t)).round()), width: 2),
                  ),
                );
              }),
            Container(
              width: 120,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFFE60000), Color(0xFFB30000)]),
                boxShadow: const [BoxShadow(color: Color(0x66E60000), blurRadius: 24)],
              ),
              child: const Icon(Icons.contactless_outlined, color: Colors.white, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}
