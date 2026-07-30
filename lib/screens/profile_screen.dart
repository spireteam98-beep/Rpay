import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'admin_console_screen.dart';
import 'auth/welcome_screen.dart';
import 'kyc_limits_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';

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
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const KycLimitsScreen())),
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
                appState.hasPin
                    ? 'Transaction PIN active'
                    : 'Set a transaction PIN, biometrics, device trust',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const SecurityScreen())),
              ),
              _tile(
                Icons.receipt_long_outlined,
                'Statements',
                'Wallet and virtual account records',
              ),
              _tile(
                Icons.settings_outlined,
                'Settings',
                'Personal details, accounts, notifications, support',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const SettingsScreen())),
              ),
              if (appState.isAdmin)
                _tile(
                  Icons.admin_panel_settings_outlined,
                  'Admin console',
                  'Ops, AML queue, agents and merchants',
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const AdminConsoleScreen())),
                ),
              const SizedBox(height: 8),
              _tile(
                Icons.logout_rounded,
                'Log out',
                'Sign out of this device',
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: BybitPalette.surface,
            title: const Text('Log out?', style: TextStyle(color: Colors.white)),
            content: const Text(
              "You'll need to sign in again to access your wallet.",
              style: TextStyle(color: BybitPalette.muted2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Log out',
                  style: TextStyle(color: BybitPalette.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    await ApiService.logout();
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      kashRoute(const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    final card = BybitCard(
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
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null ? card : TouchScale(onTap: onTap, child: card),
    );
  }
}
