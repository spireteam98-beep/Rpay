import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Lets an agent set the live KES-per-USD rate they're offering in the
/// M-Pesa/Till FX marketplace (see routes/agents.js PUT /fx-offer). This
/// rate is the agent's entire margin — no separate fee is charged to the
/// customer, so it's deliberately shown next to Wayaki's reference rate to
/// make the spread/margin visible while setting it.
class AgentFxRateScreen extends StatefulWidget {
  const AgentFxRateScreen({super.key});

  @override
  State<AgentFxRateScreen> createState() => _AgentFxRateScreenState();
}

class _AgentFxRateScreenState extends State<AgentFxRateScreen> {
  bool _loading = true;
  bool _saving = false;
  final _rateController = TextEditingController();
  final _minController = TextEditingController(text: '1');
  final _maxController = TextEditingController(text: '50');
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final offer = await ApiService.myFxOffer();
    if (!mounted) return;
    setState(() {
      if (offer != null) {
        _rateController.text = offer['rate_kes_per_usd'].toString();
        _minController.text = offer['min_usd'].toString();
        _maxController.text = offer['max_usd'].toString();
        _active = offer['active'] == true;
      }
      _loading = false;
    });
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
        rateKesPerUsd: rate,
        minUsd: min,
        maxUsd: max,
        active: _active,
      );
      if (!mounted) return;
      BybitToast.success(context, 'Rate saved');
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Your M-Pesa/Till rate'),
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
                        'Set your live rate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Customers see this in the marketplace and pick the best rate. Your margin is whatever you set below Wayaki\'s reference rate — there\'s no separate fee.',
                        style: TextStyle(
                          color: BybitPalette.muted2,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      BybitTextField(
                        label: 'Your rate (KES per USD)',
                        hint: 'e.g. 127',
                        icon: Icons.currency_exchange_rounded,
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      TouchScale(
                        onTap: () => setState(() => _active = !_active),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: BybitPalette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF242832)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Listed in marketplace',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _active
                                          ? 'Customers can see and pick your rate'
                                          : 'Hidden — you won\'t get new requests',
                                      style: const TextStyle(
                                        color: BybitPalette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 44,
                                height: 26,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: _active ? BybitPalette.accent : BybitPalette.surface2,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Align(
                                  alignment: _active ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    width: 20,
                                    height: 20,
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
                      const SizedBox(height: 24),
                      BybitPrimaryButton(
                        label: _saving ? 'Saving...' : 'Save rate',
                        enabled: !_saving,
                        onTap: _save,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
