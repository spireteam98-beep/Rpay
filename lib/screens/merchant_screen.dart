import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Business onboarding + the merchant's till number, QR code and recent
/// payments received — the software side of merchant payment acceptance.
/// (Physical POS terminal distribution is a hardware/ops process outside
/// this app; the QR code below already works as a software POS: any
/// RoyallPay user pays it straight from their wallet.)
class MerchantScreen extends StatefulWidget {
  const MerchantScreen({super.key});

  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> {
  bool _loading = true;
  Map<String, dynamic>? _merchant;
  final _nameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ApiService.myMerchants();
    if (!mounted) return;
    setState(() {
      _merchant =
          (list != null && list.isNotEmpty)
              ? Map<String, dynamic>.from(list.first as Map)
              : null;
      _loading = false;
    });
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      BybitToast.error(context, 'Enter your business name');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.registerMerchant(
        name: name,
        businessType: _businessTypeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _merchant = Map<String, dynamic>.from(result['merchant'] as Map);
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Merchant'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child:
                      _merchant == null
                          ? _onboarding()
                          : _dashboard(_merchant!),
                ),
      ),
    );
  }

  Widget _onboarding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Become a merchant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Register your business to get a till number, a QR code, and a business account for receiving payments.',
          style: TextStyle(
            color: BybitPalette.muted2,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        BybitTextField(
          label: 'Business name',
          hint: 'e.g. Waberi Electronics',
          icon: Icons.storefront_rounded,
          controller: _nameController,
        ),
        const SizedBox(height: 16),
        BybitTextField(
          label: 'Business type (optional)',
          hint: 'e.g. Retail, Restaurant, Services',
          icon: Icons.category_outlined,
          controller: _businessTypeController,
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(
          label: _submitting ? 'Registering...' : 'Register business',
          enabled: !_submitting,
          onTap: _register,
        ),
      ],
    );
  }

  Widget _dashboard(Map<String, dynamic> merchant) {
    final till = merchant['till_number'] as String? ?? '';
    final name = merchant['name'] as String? ?? '';
    final status = merchant['status'] as String? ?? 'PENDING';
    final isActive = status == 'ACTIVE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Share your QR or till number to get paid instantly.',
          style: TextStyle(color: BybitPalette.muted2, fontSize: 14),
        ),
        if (!isActive) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (status == 'SUSPENDED'
                      ? BybitPalette.red
                      : BybitPalette.accent)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              status == 'SUSPENDED'
                  ? 'Your merchant account has been deactivated by an admin. Contact support for help.'
                  : 'Your merchant account is pending admin approval. Your till cannot receive payments until approved.',
              style: TextStyle(
                color:
                    status == 'SUSPENDED'
                        ? BybitPalette.red
                        : BybitPalette.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
              data: 'royallpay:pay?till=$till',
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Till / merchant number',
          style: TextStyle(
            color: BybitPalette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TouchScale(
          onTap: () {
            Clipboard.setData(ClipboardData(text: till));
            BybitToast.show(context, 'Till number copied');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: BybitPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF242832)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    till,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.copy_rounded,
                  color: BybitPalette.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Recent payments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<dynamic>?>(
          future: ApiService.merchantPayments(merchant['id'] as String),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const BybitSkeletonList(count: 3);
            }
            final payments = snapshot.data ?? const [];
            if (payments.isEmpty) {
              return BybitCard(
                child: const Text(
                  'No payments yet — share your QR or till number to start receiving.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 13),
                ),
              );
            }
            return Column(
              children:
                  payments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final payment = Map<String, dynamic>.from(
                      entry.value as Map,
                    );
                    final payer =
                        payment['payer_name'] as String? ?? 'Customer';
                    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
                    final currency = payment['currency'] as String? ?? 'USD';
                    final createdAt =
                        DateTime.tryParse(
                          payment['created_at'] as String? ?? '',
                        ) ??
                        DateTime.now();
                    return StaggeredFadeIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BybitCard(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: BybitPalette.surface2,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.south_west_rounded,
                                  color: BybitPalette.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payer,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'MMM d, HH:mm',
                                      ).format(createdAt),
                                      style: const TextStyle(
                                        color: BybitPalette.muted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${amount.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  color: BybitPalette.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }
}
