import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import 'auth/kyc_screen.dart';

/// Verification progress + the real per-transfer/daily limits that tier
/// unlocks — reads straight off [KashAppState], no separate fetch needed,
/// and pushes the existing [KycScreen] rather than duplicating its
/// ID/selfie flow.
class KycLimitsScreen extends StatelessWidget {
  const KycLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final tier = appState.tier;
    final full = appState.kycSubmitted;

    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Verification & limits'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _progressStep(
                title: 'Phone verified',
                done: appState.phoneVerified,
              ),
              _progressStep(title: 'Tier 1 active', done: true),
              _progressStep(title: 'ID document & selfie', done: full),
              _progressStep(
                title: 'Full limits unlocked',
                done: full,
                isLast: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your limits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _limitField('Current tier', tier.label),
              const SizedBox(height: 10),
              _limitField(
                'Per-transfer limit',
                '\$${tier.perTransferLimit.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 10),
              _limitField(
                'Daily limit',
                '\$${tier.dailyLimit.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 10),
              _limitField(
                'Spent today',
                '\$${appState.spentToday.toStringAsFixed(2)}',
              ),
              if (!full) ...[
                const SizedBox(height: 28),
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
                              'Unlock full limits',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Verify your ID to raise your daily limit to \$25,000.',
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
                const SizedBox(height: 16),
                BybitPrimaryButton(
                  label: 'Verify identity',
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const KycScreen())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressStep({
    required String title,
    required bool done,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: done ? BybitPalette.accent : BybitPalette.surface2,
            child: Icon(
              done ? Icons.check_rounded : Icons.more_horiz_rounded,
              color: done ? Colors.black : BybitPalette.muted,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: done ? Colors.white : BybitPalette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
