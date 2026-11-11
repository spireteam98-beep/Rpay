import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Animated "Spending" insight card for the wallet dashboard: black card,
/// a count-up total, a bar for every day of the month that grows into
/// place, and two ring gauges whose percentages climb as they fill.
/// Tapping the card plays the animation again.
class SpendingInsightCard extends StatefulWidget {
  /// Amount spent on each day of the current month so far (index 0 = 1st).
  final List<double> daily;
  final double total;

  /// 0..1 values for the two gauges.
  final double limitUsed;
  final double saved;

  final bool isExample;
  final bool hideAmounts;
  final VoidCallback? onOpen;

  const SpendingInsightCard({
    super.key,
    required this.daily,
    required this.total,
    required this.limitUsed,
    required this.saved,
    this.isExample = false,
    this.hideAmounts = false,
    this.onOpen,
  });

  @override
  State<SpendingInsightCard> createState() => SpendingInsightCardState();
}

class SpendingInsightCardState extends State<SpendingInsightCard>
    with SingleTickerProviderStateMixin {
  static const _redSoft = Color(0xFFFF4D4D);
  static const _card = Color(0xFF141414);
  static const _muted = Color(0xFF9A9A9F);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Plays when the card scrolls into view and resets once it has fully
  // left the screen, so the chart animates again every time it comes back.
  ScrollPosition? _position;
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_checkVisible);
      _position = next;
      _position?.addListener(_checkVisible);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  /// Called by the screen on every scroll so the chart plays the moment it
  /// comes into view, whatever scroll view it sits in.
  void checkVisible() => _checkVisible();

  void _checkVisible() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final h = box.size.height;
    if (h <= 0) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final visible =
        ((math.min(top + h, screenH) - math.max(top, 0.0)) / h).clamp(0.0, 1.0);
    if (!_shown && visible > 0.2) {
      _shown = true;
      _c.forward(from: 0);
    } else if (_shown && visible <= 0.0) {
      _shown = false;
      _c.value = 0;
    }
  }

  final _money = NumberFormat.currency(symbol: r'$');

  @override
  void dispose() {
    _position?.removeListener(_checkVisible);
    _c.dispose();
    super.dispose();
  }

  void _replay() => _c.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 36 * (1 - t.value)),
        child: Transform.scale(
          scale: 0.95 + 0.05 * t.value,
          child: child,
        ),
      ),
      child: GestureDetector(
      onTap: _replay,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: AnimatedBuilder(
          animation: t,
          builder: (context, _) {
            final v = t.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Spending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.isExample)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'EXAMPLE',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onOpen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: const Text(
                          'This month',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.hideAmounts
                      ? r'$ ••••••'
                      : _money.format(widget.total * v),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Spent so far',
                  style: TextStyle(
                    color: _redSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 96,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _BarsPainter(widget.daily, v),
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: const Color(0x14FFFFFF)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _gauge(
                        label: 'Daily limit used',
                        value: widget.limitUsed,
                        v: v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _gauge(
                        label: 'Saved this month',
                        value: widget.saved,
                        v: v,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _gauge({
    required String label,
    required double value,
    required double v,
  }) {
    final shown = (value.clamp(0.0, 1.0) * v);
    return Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CustomPaint(painter: _RingPainter(shown)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(shown * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  color: _redSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One thin bar per day; bars grow in left to right, today's bar is the
/// brightest red.
class _BarsPainter extends CustomPainter {
  final List<double> daily;
  final double t;
  _BarsPainter(this.daily, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.isEmpty) return;
    final maxV = daily.fold<double>(0, math.max);
    final n = daily.length;
    final gap = 3.0;
    final w = math.max(2.0, (size.width - gap * (n - 1)) / n);
    final baseline = Paint()..color = const Color(0x1FFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      baseline,
    );
    for (var i = 0; i < n; i++) {
      // Stagger: each bar starts a little after the previous one.
      final start = (i / n) * 0.45;
      final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(local).clamp(0.0, 1.2);
      final ratio = maxV <= 0 ? 0.0 : daily[i] / maxV;
      final h = math.max(3.0, ratio * (size.height - 6)) * eased;
      final x = i * (w + gap);
      final isToday = i == n - 1;
      final paint = Paint()
        ..color = isToday ? const Color(0xFFFF2A2A) : const Color(0xFFB30000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 1 - h, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.t != t || old.daily != daily;
}

class _RingPainter extends CustomPainter {
  final double value;
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 7.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0xFF2A2A2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = const Color(0xFFE60000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}
