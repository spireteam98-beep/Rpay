import 'package:flutter/material.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

/// Step 1 of the user journey: the front door.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
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
                  color: BybitPalette.accent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: BybitPalette.accent.withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'RoyallPay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'All your money. One app.',
                style: TextStyle(
                  color: BybitPalette.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
              BybitPrimaryButton(
                label: 'Create account',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const SignupScreen())),
              ),
              const SizedBox(height: 12),
              _outlinedButton(
                'Log in',
                () => Navigator.of(context).push(kashRoute(const LoginScreen())),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton(String label, VoidCallback onTap) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: BybitPalette.surface2, width: 1.4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
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
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: BybitPalette.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BybitPalette.muted2,
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
