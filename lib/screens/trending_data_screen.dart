import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cryptocurrency.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

/// Derivatives sentiment view (long/short ratio, taker buy/sell volume).
/// These are futures-market metrics our spot-only exchange doesn't have a
/// live feed for yet, so the candles are illustrative — same convention the
/// price chart on the Trade tab already used before this screen existed.
class TrendingDataScreen extends StatefulWidget {
  final Cryptocurrency? crypto;

  const TrendingDataScreen({super.key, this.crypto});

  @override
  State<TrendingDataScreen> createState() => _TrendingDataScreenState();
}

class _TrendingDataScreenState extends State<TrendingDataScreen> {
  static const _marketTabs = ['Spot', 'Futures', 'Options'];

  late Cryptocurrency _crypto;
  int _marketTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _crypto = widget.crypto ?? Cryptocurrency.mockData[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.accent,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            const SizedBox(height: 18),
            _coinSelector(),
            const SizedBox(height: 16),
            _marketTabsRow(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: BybitPalette.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _chartCard(
                      title: 'Margin long/short ratio',
                      subtitle: 'Long/short ratio',
                      seed: 11,
                      minY: 29.8,
                      maxY: 30.2,
                    ),
                    const SizedBox(height: 16),
                    _chartCard(
                      title: 'Taker buy/sell',
                      subtitle: 'Taker buy volume',
                      seed: 47,
                      minY: 29.8,
                      maxY: 30.2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TouchScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.14), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            ),
          ),
          const Text(
            'Trending Data',
            style: TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.14), shape: BoxShape.circle),
            child: const Icon(Icons.info_outline_rounded, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _coinSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: Center(
              child: Text(
                _crypto.symbol.isEmpty ? '?' : _crypto.symbol.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: BybitPalette.accent, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _crypto.symbol.toUpperCase(),
            style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black, size: 22),
        ],
      ),
    );
  }

  Widget _marketTabsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_marketTabs.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _marketTab(_marketTabs[i], i),
          );
        }),
      ),
    );
  }

  Widget _marketTab(String label, int index) {
    final selected = _marketTabIndex == index;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _marketTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required int seed,
    required double minY,
    required double maxY,
  }) {
    final candles = _sampleCandles(seed, minY, maxY);
    return BybitCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
                child: const Icon(Icons.ios_share_rounded, color: BybitPalette.muted, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subtitle, style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: BybitPalette.surface2, borderRadius: BorderRadius.circular(100)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('5m', style: TextStyle(color: BybitPalette.muted2, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    Icon(Icons.keyboard_arrow_down_rounded, color: BybitPalette.muted, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: Row(
              children: [
                _yAxisLabels(minY, maxY),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _CandlestickPainter(candles: candles, minY: minY, maxY: maxY),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('09:10', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
                Text('09:20', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
                Text('09:35', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
                Text('09:45', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
                Text('10:00', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
                Text('10:10', style: TextStyle(color: BybitPalette.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yAxisLabels(double minY, double maxY) {
    final steps = 5;
    final labels = List.generate(steps, (i) => maxY - (maxY - minY) * i / (steps - 1));
    return SizedBox(
      width: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: labels.map((v) {
          return Text(v.toStringAsFixed(1), style: const TextStyle(color: BybitPalette.muted, fontSize: 10.5));
        }).toList(),
      ),
    );
  }

  List<_Candle> _sampleCandles(int seed, double minY, double maxY) {
    final rand = _DeterministicRandom(seed);
    final range = maxY - minY;
    double level = minY + range * 0.35;
    final candles = <_Candle>[];
    for (var i = 0; i < 14; i++) {
      final drift = (rand.next() - 0.35) * range * 0.06;
      final open = level;
      level = (level + drift).clamp(minY + range * 0.05, maxY - range * 0.05);
      final close = level;
      final wiggle = rand.next() * range * 0.03;
      final high = (open > close ? open : close) + wiggle;
      final low = (open < close ? open : close) - wiggle;
      candles.add(_Candle(open, close, high, low));
    }
    return candles;
  }
}

class _Candle {
  final double open;
  final double close;
  final double high;
  final double low;
  const _Candle(this.open, this.close, this.high, this.low);
  bool get isUp => close >= open;
}

/// Small seeded PRNG so the illustrative candles are stable across rebuilds
/// instead of jumping around every time the widget repaints.
class _DeterministicRandom {
  int _state;
  _DeterministicRandom(int seed) : _state = seed * 9301 + 49297;
  double next() {
    _state = (_state * 9301 + 49297) % 233280;
    return _state / 233280;
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<_Candle> candles;
  final double minY;
  final double maxY;

  const _CandlestickPainter({required this.candles, required this.minY, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final gridPaint = Paint()
      ..color = BybitPalette.surface2
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final n = candles.length;
    final slot = size.width / n;
    final bodyWidth = (slot * 0.5).clamp(3.0, 14.0);
    double yFor(double v) => size.height - ((v - minY) / (maxY - minY)) * size.height;

    for (var i = 0; i < n; i++) {
      final c = candles[i];
      final cx = slot * i + slot / 2;
      final color = c.isUp ? BybitPalette.green : BybitPalette.red;
      canvas.drawLine(
        Offset(cx, yFor(c.high)),
        Offset(cx, yFor(c.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.4,
      );
      final top = yFor(c.open > c.close ? c.open : c.close);
      final bottom = yFor(c.open > c.close ? c.close : c.open);
      final rectBottom = bottom - top < 2 ? top + 2 : bottom;
      canvas.drawRect(
        Rect.fromLTRB(cx - bodyWidth / 2, top, cx + bodyWidth / 2, rectBottom),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) => false;
}
