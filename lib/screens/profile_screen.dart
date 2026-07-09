import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Profile'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: BybitPalette.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF242832)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: BybitPalette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: BybitPalette.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      appState.profileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.phoneNumber,
                      style: const TextStyle(
                        color: BybitPalette.muted2,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: BybitPalette.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: BybitPalette.accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BybitPalette.muted),
          ],
        ),
      ),
    );
  }
}
