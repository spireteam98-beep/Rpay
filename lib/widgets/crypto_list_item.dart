import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/cryptocurrency.dart';
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            _buildCryptoIcon(),
            const SizedBox(width: 12),
            _buildNameAndTurnover(),
            _buildPriceInfo(),
            const SizedBox(width: 10),
            SizedBox(width: 78, child: Align(
              alignment: Alignment.centerRight,
              child: _buildChangePill(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoIcon() {
    final iconUrl = crypto.iconUrl;
    return Container(
      width: 38,
      height: 38,
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
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildNameAndTurnover() {
    return Expanded(
      flex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: crypto.symbol.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(
                  text: ' / USDT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BybitPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTurnover(crypto.volume24h),
            style: const TextStyle(
              fontSize: 12,
              color: BybitPalette.muted,
              letterSpacing: 0.1,
            ),
          ),
        ],
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
            crypto.formattedPrice.replaceFirst('\$', ''),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            crypto.formattedPrice,
            style: const TextStyle(
              fontSize: 12,
              color: BybitPalette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: crypto.isPriceUp ? BybitPalette.accent : BybitPalette.red,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        crypto.formattedPriceChange,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: crypto.isPriceUp ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  String _formatTurnover(double v) {
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
