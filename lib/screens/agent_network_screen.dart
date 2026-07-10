import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

const _tierLabels = {
  'SUPER_AGENT': 'Super Agent',
  'AGENT': 'Agent',
  'SUB_AGENT': 'Sub-Agent',
};

Color tierColor(String? tier) {
  switch (tier) {
    case 'SUPER_AGENT':
      return BybitPalette.accent;
    case 'SUB_AGENT':
      return BybitPalette.green;
    default:
      return BybitPalette.muted2;
  }
}

class TierBadge extends StatelessWidget {
  final String? tier;
  const TierBadge(this.tier, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _tierLabels[tier] ?? tier ?? '',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// An Agent/Super Agent's own recruited network — the Safaricom-style
/// aggregation tree: Super Agents recruit Agents, Agents recruit Sub-Agents,
/// each hop earning a 20% override on top of what the recruit earns.
class AgentNetworkScreen extends StatefulWidget {
  const AgentNetworkScreen({super.key});

  @override
  State<AgentNetworkScreen> createState() => _AgentNetworkScreenState();
}

class _AgentNetworkScreenState extends State<AgentNetworkScreen> {
  bool _loading = true;
  Map<String, dynamic>? _network;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final network = await ApiService.agentNetwork();
    if (!mounted) return;
    setState(() {
      _network = network;
      _loading = false;
    });
  }

  Future<void> _openRecruitSheet() async {
    final recruitTier = _network?['recruitTier'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _RecruitSheet(recruitTier: recruitTier, onRecruited: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('My network'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
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
                    children: _content(),
                  ),
                ),
      ),
    );
  }

  List<Widget> _content() {
    final network = _network;
    if (network == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Text(
            "Couldn't load your network.",
            style: TextStyle(color: BybitPalette.muted),
          ),
        ),
      ];
    }
    final recruits = (network['recruits'] as List?) ?? const [];
    final canRecruit = network['canRecruit'] as bool? ?? false;
    final recruitTier = network['recruitTier'] as String?;
    final overrideEarned =
        (network['overrideEarnedUsd'] as num?)?.toDouble() ?? 0;

    return [
      const Text(
        'Your network',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        canRecruit
            ? 'Recruit ${_tierLabels[recruitTier]?.toLowerCase() ?? 'partners'} under you — you earn a 20% override on everything they make.'
            : 'Sub-Agents sit at the bottom of the network and cannot recruit further.',
        style: const TextStyle(
          color: BybitPalette.muted2,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
      BybitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Override commission earned',
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '\$${overrideEarned.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (canRecruit) ...[
        BybitPrimaryButton(
          label: 'Recruit a ${_tierLabels[recruitTier] ?? 'partner'}',
          onTap: _openRecruitSheet,
        ),
        const SizedBox(height: 24),
      ],
      Text(
        'Your recruits (${recruits.length})',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 12),
      if (recruits.isEmpty)
        BybitCard(
          child: const Text(
            'No recruits yet.',
            style: TextStyle(color: BybitPalette.muted, fontSize: 13),
          ),
        )
      else
        ...recruits.map(
          (raw) => _recruitCard(Map<String, dynamic>.from(raw as Map)),
        ),
    ];
  }

  Widget _recruitCard(Map<String, dynamic> agent) {
    final status = agent['status'] as String? ?? 'PENDING';
    final statusColor =
        status == 'ACTIVE'
            ? BybitPalette.green
            : status == 'SUSPENDED'
            ? BybitPalette.red
            : BybitPalette.accent;
    final balance = (agent['commission_balance'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          agent['business_name'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TierBadge(agent['tier'] as String?),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${agent['owner_name'] ?? agent['owner_email'] ?? ''} · \$${balance.toStringAsFixed(2)} earned',
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecruitSheet extends StatefulWidget {
  final String? recruitTier;
  final Future<void> Function() onRecruited;
  const _RecruitSheet({required this.recruitTier, required this.onRecruited});

  @override
  State<_RecruitSheet> createState() => _RecruitSheetState();
}

class _RecruitSheetState extends State<_RecruitSheet> {
  final _identifierController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    final businessName = _businessNameController.text.trim();
    if (identifier.isEmpty || businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter the recruit's email/phone and a business name"),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.recruitSubordinate(
        identifier: identifier,
        businessName: businessName,
        phone: _phoneController.text.trim(),
      );
      await widget.onRecruited();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
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
          Text(
            'Recruit a ${_tierLabels[widget.recruitTier] ?? 'partner'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'They must already have a RoyallPay account. They go active immediately and start earning right away.',
            style: TextStyle(
              color: BybitPalette.muted2,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          BybitTextField(
            label: 'Their email or phone',
            hint: 'jane@example.com',
            icon: Icons.person_search_outlined,
            controller: _identifierController,
          ),
          const SizedBox(height: 14),
          BybitTextField(
            label: 'Business name',
            hint: 'e.g. Waberi Corner Shop',
            icon: Icons.storefront_rounded,
            controller: _businessNameController,
          ),
          const SizedBox(height: 14),
          BybitTextField(
            label: 'Phone (optional)',
            hint: '+254...',
            icon: Icons.phone_outlined,
            controller: _phoneController,
          ),
          const SizedBox(height: 22),
          BybitPrimaryButton(
            label: _submitting ? 'Recruiting...' : 'Recruit',
            enabled: !_submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
