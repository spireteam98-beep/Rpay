import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
import 'email_verify_screen.dart';
import 'login_screen.dart';

enum _SignupStep { name, email, phone, password }

/// Step 2: create the account — one question per screen (name, then email,
/// then phone, then password), inspired by Revolut's onboarding: a single
/// large heading and one field at a time keeps each screen trivially fast
/// to fill in, instead of the old wall-of-fields wizard. Password is the
/// primary sign-in credential (still required — Apple App Review rejected
/// OTP-only auth); the email address collected here is confirmed next via
/// [EmailVerifyScreen].
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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _acceptedLegal = false;
  _SignupStep _step = _SignupStep.name;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _stepBack() {
    switch (_step) {
      case _SignupStep.email:
        setState(() => _step = _SignupStep.name);
        return;
      case _SignupStep.phone:
        setState(() => _step = _SignupStep.email);
        return;
      case _SignupStep.password:
        setState(() => _step = _SignupStep.phone);
        return;
      case _SignupStep.name:
        Navigator.of(context).maybePop();
        return;
    }
  }

  void _continueFromName() {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Enter your full name.');
      return;
    }
    setState(() => _step = _SignupStep.email);
  }

  void _continueFromEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }
    setState(() => _step = _SignupStep.phone);
  }

  void _continueFromPhone() {
    if (_phoneController.text.trim().isEmpty) {
      _showMessage('Enter your phone number.');
      return;
    }
    setState(() => _step = _SignupStep.password);
  }

  Future<void> _handleSubmit() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }
    if (!_acceptedLegal) {
      _showMessage('Accept the Terms of Service and Privacy Policy.');
      return;
    }

    setState(() => _submitting = true);

    // Register on the real backend — this provisions the user's on-chain
    // custody wallet at signup and sends the email code.
    String? ethAddress;
    try {
      ethAddress = await ApiService.signup(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
    } on ApiException catch (err) {
      setState(() => _submitting = false);
      _showMessage(err.message);
      return;
    }
    if (ethAddress == null) {
      setState(() => _submitting = false);
      _showMessage(
        'Backend is not reachable. Start the Wayaki API and try again.',
      );
      return;
    }

    await AuthService.registerUser(
      fullName: fullName,
      email: email,
      phoneNumber: phone,
    );

    if (!mounted) return;
    context.read<KashAppState>().completeSignup(
      fullName: fullName,
      phoneNumber: phone,
      email: email,
    );

    setState(() => _submitting = false);
    Navigator.of(context).push(kashRoute(EmailVerifyScreen(email: email)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: BybitSubHeader('Create account', onBack: _stepBack),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepDots(),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                child: switch (_step) {
                  _SignupStep.name => _nameStep(),
                  _SignupStep.email => _emailStep(),
                  _SignupStep.phone => _phoneStep(),
                  _SignupStep.password => _passwordStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepDots() {
    final steps = _SignupStep.values;
    return Row(
      children:
          steps.map((step) {
            final active = steps.indexOf(step) <= steps.indexOf(_step);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: step == _step ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? BybitPalette.accent : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
    );
  }

  /// Big single-question heading + subtitle, matching the one-field-per-page
  /// pattern (each step asks exactly one thing, in large friendly type).
  Widget _questionHeading(String question, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return Column(
      key: const ValueKey('name'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeading(
          "What's your name?",
          'This is how you\'ll appear to other Wayaki users.',
        ),
        BybitTextField(
          label: 'Full name',
          hint: 'Mohamed Ali',
          icon: Icons.person_outline_rounded,
          controller: _nameController,
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(label: 'Continue', onTap: _continueFromName),
        const SizedBox(height: 14),
        // Opened inside Telegram, this is the app's very first screen — no
        // welcome screen behind it to fall back on — so a returning user
        // needs a way to Login from right here, not just from Welcome.
        Center(
          child: TouchScale(
            onTap:
                () => Navigator.of(context).push(kashRoute(const LoginScreen())),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: BybitPalette.muted2),
                children: [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: TextStyle(
                      color: BybitPalette.accent,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeading(
          "What's your email?",
          'We\'ll send a short code to confirm it.',
        ),
        BybitTextField(
          label: 'Email address',
          hint: 'you@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(label: 'Continue', onTap: _continueFromEmail),
      ],
    );
  }

  Widget _phoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeading(
          "What's your phone number?",
          'Used for M-Pesa transfers and account recovery.',
        ),
        BybitTextField(
          label: 'Phone number',
          hint: '+252 61 000 0000',
          icon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          controller: _phoneController,
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(label: 'Continue', onTap: _continueFromPhone),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeading(
          'Secure your account',
          'At least 8 characters — this is what you\'ll log in with.',
        ),
        BybitTextField(
          label: 'Password',
          hint: 'At least 8 characters',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 18),
        BybitTextField(
          label: 'Confirm password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          controller: _confirmPasswordController,
        ),
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _acceptedLegal,
          onChanged:
              (value) => setState(() => _acceptedLegal = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: BybitPalette.accent,
          checkColor: Colors.black,
          title: const Text(
            'I agree to the Terms of Service and Privacy Policy.',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 12),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed:
                  () => launchUrl(
                    Uri.parse('https://wayaki.com/terms'),
                    mode: LaunchMode.externalApplication,
                  ),
              child: const Text('Read Terms'),
            ),
            TextButton(
              onPressed:
                  () => launchUrl(
                    Uri.parse('https://wayaki.com/privacy'),
                    mode: LaunchMode.externalApplication,
                  ),
              child: const Text('Read Privacy Policy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        BybitPrimaryButton(
          label: _submitting ? 'Creating account…' : 'Create account',
          enabled: _acceptedLegal && !_submitting,
          onTap: _handleSubmit,
        ),
      ],
    );
  }
}
