import 'package:flutter/material.dart';
import 'bybit_wallet_ui.dart';

/// A single row on the receipt (e.g. "Reference number" / "000123").
class ReceiptLine {
  final String label;
  final String value;
  final bool emphasize;

  const ReceiptLine(this.label, this.value, {this.emphasize = false});
}

/// Cuts a semicircular notch into both side edges at [notchY] — the classic
/// "torn ticket stub" look — on an otherwise rounded-rect card.
class TicketClipper extends CustomClipper<Path> {
  final double notchY;
  final double notchRadius;
  final double cornerRadius;

  const TicketClipper({
    required this.notchY,
    this.notchRadius = 13,
    this.cornerRadius = 28,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, cornerRadius)
      ..quadraticBezierTo(0, 0, cornerRadius, 0)
      ..lineTo(w - cornerRadius, 0)
      ..quadraticBezierTo(w, 0, w, cornerRadius)
      ..lineTo(w, notchY - notchRadius)
      ..arcToPoint(
        Offset(w, notchY + notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: true,
      )
      ..lineTo(w, h - cornerRadius)
      ..quadraticBezierTo(w, h, w - cornerRadius, h)
      ..lineTo(cornerRadius, h)
      ..quadraticBezierTo(0, h, 0, h - cornerRadius)
      ..lineTo(0, notchY + notchRadius)
      ..arcToPoint(
        Offset(0, notchY - notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: true,
      )
      ..lineTo(0, cornerRadius)
      ..close();
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) =>
      oldClipper.notchY != notchY ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.cornerRadius != cornerRadius;
}

/// Perforated-edge dashed line, same look as the one on the Send Money
/// review sheet — kept here too so the receipt doesn't depend on that screen.
class ReceiptDashedLine extends CustomPainter {
  const ReceiptDashedLine();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = BybitPalette.muted.withValues(alpha: 0.35)
          ..strokeWidth = 1;
    const dashWidth = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ticket-style transaction receipt: checkmark + status header, a torn-stub
/// notch line, then reference/date/method details and an amount breakdown.
/// Designed to be captured via RepaintBoundary for share/save — see
/// receipt_dialog.dart, which wraps this with those actions.
class ReceiptTicket extends StatelessWidget {
  static const double headerHeight = 172;

  final String statusTitle;
  final String reference;
  final String dateTime;
  final String paymentMethod;
  final List<ReceiptLine> details;
  final List<ReceiptLine> amountLines;
  final ReceiptLine total;

  const ReceiptTicket({
    super.key,
    required this.statusTitle,
    required this.reference,
    required this.dateTime,
    required this.paymentMethod,
    required this.details,
    required this.amountLines,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const TicketClipper(notchY: headerHeight),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF11140A), BybitPalette.bg],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: headerHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BybitPalette.accent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: BybitPalette.accent.withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: BybitPalette.accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 1,
              child: CustomPaint(painter: const ReceiptDashedLine()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(ReceiptLine('Reference number', reference)),
                  const SizedBox(height: 14),
                  _row(ReceiptLine('Date & time', dateTime)),
                  const SizedBox(height: 14),
                  _row(ReceiptLine('Payment method', paymentMethod)),
                  for (final line in details) ...[
                    const SizedBox(height: 14),
                    _row(line),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 1,
                    child: CustomPaint(painter: const ReceiptDashedLine()),
                  ),
                  const SizedBox(height: 22),
                  for (final line in amountLines) ...[
                    _row(line),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 1,
                    child: CustomPaint(painter: const ReceiptDashedLine()),
                  ),
                  const SizedBox(height: 16),
                  _row(total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ReceiptLine line) {
    final big = line.emphasize;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.label,
          style: TextStyle(
            color: BybitPalette.muted2,
            fontSize: big ? 15 : 13.5,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            line.value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 19 : 14,
              fontWeight: big ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
