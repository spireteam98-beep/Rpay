import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import 'login_otp_screen.dart';

/// Returning users: email + a one-time code sent to that email (no password).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showMessage('Enter your email.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    setState(() => _sending = true);
    try {
      final sent = await ApiService.requestLoginOtp(email: email);
      if (!mounted) return;
      if (sent == true) {
        Navigator.of(context).push(kashRoute(LoginOtpScreen(email: email)));
        return;
      }
      if (sent == false) {
        _showMessage('Could not send a sign-in code. Try again.');
        return;
      }
      _showMessage(
        'Backend is not reachable. Start the Wayaki API and try again.',
      );
    } on ApiException catch (err) {
      _showMessage(err.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Log in'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your email and we'll send you a sign-in code.",
                style: TextStyle(color: BybitPalette.muted2, fontSize: 14),
              ),
              const SizedBox(height: 28),
              BybitTextField(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 24),
              BybitPrimaryButton(
                label: _sending ? 'Sending…' : 'Send code',
                enabled: !_sending,
                onTap: _handleSendCode,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
