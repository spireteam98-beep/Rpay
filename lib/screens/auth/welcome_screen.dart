import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        bottom: false,
        child: Column(
          children: [
            _waveHero(),
            Expanded(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            const Text(
                              'All your money. One app.',
                              style: TextStyle(
                                color: BybitPalette.accent,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 32),
                            BybitPrimaryButton(
                              label: 'Create account',
                              onTap:
                                  () => Navigator.of(
                                    context,
                                  ).push(kashRoute(const SignupScreen())),
                            ),
                            const SizedBox(height: 14),
                            _loginLink(context),
                            const Spacer(),
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
      ),
    );
  }

  /// Lime wave hero, matching the "scoop" header used app-wide — the front
  /// door gets the same brand signature as every screen behind it.
  Widget _waveHero() {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: ClipPath(
              clipper: BybitWaveClipper(),
              child: ColoredBox(color: BybitPalette.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Image.asset(
              'assets/images/wayaki_logo.png',
              width: 210,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact "Already have an account? Log in" row — sits directly under
  /// the primary CTA instead of a second full-width button, so returning
  /// users don't need as much vertical space as new signups do.
  Widget _loginLink(BuildContext context) {
    return Center(
      child: TouchScale(
        onTap: () => Navigator.of(context).push(kashRoute(const LoginScreen())),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 12),
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
        style: const TextStyle(
          color: BybitPalette.muted2,
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
