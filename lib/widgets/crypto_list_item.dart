import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/cryptocurrency.dart';
import 'crypto_price_chart.dart';
import 'touch_scale.dart';
import 'bybit_wallet_ui.dart';

class CryptoListItem extends StatelessWidget {
  final Cryptocurrency crypto;
  final VoidCallback onTap;

  const CryptoListItem({Key? key, required this.crypto, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _buildCryptoIcon(),
            const SizedBox(width: 12),
            _buildCryptoInfo(),
            const SizedBox(width: 8),
            _buildPriceChart(),
            const SizedBox(width: 8),
            _buildPriceInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoIcon() {
    final iconUrl = crypto.iconUrl;
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: BybitPalette.surface2,
        shape: BoxShape.circle,
      ),
      child: (iconUrl == null || iconUrl.isEmpty)
          ? _fallbackIcon()
          : CachedNetworkImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallbackIcon(),
              errorWidget: (_, __, ___) => _fallbackIcon(),
            ),
    );
  }

  Widget _fallbackIcon() {
    return Center(
      child: Text(
        crypto.symbol.isEmpty ? '?' : crypto.symbol.substring(0, 1),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCryptoInfo() {
    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${crypto.symbol.toUpperCase()}/USDT',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            crypto.name,
            style: const TextStyle(
              fontSize: 12,
              color: BybitPalette.muted2,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    return Expanded(
      flex: 2,
      child: SizedBox(
        height: 40,
        child: CryptoPriceChart(crypto: crypto, height: 40),
      ),
    );
  }

  Widget _buildPriceInfo() {
    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            crypto.formattedPrice,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color:
                  crypto.isPriceUp
                      ? BybitPalette.green.withOpacity(0.12)
                      : BybitPalette.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  crypto.isPriceUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: crypto.isPriceUp ? BybitPalette.green : BybitPalette.red,
                ),
                const SizedBox(width: 2),
                Text(
                  crypto.formattedPriceChange,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: crypto.isPriceUp ? BybitPalette.green : BybitPalette.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
