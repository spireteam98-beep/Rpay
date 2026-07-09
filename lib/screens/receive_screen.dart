import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';

/// Real custody deposit address + QR code — the counterpart to Buy/Cash-in.
/// RoyallPay currently derives one ETH address per user (Sepolia testnet),
/// so unlike a multi-chain exchange there's no coin/network picker here;
/// showing a selector for assets that don't exist would just be decorative.
class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Receive crypto'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your deposit address',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Send ETH on Sepolia testnet to this address to fund your custody wallet.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FutureBuilder<Map<String, dynamic>?>(
                future: ApiService.walletSummary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                    );
                  }
                  final data = snapshot.data;
                  final address = data?['depositAddress'] as String?;
                  if (address == null || address.isEmpty) {
                    return GlassTile(
                      child: Text(
                        ApiService.hasSession
                            ? "Couldn't load your deposit address. Pull down to try again."
                            : 'Sign in to see your deposit address.',
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                      ),
                    );
                  }
                  final network = data?['network'] as String? ?? 'Sepolia testnet';
                  return _addressContent(context, address, network);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressContent(BuildContext context, String address, String network) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassTile(
          child: Row(
            children: [
              const CircleIcon(Icons.link_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      network,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.rCard),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: QrImageView(
              data: address,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Deposit address',
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TouchScale(
          onTap: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address copied'),
                backgroundColor: AppTheme.cardLightBackground,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardDarkBackground,
              borderRadius: BorderRadius.circular(AppTheme.rInput),
              border: Border.all(color: AppTheme.glassStroke),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: AppTheme.textLightGrey,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, color: AppTheme.primaryColor, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GlassTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Before you send',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              _InfoLine('Send only ETH, and only on Sepolia testnet — assets on other networks or mainnet ETH cannot be recovered.'),
              _InfoLine('This is a testnet address. Testnet ETH has no real-world value.'),
              _InfoLine('Deposits appear once the transaction is confirmed on-chain.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String text;
  const _InfoLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '•  $text',
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 12.5, height: 1.4),
      ),
    );
  }
}
