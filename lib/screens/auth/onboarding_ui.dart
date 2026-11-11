import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/touch_scale.dart';

/// Visual language of the step-by-step onboarding: near-black canvas with a
/// faint tech grid, a slowly drifting red glow, a segmented progress bar,
/// one question per screen and a Back / Next bar pinned to the bottom.
class Fz {
  static const bg = Color(0xFF0A0A0B);
  static const red = Color(0xFFE60000);
  static const hot = Color(0xFFFF2D2D);
  static const deep = Color(0xFFB00000);
  static const muted = Color(0xFF8E8E96);
  static const line = Color(0x17FFFFFF);
  static const glass = Color(0x0FFFFFFF);
  static const field = Color(0x0AFFFFFF);
  static const track = Color(0xFF26262A);
  static const green = Color(0xFF2BD48A);

  /// Total progress segments: 9 identity steps, referral, PIN, biometrics.
  static const totalSteps = 12;

  static TextStyle head(double size, {FontWeight weight = FontWeight.w700, Color color = Colors.white, double? spacing, double? height}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );

  static TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = muted, double spacing = 1.4}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );
}

/// Dark canvas with the grid and the drifting glow.
class FzBackground extends StatefulWidget {
  final Widget child;
  const FzBackground({super.key, required this.child});

  @override
  State<FzBackground> createState() => _FzBackgroundState();
}

class _FzBackgroundState extends State<FzBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Fz.bg)),
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0, 0.55],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: const CustomPaint(painter: _GridPainter()),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Positioned(
              top: -140 + 24 * t,
              right: -120 + 26 * t,
              child: Transform.scale(
                scale: 1 + 0.12 * t,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x6BE60000), Color(0x00E60000)],
                      stops: [0, 0.68],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: -160,
          left: -140,
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x29FF5A28), Color(0x00FF5A28)],
                stops: [0, 0.7],
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    const gap = 32.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wordmark + "CHAPTER · 03/12" pill and the segmented progress bar.
class FzHeader extends StatelessWidget {
  final int step;
  final String chapter;
  const FzHeader({super.key, required this.step, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/fareenn_wordmark_plain.png',
                height: 22,
                filterQuality: FilterQuality.high,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Fz.glass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Fz.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Fz.hot,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Fz.hot, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$chapter · ${step.toString().padLeft(2, '0')}/${Fz.totalSteps}',
                      style: Fz.mono(12, color: const Color(0xFFD0D0D6), spacing: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 1; i <= Fz.totalSteps; i++) ...[
                if (i > 1) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < step ? Fz.red : (i == step ? Fz.hot : Fz.track),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: i == step
                          ? const [BoxShadow(color: Color(0xE6FF2D2D), blurRadius: 10)]
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Eyebrow, big title and subtitle at the top of each step.
class FzHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  const FzHero({super.key, required this.eyebrow, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: Fz.mono(12, color: Fz.hot, spacing: 1.6)),
        const SizedBox(height: 10),
        Text(title, style: Fz.head(34, spacing: -1.3, height: 1.05)),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(color: Fz.muted, fontSize: 15, height: 1.45),
        ),
      ],
    );
  }
}

/// Fades and slides its child in whenever [animationKey] changes.
class FzEntrance extends StatelessWidget {
  final Object animationKey;
  final Widget child;
  final int delayMs;
  const FzEntrance({super.key, required this.animationKey, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(animationKey),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Interval(delayMs / (520 + delayMs), 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// Glass back button + red gradient Next button.
class FzNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool busy;
  const FzNavBar({
    super.key,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Next',
    this.nextEnabled = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = nextEnabled && !busy;
    return Row(
      children: [
        TouchScale(
          onTap: onBack,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Fz.glass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Fz.line),
            ),
            child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TouchScale(
            onTap: enabled ? onNext : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: enabled ? null : const Color(0xFF1E1E22),
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Fz.hot, Fz.red, Fz.deep],
                        stops: [0, 0.55, 1],
                      )
                    : null,
                boxShadow: enabled
                    ? const [BoxShadow(color: Color(0x73E60000), blurRadius: 30, offset: Offset(0, 12))]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  else ...[
                    Text(
                      nextLabel,
                      style: Fz.head(17, color: enabled ? Colors.white : const Color(0xFF5C5C64)),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: enabled ? Colors.white : const Color(0xFF5C5C64),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Plain text button under the nav bar ("Skip for now", "Not now").
class FzTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const FzTextButton(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFD0D0D6), fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Full page frame for one onboarding step.
class FzStepScaffold extends StatelessWidget {
  final int step;
  final String chapter;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  /// Pinned at the bottom (usually [FzNavBar], optionally with extras).
  final Widget? bottom;

  /// Changes whenever the visible question changes, to replay the entrance.
  final Object? animationKey;

  const FzStepScaffold({
    super.key,
    required this.step,
    required this.chapter,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
    this.animationKey,
  });

  @override
  Widget build(BuildContext context) {
    final key = animationKey ?? step;
    return Scaffold(
      backgroundColor: Fz.bg,
      body: FzBackground(
        child: SafeArea(
          child: Column(
            children: [
              FzHeader(step: step, chapter: chapter),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 34, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FzEntrance(
                        animationKey: key,
                        child: FzHero(eyebrow: eyebrow, title: title, subtitle: subtitle),
                      ),
                      const SizedBox(height: 30),
                      FzEntrance(animationKey: key, delayMs: 120, child: child),
                    ],
                  ),
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large single-line input with a mono label and a glowing focus ring.
class FzBigField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final TextInputAction action;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final Widget? prefix;
  final IconData? icon;

  const FzBigField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.action = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.errorText,
    this.prefix,
    this.icon,
  });

  @override
  State<FzBigField> createState() => _FzBigFieldState();
}

class _FzBigFieldState extends State<FzBigField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final textStyle = widget.mono
        ? GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1.2)
        : Fz.head(24, weight: FontWeight.w600, spacing: -0.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Fz.mono(11.5)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.fromLTRB(widget.prefix != null || widget.icon != null ? 12 : 18, 6, 18, 6),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: Fz.field,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasError ? const Color(0xFFFF5A5F) : (focused ? Fz.hot : Fz.line),
              width: 1.5,
            ),
            boxShadow: focused
                ? const [BoxShadow(color: Color(0x1FFF2D2D), spreadRadius: 4)]
                : null,
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null) ...[widget.prefix!, const SizedBox(width: 12)],
              if (widget.icon != null) ...[
                Padding(
                  padding: EdgeInsets.only(top: widget.maxLines > 1 ? 16 : 0, left: 4),
                  child: Icon(widget.icon, color: Fz.hot, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  minLines: 1,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.capitalization,
                  textInputAction: widget.action,
                  autofillHints: widget.autofillHints,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: Fz.hot,
                  cursorWidth: 2.4,
                  style: textStyle,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: textStyle.copyWith(color: const Color(0xFF4A4A52)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(widget.errorText!, style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 13)),
        ],
      ],
    );
  }
}

/// Glass info line with a red icon.
class FzTip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FzTip(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Fz.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Fz.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: Fz.hot, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFC9C9CF), fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Red-tinted error box.
class FzError extends StatelessWidget {
  final String message;
  const FzError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1FFF2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FF2D2D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Fz.hot, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _choiceDecoration(bool selected, double radius) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: selected ? null : Fz.field,
      gradient: selected
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x38FF2D2D), Color(0x0FE60000)],
            )
          : null,
      border: Border.all(color: selected ? Fz.hot : Fz.line, width: 1.5),
      boxShadow: selected
          ? const [BoxShadow(color: Color(0x40E60000), blurRadius: 30, offset: Offset(0, 10))]
          : null,
    );

Widget _checkBadge(bool selected) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Fz.hot : Colors.transparent,
        border: Border.all(color: selected ? Fz.hot : const Color(0xFF3A3A40), width: 1.5),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );

/// Big selectable card: a tall tile ([tall]) or a full-width row.
class FzChoiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final bool tall;
  final VoidCallback onTap;

  const FzChoiceCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tall) {
      return TouchScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 210,
          padding: const EdgeInsets.all(20),
          decoration: _choiceDecoration(selected, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 52, color: selected ? Colors.white : const Color(0xFFBDBDC2)),
                  const Spacer(),
                  _checkBadge(selected),
                ],
              ),
              const Spacer(),
              Text(title, style: Fz.head(22)),
            ],
          ),
        ),
      );
    }
    return TouchScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: _choiceDecoration(selected, 24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: selected ? Colors.white : const Color(0xFFBDBDC2), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Fz.head(19)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: const TextStyle(color: Fz.muted, fontSize: 13.5)),
                  ],
                ],
              ),
            ),
            _checkBadge(selected),
          ],
        ),
      ),
    );
  }
}

/// Compact selectable tile used for the region grid.
class FzTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const FzTile({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _choiceDecoration(selected, 20),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: selected ? Fz.hot : Fz.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Fz.head(15.5, weight: FontWeight.w600, height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of small glass hint chips (photo tips).
class FzHintChips extends StatelessWidget {
  final List<String> items;
  const FzHintChips(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Fz.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Fz.line),
              ),
              child: Text(
                items[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFD0D0D6), fontSize: 12.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Camera frame with red corner brackets and a sweeping scan line.
class FzViewfinder extends StatefulWidget {
  final Widget child;
  final bool scanning;
  final double height;
  const FzViewfinder({super.key, required this.child, this.scanning = true, this.height = 260});

  @override
  State<FzViewfinder> createState() => _FzViewfinderState();
}

class _FzViewfinderState extends State<FzViewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Fz.line),
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFF26262C), Color(0xFF101012)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
          if (widget.scanning)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = math.sin(_c.value * math.pi);
                return Positioned(
                  left: 22,
                  right: 22,
                  top: widget.height * (0.1 + 0.76 * t),
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.transparent, Fz.hot, Colors.transparent]),
                      boxShadow: [BoxShadow(color: Color(0x99FF2D2D), blurRadius: 16, spreadRadius: 3)],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Fz.hot
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const m = 14.0, l = 34.0, r = 14.0;
    void corner(double x, double y, double sx, double sy) {
      final path = Path()
        ..moveTo(x, y + sy * l)
        ..lineTo(x, y + sy * r)
        ..quadraticBezierTo(x, y, x + sx * r, y)
        ..lineTo(x + sx * l, y);
      canvas.drawPath(path, p);
    }

    corner(m, m, 1, 1);
    corner(size.width - m, m, -1, 1);
    corner(m, size.height - m, 1, -1);
    corner(size.width - m, size.height - m, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing round shutter button.
class FzShutter extends StatefulWidget {
  final VoidCallback onTap;
  const FzShutter({super.key, required this.onTap});

  @override
  State<FzShutter> createState() => _FzShutterState();
}

class _FzShutterState extends State<FzShutter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = _c.value;
          return Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Fz.red.withValues(alpha: 0.55 * (1 - v)),
                  spreadRadius: 16 * v,
                ),
              ],
            ),
            child: child,
          );
        },
        child: const DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Fz.hot),
        ),
      ),
    );
  }
}

/// Small glass pill button (Upload, Retake).
class FzPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const FzPillButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Fz.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Fz.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Rotating red arc, used around the selfie frame and the submit loader.
class FzSpinRing extends StatefulWidget {
  final double size;
  final double stroke;
  final Duration period;
  final double sweep; // fraction of a full turn that is lit
  final Widget? child;
  const FzSpinRing({
    super.key,
    required this.size,
    this.stroke = 6,
    this.period = const Duration(seconds: 6),
    this.sweep = 0.7,
    this.child,
  });

  @override
  State<FzSpinRing> createState() => _FzSpinRingState();
}

class _FzSpinRingState extends State<FzSpinRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _ArcPainter(widget.stroke, widget.sweep),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double stroke;
  final double sweep;
  _ArcPainter(this.stroke, this.sweep);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Fz.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: const [Color(0x00FF2D2D), Fz.hot],
          stops: [0, sweep],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.stroke != stroke || old.sweep != sweep;
}
