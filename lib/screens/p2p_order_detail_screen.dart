import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

/// A single P2P order: payment instructions while waiting for the customer
/// to pay the agent, a proof-upload step, then live status once the agent
/// reviews it — the Binance-P2P style escrow flow for buying crypto with
/// mobile money via an Agent's float.
class P2pOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const P2pOrderDetailScreen({super.key, required this.orderId});

  @override
  State<P2pOrderDetailScreen> createState() => _P2pOrderDetailScreenState();
}

class _P2pOrderDetailScreenState extends State<P2pOrderDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _order;
  bool _uploading = false;
  bool _cancelling = false;
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final order = await ApiService.p2pOrder(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
    });
  }

  Future<void> _uploadProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      await ApiService.uploadP2pProof(
        orderId: widget.orderId,
        proofImageDataUrl: dataUrl,
        reference: _referenceController.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof submitted — the agent will review it shortly.'),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ApiService.cancelP2pOrder(widget.orderId);
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Order'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : _order == null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load this order.",
                      style: const TextStyle(color: BybitPalette.muted),
                    ),
                  ),
                )
                : RefreshIndicator(
                  color: BybitPalette.accent,
                  backgroundColor: BybitPalette.surface,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: _content(_order!),
                  ),
                ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'PENDING_PAYMENT';
    final asset = order['asset'] as String? ?? '';
    final cryptoAmount = (order['crypto_amount'] as num?)?.toDouble() ?? 0;
    final fiatAmount = (order['fiat_amount'] as num?)?.toDouble() ?? 0;
    final fiatCurrency = order['fiat_currency'] as String? ?? 'KES';
    final agentName = order['agent_name'] as String? ?? '';
    final agentCode = order['agent_code'] as String? ?? '';
    final agentPhone = order['agent_phone'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${cryptoAmount.toStringAsFixed(cryptoAmount < 1 ? 6 : 4)} $asset',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            _StatusPill(status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'for ${NumberFormat('#,##0.00').format(fiatAmount)} $fiatCurrency',
          style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (status == 'PENDING_PAYMENT' || status == 'REJECTED') ...[
          BybitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Send $fiatCurrency ${NumberFormat('#,##0.00').format(fiatAmount)} via mobile money to $agentName ($agentCode)${agentPhone != null && agentPhone.isNotEmpty ? ' — $agentPhone' : ''}, then upload your payment screenshot below.',
                  style: const TextStyle(
                    color: BybitPalette.muted2,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (agentPhone != null && agentPhone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TouchScale(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: agentPhone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Agent phone copied'),
                          backgroundColor: BybitPalette.surface2,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: BybitPalette.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              agentPhone,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.copy_rounded,
                            color: BybitPalette.accent,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status == 'REJECTED' &&
              (order['admin_note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BybitPalette.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Rejected: ${order['admin_note']}. You can upload new proof to retry.',
                style: const TextStyle(
                  color: BybitPalette.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          BybitTextField(
            label: 'MPESA reference (optional)',
            hint: 'e.g. QAB1C2D3E4',
            icon: Icons.confirmation_number_outlined,
            controller: _referenceController,
          ),
          const SizedBox(height: 16),
          BybitPrimaryButton(
            label: _uploading ? 'Uploading...' : "I've paid — upload proof",
            enabled: !_uploading,
            onTap: _uploadProof,
          ),
          const SizedBox(height: 12),
          TouchScale(
            onTap: _cancelling ? () {} : _cancel,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _cancelling ? 'Cancelling...' : 'Cancel order',
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ] else if (status == 'PROOF_SUBMITTED') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BybitPalette.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Proof submitted. Waiting for the agent to confirm receipt and release your crypto — pull to refresh for updates.',
              style: TextStyle(
                color: BybitPalette.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ] else if (status == 'RELEASED') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BybitPalette.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${cryptoAmount.toStringAsFixed(cryptoAmount < 1 ? 6 : 4)} $asset has been credited to your wallet.',
              style: const TextStyle(
                color: BybitPalette.green,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ] else if (status == 'CANCELLED') ...[
          BybitCard(
            child: const Text(
              'This order was cancelled.',
              style: TextStyle(color: BybitPalette.muted, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  Color get _color {
    switch (status) {
      case 'RELEASED':
        return BybitPalette.green;
      case 'REJECTED':
      case 'CANCELLED':
        return BybitPalette.red;
      default:
        return BybitPalette.accent;
    }
  }

  String get _label => status.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
