import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/pin_keypad.dart';
import '../../widgets/touch_scale.dart';
import 'auth_ui.dart';
import '../../widgets/brand_logo.dart';

/// Shown on app launch when biometric unlock is on. Prompts Face ID /
/// fingerprint straight away; the 4-digit PIN (checked by the backend)
/// is always available as a fallback.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  static const _pinLength = 4;
  BiometricSupport _support = BiometricSupport.none;
  String _entry = '';
  bool _checking = false;
  int _failures = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometrics());
  }

  Future<void> _initBiometrics() async {
    final s = await BiometricService.check();
    if (!mounted) return;
    setState(() => _support = s);
    if (s.available) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.authenticate('Unlock Fareenn');
    if (ok) _unlock();
  }

  void _unlock() {
    AuthService.unlockedThisSession = true;
    if (!mounted) return;
    GoRouter.of(context).go('/home');
  }

  void _tapKey(String v) {
    if (_checking || _entry.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _entry += v;
    });
    if (_entry.length == _pinLength) _checkPin(_entry);
  }

  void _backspace() {
    if (_checking || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _checkPin(String pin) async {
    setState(() => _checking = true);
    bool ok;
    try {
      ok = await ApiService.verifyPin(pin);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _entry = '';
        _error = "Can't check your PIN offline. Check your connection.";
      });
      return;
    }
    if (!mounted) return;
    if (ok) {
      _unlock();
      return;
    }
    HapticFeedback.heavyImpact();
    _failures++;
    setState(() {
      _checking = false;
      _entry = '';
      _error =
          _failures >= 5
              ? 'Too many wrong attempts. Sign in with Google again.'
              : 'Wrong PIN. Try again.';
    });
    if (_failures >= 5) await _signOut();
  }

  Future<void> _signOut() async {
    await ApiService.logout();
    await ApiService.clearSession();
    await AuthService.signOut();
    if (!mounted) return;
    GoRouter.of(context).go('/');
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<KashAppState>().firstName;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const FareennLogo(height: 46),
              const SizedBox(height: 26),
              Text(
                name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your PIN to unlock',
                style: TextStyle(color: BybitPalette.muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pinLength; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 11),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            i < _entry.length
                                ? BybitPalette.accent
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              i < _entry.length
                                  ? BybitPalette.accent
                                  : BybitPalette.muted,
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 64,
                child: Center(
                  child:
                      _error != null
                          ? AuthErrorBanner(_error!)
                          : _checking
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: BybitPalette.accent,
                            ),
                          )
                          : null,
                ),
              ),
              const Spacer(),
              NumericKeypad(onDigit: _tapKey, onBackspace: _backspace),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TouchScale(
                    onTap: _signOut,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_support.available)
                    TouchScale(
                      onTap: _tryBiometric,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _support.face && !_support.fingerprint
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.fingerprint_rounded,
                              color: BybitPalette.accentIcon,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Use ${BiometricService.label(_support)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
