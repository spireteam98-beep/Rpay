import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/code_boxes_input.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/pin_keypad.dart';
import 'pin_setup_screen.dart';

/// Confirms the email address collected at signup with a 4-digit code
/// (sent via Resend). The code can be typed on the on-screen keypad or
/// pasted in one action; either way, verification fires automatically the
/// moment the 4th digit lands — no separate tap needed.
class EmailVerifyScreen extends StatefulWidget {
  final String email;

  const EmailVerifyScreen({super.key, required this.email});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  static const _codeLength = 4;
  static const _resendCooldownSeconds = 60;

  final TextEditingController _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _cooldown = _resendCooldownSeconds;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() => setState(() {});

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
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
    if (_codeController.text.length >= _codeLength) return;
    _codeController.text += v;
  }

  void _backspace() {
    final text = _codeController.text;
    if (text.isEmpty) return;
    _codeController.text = text.substring(0, text.length - 1);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify([String? code]) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      final verified = await ApiService.verifyEmail(
        code ?? _codeController.text,
      );
      if (!mounted) return;
      if (!verified) {
        setState(() => _verifying = false);
        _codeController.clear();
        _showMessage('Incorrect code. Try again.');
        return;
      }
      Navigator.of(
        context,
      ).push(kashRoute(PinSetupScreen(email: widget.email)));
    } on ApiException catch (err) {
      if (!mounted) return;
      _codeController.clear();
      _showMessage(err.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ApiService.requestEmailOtp();
      if (!mounted) return;
      _showMessage('New code sent to ${widget.email}.');
      _startCooldown();
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
      appBar: const BybitSubHeader('Verify email'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Enter the 4-digit code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent a code to ${widget.email}. Paste it or type it in.',
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CodeBoxesInput(
                  controller: _codeController,
                  length: _codeLength,
                  onCompleted: _verify,
                ),
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
              NumericKeypad(onDigit: _tapKey, onBackspace: _backspace),
              const SizedBox(height: 12),
              BybitPrimaryButton(
                label: _verifying ? 'Verifying…' : 'Verify',
                enabled: _codeController.text.length == _codeLength && !_verifying,
                onTap: () => _verify(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
