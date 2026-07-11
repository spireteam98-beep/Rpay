import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';
import 'p2p_order_detail_screen.dart';

const _p2pAssets = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'USDT'];

/// Buy crypto with mobile money via an Agent's float — Binance-P2P style:
/// pick an agent, send them KES/USD directly, upload proof, the agent
/// confirms and the crypto lands in the wallet.
class P2pBuyScreen extends StatefulWidget {
  const P2pBuyScreen({super.key});

  @override
  State<P2pBuyScreen> createState() => _P2pBuyScreenState();
}

class _P2pBuyScreenState extends State<P2pBuyScreen> {
  bool _loading = true;
  List<dynamic> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await ApiService.myP2pOrders();
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
    ).push(kashRoute(P2pOrderDetailScreen(orderId: orderId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Buy crypto via agent'),
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
                        'Buy with mobile money',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Send KES or USD to a RoyallPay agent, upload proof of payment, and they release the crypto to your wallet once confirmed.',
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
                            'No orders yet — tap "New order" to buy your first crypto via an agent.',
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
    final asset = order['asset'] as String? ?? '';
    final cryptoAmount = (order['crypto_amount'] as num?)?.toDouble() ?? 0;
    final fiatAmount = (order['fiat_amount'] as num?)?.toDouble() ?? 0;
    final fiatCurrency = order['fiat_currency'] as String? ?? 'KES';
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
              kashRoute(P2pOrderDetailScreen(orderId: order['id'] as String)),
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
                  Icons.currency_bitcoin_rounded,
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
                      '${cryptoAmount.toStringAsFixed(cryptoAmount < 1 ? 6 : 4)} $asset',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
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
  String _asset = 'USDT';
  String _fiatCurrency = 'KES';
  String? _agentId;
  bool _loadingAgents = true;
  List<dynamic> _agents = const [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    final agents = await ApiService.p2pAgents();
    if (!mounted) return;
    setState(() {
      _agents = agents ?? const [];
      _agentId = _agents.isNotEmpty ? _agents.first['id'] as String : null;
      _loadingAgents = false;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      BybitToast.error(context, 'Enter a positive amount');
      return;
    }
    if (_agentId == null) {
      BybitToast.error(context, 'No agents are available right now');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.createP2pOrder(
        agentId: _agentId!,
        asset: _asset,
        cryptoAmount: amount,
        fiatCurrency: _fiatCurrency,
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
            'Choose an asset and an agent to buy from.',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _label('Asset')),
              const SizedBox(width: 12),
              Expanded(child: _label('Pay with')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  _asset,
                  _p2pAssets,
                  (v) => setState(() => _asset = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(_fiatCurrency, const [
                  'KES',
                  'USD',
                ], (v) => setState(() => _fiatCurrency = v!)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BybitTextField(
            label: 'Amount of $_asset to buy',
            hint: '0.00',
            icon: Icons.currency_bitcoin_rounded,
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          _label('Agent'),
          const SizedBox(height: 8),
          _loadingAgents
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                ),
              )
              : _agents.isEmpty
              ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No active agents available right now — check back later.',
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
                    value: _agentId,
                    dropdownColor: BybitPalette.surface2,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    items:
                        _agents
                            .map(
                              (raw) => DropdownMenuItem<String>(
                                value: raw['id'] as String,
                                child: Text(
                                  '${raw['business_name']} (${raw['agent_code']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _agentId = value),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          BybitPrimaryButton(
            label: _submitting ? 'Creating order...' : 'Create order',
            enabled: !_submitting && !_loadingAgents && _agents.isNotEmpty,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: BybitPalette.muted,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _dropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: BybitPalette.input,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: BybitPalette.surface2,
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          items:
              options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Center(child: Text(o)),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
