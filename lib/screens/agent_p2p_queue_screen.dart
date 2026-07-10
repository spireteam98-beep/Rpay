import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';

/// Agent-side queue for P2P buy orders: review the customer's payment
/// screenshot, then confirm (release the crypto) or reject the order.
class AgentP2pQueueScreen extends StatefulWidget {
  const AgentP2pQueueScreen({super.key});

  @override
  State<AgentP2pQueueScreen> createState() => _AgentP2pQueueScreenState();
}

class _AgentP2pQueueScreenState extends State<AgentP2pQueueScreen> {
  bool _loading = true;
  List<dynamic> _orders = const [];
  String _filter = 'PROOF_SUBMITTED';

  static const _filters = ['PROOF_SUBMITTED', 'RELEASED', 'REJECTED', ''];
  static const _filterLabels = {
    'PROOF_SUBMITTED': 'Awaiting review',
    'RELEASED': 'Released',
    'REJECTED': 'Rejected',
    '': 'All',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await ApiService.assignedP2pOrders(
      status: _filter.isEmpty ? null : _filter,
    );
    if (!mounted) return;
    setState(() {
      _orders = orders ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('P2P orders'),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final value = _filters[index];
                  final selected = value == _filter;
                  return TouchScale(
                    onTap: () {
                      setState(() => _filter = value);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? BybitPalette.accent
                                : BybitPalette.surface2,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _filterLabels[value] ?? value,
                        style: TextStyle(
                          color: selected ? Colors.black : BybitPalette.muted2,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: BybitPalette.accent,
                        ),
                      )
                      : RefreshIndicator(
                        color: BybitPalette.accent,
                        backgroundColor: BybitPalette.surface,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                          children: [
                            if (_orders.isEmpty)
                              BybitCard(
                                child: Text(
                                  _filter == 'PROOF_SUBMITTED'
                                      ? 'No orders awaiting review right now.'
                                      : 'No orders match this filter.',
                                  style: const TextStyle(
                                    color: BybitPalette.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ..._orders.map(
                                (raw) => _orderCard(
                                  Map<String, dynamic>.from(raw as Map),
                                ),
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

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? '';
    final asset = order['asset'] as String? ?? '';
    final cryptoAmount = (order['crypto_amount'] as num?)?.toDouble() ?? 0;
    final fiatAmount = (order['fiat_amount'] as num?)?.toDouble() ?? 0;
    final fiatCurrency = order['fiat_currency'] as String? ?? 'KES';
    final customerName = order['customer_name'] as String? ?? 'Customer';
    final createdAt =
        DateTime.tryParse(order['created_at'] as String? ?? '') ??
        DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: () async {
          await Navigator.of(context).push(
            kashRoute(
              _AgentP2pOrderReviewScreen(orderId: order['id'] as String),
            ),
          );
          _load();
        },
        child: BybitCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cryptoAmount.toStringAsFixed(cryptoAmount < 1 ? 6 : 4)} $asset · $customerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${NumberFormat('#,##0.00').format(fiatAmount)} $fiatCurrency · ${DateFormat('MMM d, HH:mm').format(createdAt)}',
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: BybitPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: BybitPalette.accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentP2pOrderReviewScreen extends StatefulWidget {
  final String orderId;
  const _AgentP2pOrderReviewScreen({required this.orderId});

  @override
  State<_AgentP2pOrderReviewScreen> createState() =>
      _AgentP2pOrderReviewScreenState();
}

class _AgentP2pOrderReviewScreenState
    extends State<_AgentP2pOrderReviewScreen> {
  bool _loading = true;
  Map<String, dynamic>? _order;
  bool _acting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
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

  Uint8List? _decodeProof(String? dataUrl) {
    if (dataUrl == null || !dataUrl.contains(',')) return null;
    try {
      return base64Decode(dataUrl.split(',').last);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirm() async {
    setState(() => _acting = true);
    try {
      await ApiService.confirmP2pOrder(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crypto released to the customer.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _acting = true);
    try {
      await ApiService.rejectP2pOrder(
        widget.orderId,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Review order'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : _order == null
                ? const Center(
                  child: Text(
                    "Couldn't load this order.",
                    style: TextStyle(color: BybitPalette.muted),
                  ),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: _content(_order!),
                ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? '';
    final asset = order['asset'] as String? ?? '';
    final cryptoAmount = (order['crypto_amount'] as num?)?.toDouble() ?? 0;
    final fiatAmount = (order['fiat_amount'] as num?)?.toDouble() ?? 0;
    final fiatCurrency = order['fiat_currency'] as String? ?? 'KES';
    final customerName = order['customer_name'] as String? ?? 'Customer';
    final reference = order['payment_reference'] as String?;
    final proofBytes = _decodeProof(order['payment_proof'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 4),
        Text(
          'for ${NumberFormat('#,##0.00').format(fiatAmount)} $fiatCurrency from $customerName',
          style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (reference != null && reference.isNotEmpty)
          BybitInfoLine('Reference', reference),
        BybitInfoLine('Status', status.replaceAll('_', ' ')),
        const SizedBox(height: 20),
        const Text(
          'Payment proof',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (proofBytes == null)
          BybitCard(
            child: const Text(
              'No proof uploaded yet.',
              style: TextStyle(color: BybitPalette.muted, fontSize: 13),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              proofBytes,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
        const SizedBox(height: 24),
        if (status == 'PROOF_SUBMITTED') ...[
          BybitTextField(
            label: 'Rejection note (optional)',
            hint: 'e.g. amount does not match',
            icon: Icons.notes_outlined,
            controller: _noteController,
          ),
          const SizedBox(height: 16),
          BybitPrimaryButton(
            label: _acting ? 'Releasing...' : 'Confirm & release crypto',
            enabled: !_acting,
            onTap: _confirm,
          ),
          const SizedBox(height: 12),
          TouchScale(
            onTap: _acting ? () {} : _reject,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BybitPalette.red.withOpacity(0.14),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Reject order',
                style: TextStyle(
                  color: BybitPalette.red,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
