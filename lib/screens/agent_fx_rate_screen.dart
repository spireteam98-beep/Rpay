import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Lets an agent set the live KES-per-USD rate they're offering for each
/// FX-marketplace direction they've been granted (see routes/agents.js PUT
/// /fx-offer and the can_provide_kes/usd capability flags). Each direction
/// is its own margin — no separate fee is charged to the customer, so the
/// rate is deliberately shown next to Wayaki's reference rate to make the
/// spread visible while setting it.
class AgentFxRateScreen extends StatefulWidget {
  const AgentFxRateScreen({super.key});

  @override
  State<AgentFxRateScreen> createState() => _AgentFxRateScreenState();
}

class _AgentFxRateScreenState extends State<AgentFxRateScreen> {
  bool _loading = true;
  Map<String, dynamic>? _agent;
  Map<String, dynamic>? _offers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([ApiService.myAgent(), ApiService.myFxOffer()]);
    if (!mounted) return;
    setState(() {
      _agent = results[0];
      _offers = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canProvideKes = _agent?['can_provide_kes'] == true;
    final canProvideUsd = _agent?['can_provide_usd'] == true;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Your FX rates'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set your live rates',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Customers browse these rates and pick the best one. Your margin is whatever spread you set below Wayaki\'s reference rate — there\'s no separate fee.',
                        style: TextStyle(
                          color: BybitPalette.muted2,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _DirectionCard(
                        title: 'Provide KES',
                        description: 'Customers pay you USD, you send real M-Pesa/Till KES.',
                        direction: 'AGENT_PROVIDES_KES',
                        enabled: canProvideKes,
                        offer: _offers?['AGENT_PROVIDES_KES'] as Map<String, dynamic>?,
                        onSaved: _load,
                      ),
                      const SizedBox(height: 16),
                      _DirectionCard(
                        title: 'Provide USD',
                        description: 'Customers pay you real KES, you top up their USD wallet.',
                        direction: 'AGENT_PROVIDES_USD',
                        enabled: canProvideUsd,
                        offer: _offers?['AGENT_PROVIDES_USD'] as Map<String, dynamic>?,
                        onSaved: _load,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _DirectionCard extends StatefulWidget {
  final String title;
  final String description;
  final String direction;
  final bool enabled;
  final Map<String, dynamic>? offer;
  final VoidCallback onSaved;

  const _DirectionCard({
    required this.title,
    required this.description,
    required this.direction,
    required this.enabled,
    required this.offer,
    required this.onSaved,
  });

  @override
  State<_DirectionCard> createState() => _DirectionCardState();
}

class _DirectionCardState extends State<_DirectionCard> {
  late final _rateController = TextEditingController(
    text: widget.offer?['rate_kes_per_usd']?.toString() ?? '',
  );
  late final _minController = TextEditingController(
    text: widget.offer?['min_usd']?.toString() ?? '1',
  );
  late final _maxController = TextEditingController(
    text: widget.offer?['max_usd']?.toString() ?? '50',
  );
  late bool _active = widget.offer?['active'] != false;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateController.text.trim());
    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());
    if (rate == null || rate <= 0) {
      BybitToast.error(context, 'Enter a positive rate');
      return;
    }
    if (min == null || max == null || min <= 0 || max < min) {
      BybitToast.error(context, 'Min/max must be positive with max ≥ min');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.setFxOffer(
        direction: widget.direction,
        rateKesPerUsd: rate,
        minUsd: min,
        maxUsd: max,
        active: _active,
      );
      if (!mounted) return;
      BybitToast.success(context, '${widget.title} rate saved');
      widget.onSaved();
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF242832)),
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
              child: const Icon(Icons.lock_outline_rounded, color: BybitPalette.muted, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Not enabled on your account — ask Wayaki admin to grant this product.',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.description,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 16),
          BybitTextField(
            label: 'Rate (KES per USD)',
            hint: 'e.g. 127',
            icon: Icons.currency_exchange_rounded,
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BybitTextField(
                  label: 'Min USD',
                  hint: '1',
                  icon: Icons.south_rounded,
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BybitTextField(
                  label: 'Max USD',
                  hint: '50',
                  icon: Icons.north_rounded,
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TouchScale(
            onTap: () => setState(() => _active = !_active),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _active
                          ? 'Listed in marketplace'
                          : 'Hidden — you won\'t get new requests',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 24,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _active ? BybitPalette.accent : BybitPalette.surface,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Align(
                      alignment: _active ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _active ? Colors.black : BybitPalette.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          BybitPrimaryButton(
            label: _saving ? 'Saving...' : 'Save',
            enabled: !_saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
