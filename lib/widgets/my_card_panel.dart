import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'touch_scale.dart';

/// The user's own Fareenn card, shown full width on the wallet dashboard:
/// a second card peeking behind, the front card with the card balance,
/// and Swap / Freeze / Send / Receive buttons underneath.
class MyCardPanel extends StatefulWidget {
  final String holderName;
  final String balanceText;
  final String last4;
  final String expiry;
  final bool active; // KYC complete
  final String? walletNumber; // issued on KYC approval
  final String? kycStatus; // PENDING_REVIEW / APPROVED / REJECTED
  final String? kycRejectReason;
  final bool frozen;
  final bool hideBalance;
  final VoidCallback onSwap;
  final VoidCallback onFreeze;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onActivate;

  const MyCardPanel({
    super.key,
    required this.holderName,
    required this.balanceText,
    required this.last4,
    required this.expiry,
    required this.active,
    this.walletNumber,
    this.kycStatus,
    this.kycRejectReason,
    required this.frozen,
    required this.hideBalance,
    required this.onSwap,
    required this.onFreeze,
    required this.onSend,
    required this.onReceive,
    required this.onActivate,
  });

  @override
  State<MyCardPanel> createState() => _MyCardPanelState();
}

class _MyCardPanelState extends State<MyCardPanel> {
  bool _manageOpen = false;

  String get holderName => widget.holderName;
  String get balanceText => widget.balanceText;
  String get last4 => widget.last4;
  String get expiry => widget.expiry;
  bool get active => widget.active;
  bool get frozen => widget.frozen;
  bool get hideBalance => widget.hideBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AspectRatio(
            aspectRatio: 1.48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Back card peeking out above the front one.
                Positioned(
                  left: 22,
                  right: 22,
                  top: 0,
                  bottom: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A0A0D), Color(0xFF141414)],
                      ),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 18,
                  bottom: 0,
                  child: _front(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _front() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // Red top with fine flowing lines.
              Expanded(
                flex: 70,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE60000), Color(0xFFB30000)],
                    ),
                  ),
                  child: CustomPaint(
                    painter: const _WavesPainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/fareenn_wordmark_plain.png',
                                height: 24,
                                filterQuality: FilterQuality.high,
                              ),
                              const Spacer(),
                              _manageToggle(),
                              const SizedBox(width: 10),
                              Image.asset(
                                'assets/images/mastercard.png',
                                height: 26,
                                filterQuality: FilterQuality.high,
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Card balance',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    hideBalance ? r'$ ••••••' : balanceText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.contactless_outlined,
                                color: Colors.white,
                                size: 30,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Light bottom band with the card details.
              Expanded(
                flex: 30,
                child: Container(
                  color: const Color(0xFFF7EDED),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expiry,
                              style: const TextStyle(
                                color: Color(0xFF2A0A0D),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              holderName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        (widget.walletNumber?.isNotEmpty ?? false)
                            ? 'ID ${widget.walletNumber}'
                            : '•••• $last4',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (active && frozen)
            Container(
              color: const Color(0x99FFFFFF),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ac_unit_rounded, color: Color(0xFF1A1A1A)),
                  SizedBox(width: 8),
                  Text(
                    'Card frozen',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          if (!active)
            Container(
              color: const Color(0xB3000000),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    widget.kycStatus == 'PENDING_REVIEW'
                        ? 'Your application is under review. Your card will '
                            'be activated once verification is complete.'
                        : widget.kycStatus == 'REJECTED'
                            ? 'Verification unsuccessful: ${widget.kycRejectReason ?? 'please update your details'}'
                            : 'Verify your identity to activate your card',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.kycStatus != 'PENDING_REVIEW') ...[
                  const SizedBox(height: 12),
                  TouchScale(
                    onTap: widget.onActivate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE60000),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        widget.kycStatus == 'REJECTED' ? 'Update details' : 'Complete KYC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          // Card management opens right on the card as a frosted glass
          // panel, so it is clear these controls belong to this card.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_manageOpen,
              child: AnimatedOpacity(
                opacity: _manageOpen ? 1 : 0,
                duration: const Duration(milliseconds: 240),
                child: AnimatedScale(
                  scale: _manageOpen ? 1 : 1.04,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _managePanel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managePanel() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xB31A1A1A), Color(0x99000000)],
          ),
          border: Border.all(color: const Color(0x33FFFFFF)),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Manage card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•••• $last4',
                  style: const TextStyle(
                    color: Color(0xFFBDBDC2),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TouchScale(
                  onTap: () => setState(() => _manageOpen = false),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x1FFFFFFF),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _action(Icons.swap_horiz_rounded, 'Swap', () {
                    setState(() => _manageOpen = false);
                    widget.onSwap();
                  }),
                ),
                Expanded(
                  child: _action(
                    frozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    frozen ? 'Unfreeze' : 'Freeze',
                    active ? widget.onFreeze : widget.onActivate,
                  ),
                ),
                Expanded(
                  child: _action(Icons.north_east_rounded, 'Send', () {
                    setState(() => _manageOpen = false);
                    widget.onSend();
                  }),
                ),
                Expanded(
                  child: _action(Icons.south_west_rounded, 'Receive', () {
                    setState(() => _manageOpen = false);
                    widget.onReceive();
                  }),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _manageToggle() {
    return TouchScale(
      onTap: () => setState(() => _manageOpen = true),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: _manageOpen ? Colors.white : const Color(0x33000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage',
              style: TextStyle(
                color: _manageOpen ? const Color(0xFFB30000) : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            AnimatedRotation(
              turns: _manageOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _manageOpen ? const Color(0xFFB30000) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Center(
      child: TouchScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x1FFFFFFF),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fine, flowing guilloche-style lines across the red part of the card.
class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x24FFFFFF);
    for (var k = 0; k < 14; k++) {
      final path = Path();
      final amp = 10 + k * 1.6;
      final yBase = size.height * 0.15 + k * size.height * 0.05;
      for (var x = 0.0; x <= size.width; x += 4) {
        final y = yBase +
            amp * math.sin(x / size.width * math.pi * 2 + k * 0.35) +
            x * 0.12;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
