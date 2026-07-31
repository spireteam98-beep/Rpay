import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Agent-side queue for USD-sourced M-Pesa/Till payout requests (see
/// backend/src/routes/mobileMoney.js POST /withdrawals) — Paystack can't
/// reliably fund these since Stripe/Waafi money never reaches its balance,
/// so an agent sends the real M-Pesa/Till payment themselves, off-app,
/// using their own float, and marks it complete here for a commission.
class AgentMobileMoneyQueueScreen extends StatefulWidget {
  const AgentMobileMoneyQueueScreen({super.key});

  @override
  State<AgentMobileMoneyQueueScreen> createState() =>
      _AgentMobileMoneyQueueScreenState();
}

class _AgentMobileMoneyQueueScreenState
    extends State<AgentMobileMoneyQueueScreen> {
  bool _loading = true;
  List<dynamic> _queue = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final queue = await ApiService.mobileMoneyQueue();
    if (!mounted) return;
    setState(() {
      _queue = queue ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('M-Pesa/Till payouts'),
      body: SafeArea(
        child:
            _loading
                ? const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
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
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    children: [
                      const Text(
                        'Open requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Claim one, send the real M-Pesa/Till payment yourself, then mark it complete to earn your commission.',
                        style: TextStyle(
                          color: BybitPalette.muted2,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_queue.isEmpty)
                        BybitCard(
                          child: const Text(
                            'No payout requests right now.',
                            style: TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._queue.asMap().entries.map(
                          (entry) => StaggeredFadeIn(
                            index: entry.key,
                            child: _queueCard(
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

  Widget _queueCard(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final rail = item['rail'] as String? ?? 'M-Pesa';
    final isTill = rail == 'M-Pesa Till';
    final phone = item['phone'] as String? ?? '';
    final amountKes = (item['amount_kes'] as num?)?.toDouble() ?? 0;
    final commissionUsd = (item['agent_commission_usd'] as num?)?.toDouble() ?? 0;
    final status = item['status'] as String? ?? 'PENDING_AGENT';
    final claimedByMe = status == 'AGENT_CLAIMED';
    final createdAt =
        DateTime.tryParse(item['created_at'] as String? ?? '') ??
        DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: () async {
          await Navigator.of(context).push(
            kashRoute(
              _MobileMoneyPayoutDetailScreen(
                id: id,
                rail: rail,
                phone: phone,
                amountKes: amountKes,
                commissionUsd: commissionUsd,
                claimedByMe: claimedByMe,
              ),
            ),
          );
          _load();
        },
        child: BybitCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTill ? Icons.storefront_outlined : Icons.phone_iphone_rounded,
                  color: BybitPalette.accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTill ? 'Till $phone' : phone,
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
                      '${NumberFormat('#,##0.00').format(amountKes)} KES · ${DateFormat('MMM d, HH:mm').format(createdAt)}',
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      claimedByMe
                          ? BybitPalette.accent.withValues(alpha: 0.14)
                          : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  claimedByMe ? 'CLAIMED BY YOU' : 'OPEN',
                  style: TextStyle(
                    color: claimedByMe ? BybitPalette.accent : BybitPalette.muted2,
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

class _MobileMoneyPayoutDetailScreen extends StatefulWidget {
  final String id;
  final String rail;
  final String phone;
  final double amountKes;
  final double commissionUsd;
  final bool claimedByMe;

  const _MobileMoneyPayoutDetailScreen({
    required this.id,
    required this.rail,
    required this.phone,
    required this.amountKes,
    required this.commissionUsd,
    required this.claimedByMe,
  });

  @override
  State<_MobileMoneyPayoutDetailScreen> createState() =>
      _MobileMoneyPayoutDetailScreenState();
}

class _MobileMoneyPayoutDetailScreenState
    extends State<_MobileMoneyPayoutDetailScreen> {
  bool _acting = false;
  bool _claimed = false;
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _claimed = widget.claimedByMe;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() => _acting = true);
    try {
      await ApiService.claimMobileMoneyPayout(widget.id);
      if (!mounted) return;
      setState(() {
        _claimed = true;
        _acting = false;
      });
      BybitToast.success(context, 'Claimed — send the payment, then mark complete.');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _acting = false);
      BybitToast.error(context, err.message);
    }
  }

  Future<void> _release() async {
    setState(() => _acting = true);
    try {
      await ApiService.releaseMobileMoneyPayout(widget.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _acting = false);
      BybitToast.error(context, err.message);
    }
  }

  Future<void> _complete() async {
    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      BybitToast.error(context, 'Enter the M-Pesa confirmation code');
      return;
    }
    setState(() => _acting = true);
    try {
      await ApiService.completeMobileMoneyPayout(widget.id, reference: reference);
      if (!mounted) return;
      BybitToast.success(context, 'Marked complete — commission credited.');
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _acting = false);
      BybitToast.error(context, err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTill = widget.rail == 'M-Pesa Till';
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Payout request'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${NumberFormat('#,##0.00').format(widget.amountKes)} KES',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isTill ? 'To Till number ${widget.phone}' : 'To M-Pesa ${widget.phone}',
                style: const TextStyle(color: BybitPalette.muted2, fontSize: 14),
              ),
              const SizedBox(height: 20),
              BybitInfoLine('Your commission', '\$${widget.commissionUsd.toStringAsFixed(2)}'),
              const SizedBox(height: 24),
              if (!_claimed) ...[
                const Text(
                  'Claim this request, then send the real M-Pesa/Till payment yourself from your own float.',
                  style: TextStyle(color: BybitPalette.muted2, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                BybitPrimaryButton(
                  label: _acting ? 'Claiming...' : 'Claim this payout',
                  enabled: !_acting,
                  onTap: _claim,
                ),
              ] else ...[
                BybitTextField(
                  label: 'M-Pesa confirmation code',
                  hint: 'e.g. QGX7ABC123',
                  icon: Icons.confirmation_number_outlined,
                  controller: _referenceController,
                ),
                const SizedBox(height: 16),
                BybitPrimaryButton(
                  label: _acting ? 'Completing...' : 'Mark complete',
                  enabled: !_acting,
                  onTap: _complete,
                ),
                const SizedBox(height: 12),
                TouchScale(
                  onTap: _acting ? () {} : _release,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BybitPalette.red.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      "Can't fulfill — release it",
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
          ),
        ),
      ),
    );
  }
}
