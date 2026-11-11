import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/biometric_service.dart';
import '../../state/kash_app_state.dart';
import 'auth_flow.dart';
import 'onboarding_ui.dart';

/// Final step: turn on Face ID and/or fingerprint login. Only shown when the
/// device actually has a biometric sensor enrolled. Enabling runs a real
/// biometric check first, so it can't be switched on by someone who isn't
/// the device owner.
class BiometricSetupScreen extends StatefulWidget {
  final OnboardingData data;
  final BiometricSupport support;

  const BiometricSetupScreen({super.key, required this.data, required this.support});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String? _error;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await BiometricService.authenticate(
      'Confirm it’s you to turn on ${BiometricService.label(widget.support)}',
    );
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = 'Biometric verification failed. Try again, or enable it later in Security settings.';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    context.read<KashAppState>().setBiometricEnabled(true);
    await AuthFlow.finish(context, widget.data);
  }

  Future<void> _skip() async {
    if (_busy) return;
    context.read<KashAppState>().setBiometricEnabled(false);
    await AuthFlow.finish(context, widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.support;
    final label = BiometricService.label(s);
    final faceOnly = s.face && !s.fingerprint;
    return FzStepScaffold(
      step: 12,
      chapter: 'SECURITY',
      eyebrow: 'ACCOUNT SECURITY',
      title: 'Biometric login',
      subtitle: 'Use $label to sign in and authorise payments. Your PIN remains available.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FzTextButton('Not now', onTap: _busy ? null : _skip),
          const SizedBox(height: 6),
          FzNavBar(
            onBack: () => Navigator.of(context).maybePop(),
            onNext: _enable,
            nextLabel: 'Turn on $label',
            busy: _busy,
          ),
        ],
      ),
      child: Column(
        children: [
          if (_error != null) ...[FzError(_error!), const SizedBox(height: 20)],
          const SizedBox(height: 16),
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final v = _pulse.value;
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(54),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x4DFF2D2D), Color(0x0DE60000)],
                    ),
                    border: Border.all(color: Fz.hot, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Fz.red.withValues(alpha: 0.5 * (1 - v)),
                        spreadRadius: 18 * v,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Icon(
                faceOnly ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded,
                color: Colors.white,
                size: 76,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
