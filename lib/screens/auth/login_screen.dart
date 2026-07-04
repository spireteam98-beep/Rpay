import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../widgets/kash_widgets.dart';
import '../main_navigation.dart';

/// Returning users: phone + password (biometrics later).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
              const KashTextField(
                label: 'Phone number',
                hint: '+252 61 000 0000',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              const KashTextField(
                label: 'Password',
                hint: 'Your password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
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
                onTap:
                    () => Navigator.of(context).pushAndRemoveUntil(
                      kashRoute(const MainNavigation()),
                      (r) => false,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
