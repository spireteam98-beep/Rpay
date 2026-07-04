import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
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
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
                'Join Kashflip',
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
              const KashTextField(
                label: 'Password',
                hint: 'At least 8 characters',
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Continue',
                onTap: () {
                  context.read<KashAppState>().completeSignup(
                    fullName: _nameController.text,
                    phoneNumber: _phoneController.text,
                  );
                  Navigator.of(context).push(kashRoute(const OtpScreen()));
                },
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
