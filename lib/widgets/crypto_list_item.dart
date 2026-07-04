import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/cryptocurrency.dart';
import 'crypto_price_chart.dart';
import 'touch_scale.dart';

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
        decoration: AppTheme.glassCard,
        child: Row(
          children: [
            _buildCryptoIcon(),
            const SizedBox(width: 14),
            _buildCryptoInfo(),
            const SizedBox(width: 12),
            _buildPriceChart(),
            const SizedBox(width: 12),
            _buildPriceInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.cardLightBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: Center(
        child: Text(
          crypto.symbol.substring(0, 1),
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
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
            crypto.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppTheme.textWhite,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            crypto.symbol.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    return Expanded(
      flex: 3,
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
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  crypto.isPriceUp
                      ? AppTheme.priceUp.withOpacity(0.12)
                      : AppTheme.priceDown.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              crypto.formattedPriceChange,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: crypto.isPriceUp ? AppTheme.priceUp : AppTheme.priceDown,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
