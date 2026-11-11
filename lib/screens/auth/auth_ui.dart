import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/touch_scale.dart';

/// Faint dot lattice used over red brand surfaces (header texture).
class WayakiDotGrid extends CustomPainter {
  const WayakiDotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1F000000);
    const gap = 9.0;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Four-colour Google "G", drawn so no image asset is needed.
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color c) =>
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
    const deg = math.pi / 180;
    // Angles measured clockwise from 3 o'clock.
    canvas.drawArc(rect, -45 * deg, 90 * deg, false, arc(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 45 * deg, 90 * deg, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(rect, 135 * deg, 80 * deg, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 215 * deg, 100 * deg, false, arc(const Color(0xFFEA4335)));
    // Blue crossbar.
    final bar =
        Paint()
          ..color = const Color(0xFF4285F4)
          ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2 - stroke * 0.05,
        stroke,
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page frame shared by the onboarding steps after Google sign-in:
/// back button + step counter, big title, subtitle, content, and a pinned
/// primary button at the bottom.
class AuthStepScaffold extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;
  final bool showBack;

  const AuthStepScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
              child: Row(
                children: [
                  if (showBack)
                    TouchScale(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: BybitPalette.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 42, height: 42),
                  const Spacer(),
                  Text(
                    'Step $step of $totalSteps',
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _StepBar(step: step, total: totalSteps),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    child,
                  ],
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int step;
  final int total;
  const _StepBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color:
                    i <= step ? BybitPalette.accent : BybitPalette.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Labelled dark input used on the profile step.
class AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final Widget? prefix;
  final String? errorText;
  final TextInputAction? action;
  final List<String>? autofillHints;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.prefix,
    this.errorText,
    this.action,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC7C7CC),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          textInputAction: action,
          autofillHints: autofillHints,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: BybitPalette.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6E6E73)),
            filled: true,
            fillColor: BybitPalette.surface,
            prefixIcon: prefix,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: border(BybitPalette.hairline),
            enabledBorder: border(BybitPalette.hairline),
            focusedBorder: border(BybitPalette.accent, 1.4),
            errorBorder: border(BybitPalette.red),
            focusedErrorBorder: border(BybitPalette.red, 1.4),
          ),
        ),
      ],
    );
  }
}

/// Inline error banner for a failed step.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BybitPalette.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BybitPalette.accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: BybitPalette.accentIcon,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
