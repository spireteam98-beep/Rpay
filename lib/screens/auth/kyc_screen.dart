import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
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
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Verify identity'),
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
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verification keeps your money safe and unlocks full limits for crypto, remittance and bank transfers.',
                style: TextStyle(color: BybitPalette.muted2, fontSize: 14),
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
              BybitCard(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: BybitPalette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: BybitPalette.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tier 1 unlocked at signup',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Wallet up to \$300. Full verification lifts limits and enables IBAN.',
                            style: TextStyle(
                              color: BybitPalette.muted,
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
              BybitPrimaryButton(
                label:
                    ready ? 'Submit & open my accounts' : 'Complete both steps',
                enabled: ready,
                onTap: ready ? () => _finish(context) : () {},
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _finish(context),
                  child: const Text(
                    'Skip for now — limited account',
                    style: TextStyle(color: BybitPalette.muted2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    // Raise the tier on the real backend too (fail-soft when offline).
    if (_idDone && _selfieDone) ApiService.submitKyc();
    context.read<KashAppState>().submitKyc(
      fullVerification: _idDone && _selfieDone,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: BybitPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: BybitPalette.accent,
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your accounts are ready',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Crypto wallet · Mobile money wallet · Virtual bank account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  BybitPrimaryButton(
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
    return TouchScale(
      onTap: onTap,
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: done ? BybitPalette.accent : BybitPalette.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                color: done ? Colors.black : BybitPalette.accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    done ? 'Done' : subtitle,
                    style: TextStyle(
                      color: done ? BybitPalette.green : BybitPalette.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: BybitPalette.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
