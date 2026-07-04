import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/kash_widgets.dart';
import 'otp_screen.dart';

/// Step 2: create the account (phone-first, Somalia default).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleContinue() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showMessage('Fill in name, email, phone number, and password.');
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters.');
      return;
    }

    // Register on the real backend when it's running — this provisions
    // the user's on-chain custody wallet at signup. Falls back to the
    // local sandbox when the API is offline.
    String? ethAddress;
    try {
      ethAddress = await ApiService.signup(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
    } on ApiException catch (err) {
      _showMessage(err.message);
      return;
    }

    await AuthService.registerUser(
      fullName: fullName,
      email: email,
      phoneNumber: phone,
      password: password,
    );

    if (!mounted) return;
    context.read<KashAppState>().completeSignup(
          fullName: fullName,
          phoneNumber: phone,
        );

    if (ethAddress != null) {
      _showMessage('Custody wallet created: '
          '${ethAddress.substring(0, 10)}…');
    }

    Navigator.of(context).push(kashRoute(const OtpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Create account'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join RoyalPay',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One signup gives you a crypto wallet, a mobile money wallet and a bank account.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),
              KashTextField(
                label: 'Full name',
                hint: 'Mohamed Ali',
                icon: Icons.person_outline_rounded,
                controller: _nameController,
              ),
              const SizedBox(height: 18),
              KashTextField(
                label: 'Phone number',
                hint: '+252 61 000 0000',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                controller: _phoneController,
              ),
              const SizedBox(height: 18),
              KashTextField(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 18),
              KashTextField(
                label: 'Password',
                hint: 'At least 8 characters',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Continue',
                onTap: _handleContinue,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy.',
                  style: TextStyle(
                    color: AppTheme.textGrey.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
