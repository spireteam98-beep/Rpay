import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';
import 'usd_topup_order_detail_screen.dart';

/// Buy USD with real KES via a Wayaki agent — Binance-P2P style: pick an
/// agent's live rate, send them KES directly, upload proof, they release
/// the USD to your wallet once confirmed.
class BuyUsdScreen extends StatefulWidget {
  const BuyUsdScreen({super.key});

  @override
  State<BuyUsdScreen> createState() => _BuyUsdScreenState();
}

class _BuyUsdScreenState extends State<BuyUsdScreen> {
  bool _loading = true;
  List<dynamic> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await ApiService.myUsdTopupOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders ?? const [];
      _loading = false;
    });
  }

  Future<void> _openNewOrder() async {
    final orderId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _NewOrderSheet(),
    );
    if (orderId == null || !mounted) return;
    await Navigator.of(
      context,
    ).push(kashRoute(UsdTopupOrderDetailScreen(orderId: orderId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Buy USD via agent'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BybitPalette.accent,
        onPressed: _openNewOrder,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text(
          'New order',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child:
            _loading
                ? const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 100),
                  child: BybitSkeletonList(count: 3),
                )
                : RefreshIndicator(
                  color: BybitPalette.accent,
                  backgroundColor: BybitPalette.surface,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                    children: [
                      const Text(
                        'Buy USD with mobile money',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Send KES to a Wayaki agent, upload proof of payment, and they top up your USD wallet once confirmed.',
                        style: TextStyle(
                          color: BybitPalette.muted2,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Your orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_orders.isEmpty)
                        BybitCard(
                          child: const Text(
                            'No orders yet — tap "New order" to buy your first USD via an agent.',
                            style: TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._orders.asMap().entries.map(
                          (entry) => StaggeredFadeIn(
                            index: entry.key,
                            child: _orderCard(
                              Map<String, dynamic>.from(entry.value as Map),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'PENDING_PAYMENT';
    final amountUsd = (order['amount_usd'] as num?)?.toDouble() ?? 0;
    final amountKes = (order['amount_kes'] as num?)?.toDouble() ?? 0;
    final createdAt =
        DateTime.tryParse(order['created_at'] as String? ?? '') ??
        DateTime.now();
    final color =
        status == 'RELEASED'
            ? BybitPalette.green
            : (status == 'REJECTED' || status == 'CANCELLED')
            ? BybitPalette.red
            : BybitPalette.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap:
            () => Navigator.of(context).push(
              kashRoute(UsdTopupOrderDetailScreen(orderId: order['id'] as String)),
            ),
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
                  Icons.attach_money_rounded,
                  color: BybitPalette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${amountUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,##0.00').format(amountKes)} KES · ${DateFormat('MMM d, HH:mm').format(createdAt)}',
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: color,
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

class _NewOrderSheet extends StatefulWidget {
  const _NewOrderSheet();

  @override
  State<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends State<_NewOrderSheet> {
  final _amountController = TextEditingController();
  bool _loadingOffers = true;
  List<dynamic> _offers = const [];
  String? _offerId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    final result = await ApiService.usdTopupOffers();
    if (!mounted) return;
    setState(() {
      _offers = (result?['offers'] as List<dynamic>?) ?? const [];
      _offerId = _offers.isNotEmpty ? _offers.first['id'] as String : null;
      _loadingOffers = false;
    });
  }

  Map<String, dynamic>? get _selectedOffer =>
      _offers.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['id'] == _offerId,
        orElse: () => null,
      );

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      BybitToast.error(context, 'Enter a positive amount');
      return;
    }
    if (_offerId == null) {
      BybitToast.error(context, 'No agents are available right now');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.createUsdTopupOrder(
        agentFxOfferId: _offerId!,
        amountUsd: amount,
      );
      final orderId = (result['order'] as Map)['id'] as String;
      if (!mounted) return;
      Navigator.of(context).pop(orderId);
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _selectedOffer;
    final rate = (offer?['rate_kes_per_usd'] as num?)?.toDouble();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New buy order',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose an agent\'s rate and how much USD you want.',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text(
            'Agent rate',
            style: TextStyle(
              color: BybitPalette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _loadingOffers
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                ),
              )
              : _offers.isEmpty
              ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No agents are selling USD right now — check back later.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
                ),
              )
              : Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: BybitPalette.input,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _offerId,
                    dropdownColor: BybitPalette.surface2,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    items:
                        _offers
                            .map(
                              (raw) => DropdownMenuItem<String>(
                                value: raw['id'] as String,
                                child: Text(
                                  '${raw['business_name']} — ${raw['rate_kes_per_usd']} KES/USD',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _offerId = value),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          BybitTextField(
            label: 'Amount of USD to buy',
            hint: '0.00',
            icon: Icons.attach_money_rounded,
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (rate != null && amount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'You\'ll pay ${NumberFormat('#,##0.00').format(amount * rate)} KES',
              style: const TextStyle(
                color: BybitPalette.muted2,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          BybitPrimaryButton(
            label: _submitting ? 'Creating order...' : 'Create order',
            enabled: !_submitting && !_loadingOffers && _offers.isNotEmpty,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
