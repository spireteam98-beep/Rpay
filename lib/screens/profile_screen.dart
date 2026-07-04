import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Profile'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: AppTheme.heroCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleIcon(
                      Icons.person_rounded,
                      color: AppTheme.onLime,
                      size: 58,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      appState.profileName,
                      style: const TextStyle(
                        color: AppTheme.onLime,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.phoneNumber,
                      style: const TextStyle(
                        color: AppTheme.onLime,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _tile(
                Icons.verified_user_outlined,
                'KYC status',
                appState.kycSubmitted
                    ? 'Full KYC submitted for review'
                    : 'Tier 1 active, full verification pending',
              ),
              _tile(
                Icons.sms_outlined,
                'Phone verification',
                appState.phoneVerified
                    ? 'Phone verified'
                    : 'Phone not verified',
              ),
              _tile(
                Icons.policy_outlined,
                'AML checks',
                'Sanctions and PEP screening ready',
              ),
              _tile(
                Icons.lock_outline_rounded,
                'Security',
                'Password, OTP and biometrics later',
              ),
              _tile(
                Icons.receipt_long_outlined,
                'Statements',
                'Wallet and virtual account records',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassTile(
        child: Row(
          children: [
            CircleIcon(icon, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }
}
