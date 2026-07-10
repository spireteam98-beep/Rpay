import 'package:flutter/material.dart';
import 'bybit_wallet_ui.dart';

/// Decorative "live" card visual shown above the split card-number/expiry/
/// CVC fields — mirrors what the user is filling in below (holder name,
/// detected network, whether expiry/CVC are complete) without ever touching
/// the raw card number, which stays inside Stripe's PCI-hosted iframes and
/// never reaches Dart.
class CardPreview extends StatelessWidget {
  final String holderName;
  final String brand;
  final bool numberComplete;
  final bool expiryComplete;

  const CardPreview({
    super.key,
    required this.holderName,
    required this.brand,
    required this.numberComplete,
    required this.expiryComplete,
  });

  String get _brandLabel {
    switch (brand) {
      case 'visa':
        return 'VISA';
      case 'mastercard':
        return 'MASTERCARD';
      case 'amex':
        return 'AMEX';
      case 'discover':
        return 'DISCOVER';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        holderName.trim().isEmpty
            ? 'YOUR NAME'
            : holderName.trim().toUpperCase();
    final complete = numberComplete && expiryComplete;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2027), BybitPalette.bg],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: BybitPalette.accent.withOpacity(complete ? 0.55 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: BybitPalette.accent.withOpacity(complete ? 0.18 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE9A8), Color(0xFFE0B45C)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.wifi_rounded,
                    color: Colors.white.withOpacity(0.55),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _brandLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Text(
            '••••  ••••  ••••  ••••',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARD HOLDER',
                      style: TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiryComplete ? '••/••' : 'MM/YY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
