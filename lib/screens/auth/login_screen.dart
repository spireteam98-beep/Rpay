import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/kash_widgets.dart';
import '../main_navigation.dart';

/// Returning users: phone + password (biometrics later).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Sandbox: demo credentials are pre-filled so login is one tap.
  final TextEditingController _phoneController =
      TextEditingController(text: AuthService.demoPhone);
  final TextEditingController _passwordController =
      TextEditingController(text: AuthService.demoPassword);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showMessage('Enter your phone number and password.');
      return;
    }

    // Sandbox convenience: demo credentials always work.
    if (phone == AuthService.demoPhone && password == AuthService.demoPassword) {
      await _handleDemoLogin();
      return;
    }

    // Real backend first (backend/ — Node + Postgres). Falls back to the
    // local sandbox automatically when the API isn't running.
    final backendResult =
        await ApiService.login(phone: phone, password: password);
    if (backendResult == true) {
      await AuthService.signInSavedUser();
      _enterApp();
      return;
    }
    if (backendResult == false) {
      _showMessage('Incorrect phone or password. Check your details and try again.');
      return;
    }

    final success = await AuthService.signIn(phoneNumber: phone, password: password);
    if (!success) {
      _showMessage('Incorrect phone or password. Check your details and try again.');
      return;
    }

    _enterApp();
  }

  Future<void> _handleDemoLogin() async {
    _phoneController.text = AuthService.demoPhone;
    _passwordController.text = AuthService.demoPassword;
    await AuthService.signInDemo();
    _enterApp();
  }

  void _enterApp() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      kashRoute(const MainNavigation()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Log in'),
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
                  color: AppTheme.textWhite,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your money is where you left it.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),
              KashTextField(
                label: 'Phone number',
                hint: '+252 61 000 0000',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                controller: _phoneController,
              ),
              const SizedBox(height: 18),
              KashTextField(
                label: 'Password',
                hint: 'Your password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Log in',
                onTap: _handleLogin,
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Use demo account',
                outlined: true,
                onTap: _handleDemoLogin,
              ),
              const SizedBox(height: 18),
              GlassTile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sandbox credentials',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${AuthService.demoPhone}\nPassword: ${AuthService.demoPassword}',
                      style: const TextStyle(
                        color: AppTheme.textLightGrey,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
