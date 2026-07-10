import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/aml_case.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

class AmlQueueScreen extends StatelessWidget {
  const AmlQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final cases = appState.amlCases;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Monitoring queue'),
      body: SafeArea(
        child:
            cases.isEmpty
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: BybitPalette.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: BybitPalette.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No open cases',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sanctions, velocity and limit rules are running.',
                        style: TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: cases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final amlCase = cases[index];
                    return _caseTile(context, appState, amlCase);
                  },
                ),
      ),
    );
  }

  Widget _caseTile(
    BuildContext context,
    KashAppState appState,
    AmlCase amlCase,
  ) {
    final isOpen = amlCase.status == 'Open';
    final color = switch (amlCase.kind) {
      AmlCaseKind.sanctionsHit => BybitPalette.red,
      AmlCaseKind.velocity => const Color(0xFFFFB74D),
      AmlCaseKind.limitBreach => const Color(0xFF8FA7FF),
    };
    final icon = switch (amlCase.kind) {
      AmlCaseKind.sanctionsHit => Icons.gpp_bad_outlined,
      AmlCaseKind.velocity => Icons.speed_rounded,
      AmlCaseKind.limitBreach => Icons.data_thresholding_outlined,
    };
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amlCase.kindLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amlCase.subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      isOpen
                          ? color.withOpacity(0.14)
                          : BybitPalette.green.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  amlCase.status,
                  style: TextStyle(
                    color: isOpen ? color : BybitPalette.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amlCase.details,
            style: const TextStyle(
              color: BybitPalette.muted2,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, HH:mm').format(amlCase.createdAt),
                style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
              ),
              if (isOpen)
                TouchScale(
                  onTap: () => appState.clearAmlCase(amlCase.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: BybitPalette.accent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Clear case',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
