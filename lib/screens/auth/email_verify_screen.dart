import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import 'wallet_id_setup_screen.dart';

/// Confirms the email address collected at signup with a 4-digit code
/// (sent via Resend). Entered into a plain text field — using the device's
/// own keyboard instead of a custom on-screen dial pad makes typing or
/// pasting the code feel like every other text input in the app; either
/// way, verification fires automatically the moment the 4th digit lands —
/// no separate tap needed.
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

  void _onCodeChanged() {
    setState(() {});
    if (_codeController.text.length == _codeLength && !_verifying) {
      _verify();
    }
  }

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
      ).push(kashRoute(WalletIdSetupScreen(email: widget.email)));
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
                'Check your email — we sent a code to ${widget.email}.',
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '0000',
                  hintStyle: const TextStyle(
                    color: BybitPalette.muted,
                    letterSpacing: 12,
                  ),
                  filled: true,
                  fillColor: BybitPalette.input,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: BybitPalette.accent,
                      width: 1.4,
                    ),
                  ),
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
