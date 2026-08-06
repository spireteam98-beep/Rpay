import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/kash_widgets.dart';
import '../../constants/app_theme.dart';
import '../../widgets/ui/wayaki_glow_button.dart';
import '../../widgets/ui/wayaki_glass_input.dart';
import '../../widgets/ui/wayaki_glass_card.dart';
import '../../widgets/ui/wayaki_background_glow.dart';
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
        context.go('/home');
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: WayakiBackgroundGlow(
        child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Space Grotesk',
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Enter your email and password to log in.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              WayakiGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email Address', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    WayakiGlassInput(
                      hintText: 'you@example.com',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 20),
                    const Text('Password', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    WayakiGlassInput(
                      hintText: 'Your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 32),
                    WayakiGlowButton(
                      label: _sending ? 'Please wait…' : 'Log in',
                      isLoading: _sending,
                      onPressed: _sending ? null : _handlePasswordLogin,
                      isPrimary: true,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _sending ? null : _handleSendCode,
                  child: const Text(
                    'Log in with a one-time code instead',
                    style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
