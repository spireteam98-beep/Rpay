import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_theme.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
import '../../widgets/ui/wayaki_glow_button.dart';
import 'signup_screen.dart';

/// Step 1 of the user journey: the front door.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // Background subtle neon glow mimicking the Framer UI
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            height: 400,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox(),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                          // Premium Centered Logo
                          Image.asset(
                            'assets/images/wayaki_logo.png',
                            width: 220,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 40),
                          // Strong Value Proposition
                          const Text(
                            'Crypto, Mobile Money, and Banking.\nAll in one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Space Grotesk',
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'The next-generation Web3 treasury operating system.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(flex: 3),
                          // New WayakiGlowButton
                          SizedBox(
                            width: double.infinity,
                            child: WayakiGlowButton(
                              label: 'Start Free Crypto Sandbox',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => Navigator.of(context).push(kashRoute(const SignupScreen())),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _loginLink(context),
                          const SizedBox(height: 40),
                          _legalFooter(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Compact "Already have an account? Log in" row aligned perfectly
  Widget _loginLink(BuildContext context) {
    return Center(
      child: TouchScale(
        onTap: () => context.push('/login'),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
            children: [
              const TextSpan(text: 'Already have an account? '),
              TextSpan(
                text: 'Log in',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalFooter() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _footerLink('Privacy Policy', '/privacy.html'),
        _footerLink('Terms', '/terms.html'),
        _footerLink('Delete account', '/data-deletion.html'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ),
        _footerLink('Support', '/support.html'),
      ],
    );
  }

  Widget _footerLink(String label, String path) {
    return GestureDetector(
      onTap: () => _openLink(path),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textGrey,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _openLink(String path) async {
    final uri = Uri.parse(kIsWeb ? path : 'https://wayaki.com$path');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }
}
