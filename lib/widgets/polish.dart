import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bybit_wallet_ui.dart';
import 'touch_scale.dart';

const kSupportEmail = 'support@royallpay.com';

/// A lightweight "contact support" dialog reused wherever a screen needs a
/// support action without a full disputes/ticketing backend behind it.
Future<void> showSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => Dialog(
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
                  radius: 32,
                  backgroundColor: BybitPalette.surface2,
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: BybitPalette.accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Need help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reach the support team for disputes, card issues, or anything else — we typically reply within a business day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
                ),
                const SizedBox(height: 18),
                TouchScale(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: kSupportEmail));
                    BybitToast.show(dialogContext, 'Support email copied');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: BybitPalette.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            kSupportEmail,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.copy_rounded,
                          color: BybitPalette.accent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BybitPrimaryButton(
                  label: 'Done',
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
  );
}

/// Shared motion/feedback primitives layered on top of [TouchScale] and
/// [BybitCard] — skeleton loading instead of a bare spinner, a staggered
/// entrance for lists, and a color-coded toast instead of a flat SnackBar.
/// The goal is the same physical, cozy feel across every loading state and
/// confirmation, not just the screens that happen to reach for it.

/// A shimmering placeholder bar — the building block for skeleton loading.
class BybitShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const BybitShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<BybitShimmer> createState() => _BybitShimmerState();
}

class _BybitShimmerState extends State<BybitShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final slide = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.6 + slide * 3.2, 0),
                end: Alignment(-0.6 + slide * 3.2, 0),
                colors: const [
                  BybitPalette.surface2,
                  Color(0xFF3A3F48),
                  BybitPalette.surface2,
                ],
              ).createShader(bounds);
            },
            child: Container(
              width: widget.width,
              height: widget.height,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

/// One skeleton row shaped like the icon+title+subtitle list items used
/// throughout the app (agent/merchant/order cards).
class BybitSkeletonListTile extends StatelessWidget {
  const BybitSkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            const BybitShimmer(
              width: 44,
              height: 44,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  BybitShimmer(height: 13, width: 150),
                  SizedBox(height: 8),
                  BybitShimmer(height: 11, width: 96),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stack of [BybitSkeletonListTile] — drop-in replacement for a centered
/// spinner while a list screen's first fetch is in flight.
class BybitSkeletonList extends StatelessWidget {
  final int count;
  const BybitSkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const BybitSkeletonListTile()),
    );
  }
}

/// A skeleton shaped like a stat/summary [BybitCard] — a label-sized bar
/// over a big value-sized bar, matching balance/total cards across the app.
class BybitSkeletonStat extends StatelessWidget {
  const BybitSkeletonStat({super.key});

  @override
  Widget build(BuildContext context) {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          BybitShimmer(height: 12, width: 120),
          SizedBox(height: 10),
          BybitShimmer(height: 24, width: 100),
        ],
      ),
    );
  }
}

/// Fades and slides a list item in on first build, staggered by [index] —
/// wrap each item builder in this to turn a flat list load into a cascade.
class StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredFadeIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 8) * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

enum BybitToastType { success, error, info }

/// A floating, color-coded toast — the same [ScaffoldMessenger] mechanism
/// every screen already uses, just with an icon and a status color instead
/// of flat grey text, so success/failure reads at a glance.
class BybitToast {
  BybitToast._();

  static void show(
    BuildContext context,
    String message, {
    BybitToastType type = BybitToastType.info,
  }) {
    final IconData icon;
    final Color color;
    switch (type) {
      case BybitToastType.success:
        icon = Icons.check_circle_rounded;
        color = BybitPalette.green;
        break;
      case BybitToastType.error:
        icon = Icons.error_rounded;
        color = BybitPalette.red;
        break;
      case BybitToastType.info:
        icon = Icons.info_rounded;
        color = BybitPalette.accent;
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: BybitPalette.surface2,
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.35), width: 1),
          ),
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: BybitToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: BybitToastType.error);
}
