import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../main_navigation.dart';
import 'login_otp_screen.dart';

/// Returning users: email + password (primary), with a one-time email code
/// kept as an alternative — accounts created before password signup existed
/// have no password set, so the code path also covers them.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validEmail(String email) {
    if (email.isEmpty) {
      _showMessage('Enter your email.');
      return false;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return false;
    }
    return true;
  }

  Future<void> _handlePasswordLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (!_validEmail(email)) return;
    if (password.isEmpty) {
      _showMessage('Enter your password.');
      return;
    }

    setState(() => _sending = true);
    try {
      final signedIn = await ApiService.login(email: email, password: password);
      if (!mounted) return;
      if (signedIn == true) {
        await AuthService.signInBackendUser(email: email);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          kashRoute(const MainNavigation()),
          (route) => false,
        );
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

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!_validEmail(email)) return;

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
                'Enter your email and password to log in.',
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
              const SizedBox(height: 18),
              BybitTextField(
                label: 'Password',
                hint: 'Your password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 24),
              BybitPrimaryButton(
                label: _sending ? 'Please wait…' : 'Log in',
                enabled: !_sending,
                onTap: _handlePasswordLogin,
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _sending ? null : _handleSendCode,
                  child: const Text(
                    'Log in with a one-time code instead',
                    style: TextStyle(color: BybitPalette.accent),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
