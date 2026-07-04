import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../widgets/kash_widgets.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

/// Step 1 of the user journey: the front door.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo mark
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.limeSoft, AppTheme.primaryColor],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppTheme.onLime,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'ROYALPAY',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'All your money. One app.',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 24),
              _valueRow(
                Icons.currency_bitcoin_rounded,
                'Crypto wallet — buy, sell & swap safely',
              ),
              _valueRow(
                Icons.phone_iphone_rounded,
                'Mobile money — EVC Plus, Zaad, Sahal, M-Pesa',
              ),
              _valueRow(
                Icons.account_balance_rounded,
                'Bank account — receive money globally (IBAN soon)',
              ),
              _valueRow(
                Icons.storefront_rounded,
                'Pay anyone — person, merchant or bank',
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Create account',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const SignupScreen())),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Log in',
                outlined: true,
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const LoginScreen())),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleIcon(icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textLightGrey,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
