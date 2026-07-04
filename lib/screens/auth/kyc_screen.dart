import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/kash_widgets.dart';
import '../main_navigation.dart';

/// Step 4: tiered KYC — verify identity to unlock full limits.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  bool _idDone = false;
  bool _selfieDone = false;

  @override
  Widget build(BuildContext context) {
    final ready = _idDone && _selfieDone;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Verify identity'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Two quick steps',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Verification keeps your money safe and unlocks full limits for crypto, remittance and bank transfers.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _kycStep(
                icon: Icons.badge_outlined,
                title: 'Scan your ID document',
                subtitle: 'Passport, national ID or driving licence',
                done: _idDone,
                onTap: () => setState(() => _idDone = true),
              ),
              const SizedBox(height: 12),
              _kycStep(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Take a selfie',
                subtitle: 'Confirms the document belongs to you',
                done: _selfieDone,
                onTap: () => setState(() => _selfieDone = true),
              ),
              const SizedBox(height: 24),
              GlassTile(
                child: Row(
                  children: [
                    const CircleIcon(Icons.verified_user_outlined, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tier 1 unlocked at signup',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Wallet up to \$300. Full verification lifts limits and enables IBAN.',
                            style: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label:
                    ready ? 'Submit & open my accounts' : 'Complete both steps',
                onTap: ready ? () => _finish(context) : () {},
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _finish(context),
                  child: const Text('Skip for now — limited account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    context.read<KashAppState>().submitKyc(
      fullVerification: _idDone && _selfieDone,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: AppTheme.cardDarkBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.rCard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.onLime,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your accounts are ready',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Crypto wallet · Mobile money wallet · Virtual bank account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Go to my dashboard',
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

  Widget _kycStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
    required VoidCallback onTap,
  }) {
    return GlassTile(
      onTap: onTap,
      child: Row(
        children: [
          CircleIcon(
            done ? Icons.check_rounded : icon,
            color: done ? AppTheme.onLime : AppTheme.primaryColor,
            bg: done ? AppTheme.primaryColor : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  done ? 'Done' : subtitle,
                  style: TextStyle(
                    color: done ? AppTheme.priceUp : AppTheme.textGrey,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textGrey,
            size: 22,
          ),
        ],
      ),
    );
  }
}
