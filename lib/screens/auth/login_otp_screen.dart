import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../main_navigation.dart';
import 'otp_screen.dart';

/// Enter the sign-in code emailed by [LoginScreen] to finish logging in.
class LoginOtpScreen extends StatefulWidget {
  final String email;

  const LoginOtpScreen({super.key, required this.email});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  static const _resendCooldownSeconds = 60;

  final List<String> _digits = List.filled(6, '');
  int _filled = 0;
  bool _verifying = false;
  bool _resending = false;
  int _cooldown = _resendCooldownSeconds;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      final signedIn = await ApiService.verifyLoginOtp(
        email: widget.email,
        code: _digits.join(),
      );
      if (!mounted) return;
      if (signedIn == true) {
        await AuthService.signInBackendUser(email: widget.email);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          kashRoute(const MainNavigation()),
          (route) => false,
        );
        return;
      }
      setState(() => _verifying = false);
      _showMessage('Backend is not reachable. Start the RoyallPay API and try again.');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _showMessage(err.message);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final sent = await ApiService.requestLoginOtp(email: widget.email);
      if (!mounted) return;
      if (sent == true) {
        _showMessage('New code sent to ${widget.email}.');
        _startCooldown();
      } else {
        _showMessage('Could not resend the code. Try again.');
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      _showMessage(err.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _resendLabel {
    if (_resending) return 'Sending…';
    if (_cooldown > 0) {
      final m = _cooldown ~/ 60;
      final s = (_cooldown % 60).toString().padLeft(2, '0');
      return 'Resend code ($m:$s)';
    }
    return 'Resend code';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Enter code'),
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
                'We sent a code to ${widget.email}',
                style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
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
                        color: active ? BybitPalette.accent : const Color(0xFF242832),
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
                  onPressed: (_resending || _cooldown > 0) ? null : _resend,
                  child: Text(
                    _resendLabel,
                    style: const TextStyle(color: BybitPalette.accent),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _keypad(),
              const SizedBox(height: 12),
              BybitPrimaryButton(
                label: _verifying ? 'Verifying…' : 'Log in',
                enabled: _filled == 6 && !_verifying,
                onTap: _filled == 6 ? _verify : () {},
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
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox.shrink();
        return TouchScaleKey(label: k, onTap: () => _tapKey(k));
      }).toList(),
    );
  }
}
