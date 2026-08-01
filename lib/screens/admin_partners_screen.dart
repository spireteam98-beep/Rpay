import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';
import 'agent_network_screen.dart' show TierBadge;

/// Admin control surface for the partner network: create Agents and
/// Merchants, approve or deactivate them, and see agent commission totals.
class AdminPartnersScreen extends StatefulWidget {
  const AdminPartnersScreen({super.key});

  @override
  State<AdminPartnersScreen> createState() => _AdminPartnersScreenState();
}

class _AdminPartnersScreenState extends State<AdminPartnersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: AppBar(
        backgroundColor: BybitPalette.bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Agents & Merchants',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BybitPalette.accent,
          labelColor: Colors.white,
          unselectedLabelColor: BybitPalette.muted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
          tabs: const [Tab(text: 'Agents'), Tab(text: 'Merchants')],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: const [_AgentsTab(), _MerchantsTab()],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'ACTIVE':
      return BybitPalette.green;
    case 'SUSPENDED':
      return BybitPalette.red;
    default:
      return BybitPalette.accent;
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterChips({required this.value, required this.onChanged});

  static const _options = ['', 'PENDING', 'ACTIVE', 'SUSPENDED'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _options[index];
          final selected = option == value;
          final label =
              option.isEmpty
                  ? 'All'
                  : option[0] + option.substring(1).toLowerCase();
          return TouchScale(
            onTap: () => onChanged(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? BybitPalette.accent : BybitPalette.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                label,
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
    );
  }
}

// ── Agents tab ──────────────────────────────────────────────────────

class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  bool _loading = true;
  List<dynamic> _agents = const [];
  Map<String, dynamic>? _summary;
  String _filter = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.adminAgents(status: _filter.isEmpty ? null : _filter),
      ApiService.adminCommissionSummary(),
    ]);
    if (!mounted) return;
    setState(() {
      _agents = results[0] as List<dynamic>? ?? const [];
      _summary = results[1] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _act(String agentId, Future<void> Function() action) async {
    setState(() => _busy.add(agentId));
    try {
      await action();
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _busy.remove(agentId));
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateAgentSheet(onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: BybitPalette.accent,
        onPressed: _openCreateSheet,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: RefreshIndicator(
        color: BybitPalette.accent,
        backgroundColor: BybitPalette.surface,
        onRefresh: _load,
        child:
            _loading
                ? const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 90),
                  child: BybitSkeletonList(count: 3),
                )
                : ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                  children: [
                    if (_summary != null) _summaryCard(_summary!),
                    const SizedBox(height: 16),
                    _FilterChips(
                      value: _filter,
                      onChanged: (v) {
                        setState(() => _filter = v);
                        _load();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_agents.isEmpty)
                      BybitCard(
                        child: const Text(
                          'No agents match this filter.',
                          style: TextStyle(
                            color: BybitPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ..._agents.asMap().entries.map(
                        (entry) => StaggeredFadeIn(
                          index: entry.key,
                          child: _agentCard(
                            Map<String, dynamic>.from(entry.value as Map),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _summaryCard(Map<String, dynamic> summary) {
    final liability = (summary['totalLiabilityUsd'] as num?)?.toDouble() ?? 0;
    final activeCount = summary['activeAgentCount'] as int? ?? 0;
    return Row(
      children: [
        Expanded(
          child: BybitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commission liability',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${liability.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BybitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active agents',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '$activeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openApproveSheet(Map<String, dynamic> agent) async {
    final id = agent['id'] as String;
    final result = await showModalBottomSheet<_ProductChoice>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _ProductsSheet(
            title: 'Approve ${agent['business_name'] ?? 'agent'}',
            subtitle: 'Choose which products they\'re approved to operate.',
            confirmLabel: 'Approve',
            initialKes: agent['wants_provide_kes'] == true,
            initialUsd: agent['wants_provide_usd'] == true,
          ),
    );
    if (result == null) return;
    await _act(
      id,
      () => ApiService.adminApproveAgent(
        id,
        canProvideKes: result.kes,
        canProvideUsd: result.usd,
      ),
    );
  }

  Future<void> _openCapabilitiesSheet(Map<String, dynamic> agent) async {
    final id = agent['id'] as String;
    final result = await showModalBottomSheet<_ProductChoice>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _ProductsSheet(
            title: 'Edit products',
            subtitle: 'Grant or revoke what this agent can operate.',
            confirmLabel: 'Save',
            initialKes: agent['can_provide_kes'] == true,
            initialUsd: agent['can_provide_usd'] == true,
          ),
    );
    if (result == null) return;
    await _act(
      id,
      () => ApiService.adminSetAgentCapabilities(
        id,
        canProvideKes: result.kes,
        canProvideUsd: result.usd,
      ),
    );
  }

  Widget _agentCard(Map<String, dynamic> agent) {
    final id = agent['id'] as String;
    final status = agent['status'] as String? ?? 'PENDING';
    final tier = agent['tier'] as String? ?? 'AGENT';
    final parentName = agent['parent_name'] as String?;
    final busy = _busy.contains(id);
    final commission = (agent['commission_balance'] as num?)?.toDouble() ?? 0;
    final wantsKes = agent['wants_provide_kes'] == true;
    final wantsUsd = agent['wants_provide_usd'] == true;
    final canKes = agent['can_provide_kes'] == true;
    final canUsd = agent['can_provide_usd'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TierBadge(tier),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${agent['agent_code']} · ${agent['owner_name'] ?? agent['owner_email'] ?? ''}',
                        style: const TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (parentName != null && parentName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reports to $parentName',
                          style: const TextStyle(
                            color: BybitPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _productChip('KES', status == 'ACTIVE' ? canKes : wantsKes),
                _productChip('USD', status == 'ACTIVE' ? canUsd : wantsUsd),
              ],
            ),
            const SizedBox(height: 10),
            BybitInfoLine(
              'Commission earned',
              '\$${commission.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status != 'ACTIVE')
                  Expanded(
                    child: _actionButton(
                      'Approve',
                      BybitPalette.green,
                      busy,
                      () => _openApproveSheet(agent),
                    ),
                  ),
                if (status != 'ACTIVE') const SizedBox(width: 10),
                if (status != 'SUSPENDED')
                  Expanded(
                    child: _actionButton(
                      'Deactivate',
                      BybitPalette.red,
                      busy,
                      () => _act(id, () => ApiService.adminDeactivateAgent(id)),
                    ),
                  ),
              ],
            ),
            if (status == 'ACTIVE') ...[
              const SizedBox(height: 10),
              _actionButton(
                'Edit products',
                BybitPalette.accent,
                busy,
                () => _openCapabilitiesSheet(agent),
              ),
            ],
            if (tier == 'AGENT') ...[
              const SizedBox(height: 10),
              _actionButton(
                'Promote to Super Agent',
                BybitPalette.accent,
                busy,
                () => _act(
                  id,
                  () => ApiService.adminSetAgentTier(id, tier: 'SUPER_AGENT'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _productChip(String label, bool enabled) {
    final color = enabled ? BybitPalette.green : BybitPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    bool busy,
    VoidCallback onTap,
  ) {
    return TouchScale(
      onTap: busy ? () {} : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            busy
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BybitPalette.accent,
                  ),
                )
                : Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
      ),
    );
  }
}

class _ProductChoice {
  final bool kes;
  final bool usd;
  const _ProductChoice({required this.kes, required this.usd});
}

/// Checkbox sheet for granting/revoking the two FX-marketplace products —
/// used both at approval time and for editing an already-active agent.
/// Approving an agent without deciding what they're allowed to sell doesn't
/// make sense, so this is always shown rather than defaulted silently.
class _ProductsSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final bool initialKes;
  final bool initialUsd;

  const _ProductsSheet({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.initialKes,
    required this.initialUsd,
  });

  @override
  State<_ProductsSheet> createState() => _ProductsSheetState();
}

class _ProductsSheetState extends State<_ProductsSheet> {
  late bool _kes = widget.initialKes;
  late bool _usd = widget.initialUsd;

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
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _checkRow(
            'Provide KES',
            'Customer pays USD, agent sends real M-Pesa/Till KES',
            _kes,
            (v) => setState(() => _kes = v),
          ),
          const SizedBox(height: 10),
          _checkRow(
            'Provide USD',
            'Customer pays real KES, agent tops up their USD wallet',
            _usd,
            (v) => setState(() => _usd = v),
          ),
          const SizedBox(height: 22),
          BybitPrimaryButton(
            label: widget.confirmLabel,
            onTap:
                () => Navigator.of(
                  context,
                ).pop(_ProductChoice(kes: _kes, usd: _usd)),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return TouchScale(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BybitPalette.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? BybitPalette.accent : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: value ? BybitPalette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? BybitPalette.accent : BybitPalette.muted,
                  width: 1.5,
                ),
              ),
              child:
                  value
                      ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAgentSheet extends StatefulWidget {
  final Future<void> Function() onCreated;
  const _CreateAgentSheet({required this.onCreated});

  @override
  State<_CreateAgentSheet> createState() => _CreateAgentSheetState();
}

class _CreateAgentSheetState extends State<_CreateAgentSheet> {
  final _identifierController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String _tier = 'AGENT';
  String? _parentAgentId;
  bool _loadingSuperAgents = true;
  List<dynamic> _superAgents = const [];

  @override
  void initState() {
    super.initState();
    _loadSuperAgents();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSuperAgents() async {
    final agents = await ApiService.adminAgents(tier: 'SUPER_AGENT');
    if (!mounted) return;
    setState(() {
      _superAgents = agents ?? const [];
      _loadingSuperAgents = false;
    });
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    final businessName = _businessNameController.text.trim();
    if (identifier.isEmpty || businessName.isEmpty) {
      BybitToast.error(
        context,
        "Enter the user's email/phone and a business name",
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.adminCreateAgent(
        identifier: identifier,
        businessName: businessName,
        phone: _phoneController.text.trim(),
        tier: _tier,
        parentAgentId: _tier == 'AGENT' ? _parentAgentId : null,
      );
      await widget.onCreated();
      if (!mounted) return;
      Navigator.of(context).pop();
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
            'Create agent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Onboard an existing Wayaki user as a pre-approved agent.',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          BybitTextField(
            label: 'User email or phone',
            hint: 'jane@example.com',
            icon: Icons.person_search_outlined,
            controller: _identifierController,
          ),
          const SizedBox(height: 14),
          BybitTextField(
            label: 'Business name',
            hint: 'e.g. Waberi Agency',
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
          const SizedBox(height: 16),
          const Text(
            'Tier',
            style: TextStyle(
              color: BybitPalette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: BybitPalette.input,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tier,
                dropdownColor: BybitPalette.surface2,
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                items: const [
                  DropdownMenuItem(value: 'AGENT', child: Text('Agent')),
                  DropdownMenuItem(
                    value: 'SUPER_AGENT',
                    child: Text('Super Agent (dealer / country / area lead)'),
                  ),
                ],
                onChanged: (v) => setState(() => _tier = v ?? 'AGENT'),
              ),
            ),
          ),
          if (_tier == 'AGENT' &&
              !_loadingSuperAgents &&
              _superAgents.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Reports to (optional)',
              style: TextStyle(
                color: BybitPalette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: BybitPalette.input,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _parentAgentId,
                  dropdownColor: BybitPalette.surface2,
                  isExpanded: true,
                  hint: const Text(
                    'No Super Agent',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 13),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No Super Agent'),
                    ),
                    ..._superAgents.map(
                      (raw) => DropdownMenuItem<String?>(
                        value: raw['id'] as String,
                        child: Text(
                          '${raw['business_name']} (${raw['agent_code']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _parentAgentId = v),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          BybitPrimaryButton(
            label: _submitting ? 'Creating...' : 'Create agent',
            enabled: !_submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ── Merchants tab ───────────────────────────────────────────────────

class _MerchantsTab extends StatefulWidget {
  const _MerchantsTab();

  @override
  State<_MerchantsTab> createState() => _MerchantsTabState();
}

class _MerchantsTabState extends State<_MerchantsTab> {
  bool _loading = true;
  List<dynamic> _merchants = const [];
  String _filter = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ApiService.adminMerchants(
      status: _filter.isEmpty ? null : _filter,
    );
    if (!mounted) return;
    setState(() {
      _merchants = list ?? const [];
      _loading = false;
    });
  }

  Future<void> _act(String merchantId, Future<void> Function() action) async {
    setState(() => _busy.add(merchantId));
    try {
      await action();
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      BybitToast.error(context, err.message);
    } finally {
      if (mounted) setState(() => _busy.remove(merchantId));
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BybitPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateMerchantSheet(onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: BybitPalette.accent,
        onPressed: _openCreateSheet,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: RefreshIndicator(
        color: BybitPalette.accent,
        backgroundColor: BybitPalette.surface,
        onRefresh: _load,
        child:
            _loading
                ? const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 90),
                  child: BybitSkeletonList(count: 3),
                )
                : ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                  children: [
                    _FilterChips(
                      value: _filter,
                      onChanged: (v) {
                        setState(() => _filter = v);
                        _load();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_merchants.isEmpty)
                      BybitCard(
                        child: const Text(
                          'No merchants match this filter.',
                          style: TextStyle(
                            color: BybitPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ..._merchants.asMap().entries.map(
                        (entry) => StaggeredFadeIn(
                          index: entry.key,
                          child: _merchantCard(
                            Map<String, dynamic>.from(entry.value as Map),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _merchantCard(Map<String, dynamic> merchant) {
    final id = merchant['id'] as String;
    final status = merchant['status'] as String? ?? 'PENDING';
    final busy = _busy.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BybitCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant['name'] as String? ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Till ${merchant['till_number']} · ${merchant['owner_name'] ?? merchant['owner_email'] ?? ''}',
                        style: const TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status != 'ACTIVE')
                  Expanded(
                    child: _actionButton(
                      'Approve',
                      BybitPalette.green,
                      busy,
                      () => _act(id, () => ApiService.adminApproveMerchant(id)),
                    ),
                  ),
                if (status != 'ACTIVE') const SizedBox(width: 10),
                if (status != 'SUSPENDED')
                  Expanded(
                    child: _actionButton(
                      'Deactivate',
                      BybitPalette.red,
                      busy,
                      () => _act(
                        id,
                        () => ApiService.adminDeactivateMerchant(id),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    bool busy,
    VoidCallback onTap,
  ) {
    return TouchScale(
      onTap: busy ? () {} : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            busy
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BybitPalette.accent,
                  ),
                )
                : Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
      ),
    );
  }
}

class _CreateMerchantSheet extends StatefulWidget {
  final Future<void> Function() onCreated;
  const _CreateMerchantSheet({required this.onCreated});

  @override
  State<_CreateMerchantSheet> createState() => _CreateMerchantSheetState();
}

class _CreateMerchantSheetState extends State<_CreateMerchantSheet> {
  final _identifierController = TextEditingController();
  final _nameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    final name = _nameController.text.trim();
    if (identifier.isEmpty || name.isEmpty) {
      BybitToast.error(
        context,
        "Enter the user's email/phone and a business name",
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.adminCreateMerchant(
        identifier: identifier,
        name: name,
        businessType: _businessTypeController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      await widget.onCreated();
      if (!mounted) return;
      Navigator.of(context).pop();
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
            'Create merchant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Onboard an existing Wayaki user as a pre-approved merchant.',
            style: TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          BybitTextField(
            label: 'User email or phone',
            hint: 'jane@example.com',
            icon: Icons.person_search_outlined,
            controller: _identifierController,
          ),
          const SizedBox(height: 14),
          BybitTextField(
            label: 'Business name',
            hint: 'e.g. Waberi Electronics',
            icon: Icons.storefront_rounded,
            controller: _nameController,
          ),
          const SizedBox(height: 14),
          BybitTextField(
            label: 'Business type (optional)',
            hint: 'e.g. Retail, Restaurant',
            icon: Icons.category_outlined,
            controller: _businessTypeController,
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
            label: _submitting ? 'Creating...' : 'Create merchant',
            enabled: !_submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
