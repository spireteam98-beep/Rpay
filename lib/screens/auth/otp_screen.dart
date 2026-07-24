import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
import 'kyc_screen.dart';

/// Step 3: verify the phone with a 6-digit code.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<String> _digits = List.filled(6, '');
  int _filled = 0;
  int _resendSeconds = 42;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 42);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _resendCode() {
    if (_resendSeconds > 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code resent')),
    );
    _startResendTimer();
  }

  void _tapKey(String v) {
    setState(() {
      if (v == '<') {
        if (_filled > 0) {
          _filled--;
          _digits[_filled] = '';
        }
      } else if (_filled < 6) {
        _digits[_filled] = v;
        _filled++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = context.watch<KashAppState>().phoneNumber;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Verify phone'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-digit code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent an SMS to $phoneNumber',
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final active = i == _filled;
                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BybitPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            active
                                ? BybitPalette.accent
                                : const Color(0xFF242832),
                        width: active ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      _digits[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _resendSeconds > 0 ? null : _resendCode,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend code (0:${_resendSeconds.toString().padLeft(2, '0')})'
                        : 'Resend code',
                    style: TextStyle(
                      color:
                          _resendSeconds > 0
                              ? BybitPalette.muted2
                              : BybitPalette.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _keypad(),
              const SizedBox(height: 12),
              BybitPrimaryButton(
                label: 'Verify',
                enabled: _filled == 6,
                onTap:
                    _filled == 6
                        ? () async {
                          // Real backend verification when a session exists.
                          await ApiService.verifyPhone(_digits.join());

                          final signedIn = await AuthService.signInSavedUser();
                          if (!signedIn) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to sign in. Please try again.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (!mounted) return;
                          context.read<KashAppState>().verifyPhone();
                          Navigator.of(
                            context,
                          ).push(kashRoute(const KycScreen()));
                        }
                        : () {},
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      children:
          keys.map((k) {
            if (k.isEmpty) return const SizedBox.shrink();
            return TouchScaleKey(label: k, onTap: () => _tapKey(k));
          }).toList(),
    );
  }
}

class TouchScaleKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const TouchScaleKey({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      hoverScale: 1.0,
      pressedScale: 0.85,
      child: Center(
        child:
            label == '<'
                ? const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white,
                  size: 22,
                )
                : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
      ),
    );
  }
}
