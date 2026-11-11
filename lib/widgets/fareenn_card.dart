import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The Fareenn card artwork, drawn natively so it stays sharp at any size:
/// brand red with a dot texture, a gold and black ribbon with stitch
/// threads, gold chip, contactless mark, card details and the network logo.
/// Laid out on an 856 x 540 canvas (real card ratio) and scaled to fit.
class FareennCard extends StatelessWidget {
  final String holder;
  final String number;
  final String expiry;
  final String cvc;

  const FareennCard({
    super.key,
    this.holder = 'MUDAN ALI',
    this.number = '5412 7534 8821 4821',
    this.expiry = '09/30',
    this.cvc = '123',
  });

  static const _shadow = [
    Shadow(color: Color(0x8C000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  TextStyle _mono(double size, {double spacing = 2}) => TextStyle(
        fontFamily: 'Courier New',
        fontFamilyFallback: const ['Courier', 'monospace'],
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: spacing,
        color: Colors.white,
        height: 1,
        shadows: _shadow,
      );

  TextStyle _label(double size, {FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 2,
        color: Colors.white,
        height: 1,
        shadows: _shadow,
      );

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 856 / 540,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 856,
          height: 540,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _CardArtPainter()),
                ),
                // The official Fareenn wordmark (same artwork as the master
                // logo), so the card always uses the real brand lettering.
                Positioned(
                  left: 58,
                  top: 70,
                  child: Image.asset(
                    'assets/images/fareenn_wordmark_plain.png',
                    width: 380,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 68,
                  top: 206,
                  child: Text('FRIENDLY BANKING', style: _label(20)),
                ),
                Positioned(
                  left: 64,
                  top: 256,
                  child: Text(number, style: _mono(42, spacing: 4)),
                ),
                Positioned(
                  left: 64,
                  bottom: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _field('VALID THRU', expiry),
                          const SizedBox(width: 40),
                          _field('CVC', cvc),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(holder,
                          style: _label(26, weight: FontWeight.w800)),
                    ],
                  ),
                ),
                Positioned(
                  right: 54,
                  bottom: 30,
                  child: Image.asset(
                    'assets/images/mastercard.png',
                    width: 150,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label(12)),
          const SizedBox(height: 6),
          Text(value, style: _mono(26)),
        ],
      );
}

class _CardArtPainter extends CustomPainter {
  const _CardArtPainter();

  static const _red = Color(0xFFE60000);
  static const _black = Color(0xFF141414);

  /// One ribbon curve, shifted down by [y0] like the SVG artwork.
  Path _curve(double y0) => Path()
    ..moveTo(-20, y0)
    ..cubicTo(220, y0 - 56, 520, y0 - 90, 880, y0 - 150);

  void _stroke(Canvas c, double y0, Color color, double width,
      {List<double>? dash, Shader? shader}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (shader != null) paint.shader = shader;
    final path = _curve(y0);
    if (dash == null) {
      c.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      var on = true;
      var i = 0;
      while (d < metric.length) {
        final len = dash[i % dash.length];
        if (on) c.drawPath(metric.extractPath(d, d + len), paint);
        d += len;
        on = !on;
        i++;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 856, size.height / 540);
    const full = Rect.fromLTWH(0, 0, 856, 540);

    canvas.drawRect(full, Paint()..color = _red);
    final dot = Paint()..color = const Color(0x17FFFFFF);
    for (double y = 7; y < 540; y += 14) {
      for (double x = 7; x < 856; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.6, dot);
      }
    }

    final gold = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(856, 0),
      const [Color(0xFFB9822A), Color(0xFFE9B949), Color(0xFFF6D576), Color(0xFFC8902E)],
      const [0, .35, .6, 1],
    );

    _stroke(canvas, 318, const Color(0xFFE8A33A), 2.5, dash: [6, 5]);
    _stroke(canvas, 330, const Color(0xBFFFFFFF), 1.6, dash: [3, 5]);
    _stroke(canvas, 344, _black, 2);
    _stroke(canvas, 392, Colors.white, 58, shader: gold);
    _stroke(canvas, 450, _black, 36);
    _stroke(canvas, 480, const Color(0xFFF2A93B), 2);
    _stroke(canvas, 492, const Color(0xB3FFFFFF), 1.4, dash: [3, 5]);
    _stroke(canvas, 504, const Color(0xFFD9822B), 3);
    _stroke(canvas, 518, const Color(0xFFE8A33A), 1.6, dash: [6, 4]);
    _stroke(canvas, 536, _black, 2.4);

    // Soft light sheen from the top-left corner.
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(500, 320),
          const [Color(0x10FFFFFF), Color(0x00FFFFFF)],
        ),
    );

    // Gold chip.
    const chip = Rect.fromLTWH(578, 96, 104, 80);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(14)),
      Paint()
        ..shader = ui.Gradient.linear(
          chip.topLeft,
          chip.bottomRight,
          const [Color(0xFFF6D98A), Color(0xFFD9A93F), Color(0xFFB8862C)],
          const [0, .5, 1],
        ),
    );
    final chipLine = Paint()
      ..color = const Color(0x736E460A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas
      ..drawLine(const Offset(578, 136), const Offset(612, 136), chipLine)
      ..drawLine(const Offset(648, 136), const Offset(682, 136), chipLine)
      ..drawLine(const Offset(612, 96), const Offset(612, 176), chipLine)
      ..drawLine(const Offset(648, 96), const Offset(648, 176), chipLine)
      ..drawLine(const Offset(612, 118), const Offset(648, 118), chipLine)
      ..drawLine(const Offset(612, 154), const Offset(648, 154), chipLine);

    // Contactless waves.
    final wave = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    void arc(double tipX, double r, double halfChord) {
      final cx = tipX - math.sqrt(r * r - halfChord * halfChord);
      final a = math.asin(halfChord / r);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, 136), radius: r),
        -a,
        2 * a,
        false,
        wave,
      );
    }

    arc(716, 24, 18);
    arc(732, 40, 28);
    arc(748, 56, 38);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wraps a card in a 3D stage: it floats gently, tilts toward the mouse or
/// finger with a moving light reflection, and settles back when released.
/// Uses a [Listener] so it never steals vertical scrolling.
class TiltCard extends StatefulWidget {
  final Widget child;
  const TiltCard({super.key, required this.child});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  Offset _tilt = Offset.zero; // -0.5 .. 0.5 on each axis
  bool _active = false;

  void _move(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _active = true;
      _tilt = Offset(
        (local.dx / size.width).clamp(0.0, 1.0).toDouble() - 0.5,
        (local.dy / size.height).clamp(0.0, 1.0).toDouble() - 0.5,
      );
    });
  }

  void _rest() => setState(() {
        _active = false;
        _tilt = Offset.zero;
      });

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99280000),
            blurRadius: 40,
            spreadRadius: -8,
            offset: Offset(0, 26),
          ),
        ],
      ),
      child: widget.child,
    );

    if (reduceMotion) {
      return Transform.rotate(angle: -0.14, child: card);
    }

    return MouseRegion(
      onHover: (e) => _move(e.localPosition),
      onExit: (_) => _rest(),
      child: Listener(
        onPointerDown: (e) => _move(e.localPosition),
        onPointerMove: (e) => _move(e.localPosition),
        onPointerUp: (_) => _rest(),
        onPointerCancel: (_) => _rest(),
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -10 * Curves.easeInOut.transform(_float.value)),
            child: child,
          ),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(begin: Offset.zero, end: _tilt),
            duration: Duration(milliseconds: _active ? 120 : 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-t.dy * 0.35)
                ..rotateY(t.dx * 0.49)
                ..rotateZ(-0.14);
              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(t.dx * 2, t.dy * 2),
                                radius: 0.9,
                                colors: [
                                  _active
                                      ? const Color(0x47FFFFFF)
                                      : const Color(0x1AFFFFFF),
                                  const Color(0x00FFFFFF),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: card,
          ),
        ),
      ),
    );
  }
}
