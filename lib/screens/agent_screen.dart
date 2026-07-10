import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

/// Agent hub: onboard as an agent, share a referral code that onboards new
/// customers, and assist walk-in customers with cash deposits/withdrawals —
/// earning commission on both.
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  bool _loading = true;
  Map<String, dynamic>? _agent;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final agent = await ApiService.myAgent();
    if (!mounted) return;
    setState(() {
      _agent = agent;
      _loading = false;
    });
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your business name')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.registerAgent(
        businessName: name,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _agent = Map<String, dynamic>.from(result['agent'] as Map);
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _assist({required bool isDeposit}) async {
    final result = await showModalBottomSheet<_AssistResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AssistSheet(isDeposit: isDeposit),
    );
    if (result == null || !mounted) return;

    try {
      final response =
          isDeposit
              ? await ApiService.agentAssistedDeposit(
                customer: result.customer,
                currency: result.currency,
                amount: result.amount,
              )
              : await ApiService.agentAssistedWithdrawal(
                customer: result.customer,
                currency: result.currency,
                amount: result.amount,
              );
      if (!mounted) return;
      final customerName =
          (response[isDeposit ? 'credited' : 'debited'] as Map)['customerName']
              as String? ??
          'customer';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeposit
                ? '${result.amount.toStringAsFixed(2)} ${result.currency} credited to $customerName'
                : '${result.amount.toStringAsFixed(2)} ${result.currency} debited from $customerName',
          ),
        ),
      );
      await _load();
      setState(() {});
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Agent'),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: _agent == null ? _onboarding() : _dashboard(_agent!),
                ),
      ),
    );
  }

  Widget _onboarding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Become an agent',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Onboard customers, help with cash deposits and withdrawals, and earn commission on every transaction.',
          style: TextStyle(
            color: BybitPalette.muted2,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        BybitTextField(
          label: 'Business / kiosk name',
          hint: 'e.g. Hodan Mobile Money',
          icon: Icons.storefront_rounded,
          controller: _nameController,
        ),
        const SizedBox(height: 16),
        BybitTextField(
          label: 'Phone (optional)',
          hint: '+252 61 xxx xxxx',
          icon: Icons.phone_outlined,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 28),
        BybitPrimaryButton(
          label: _submitting ? 'Registering...' : 'Register as agent',
          enabled: !_submitting,
          onTap: _register,
        ),
      ],
    );
  }

  Widget _dashboard(Map<String, dynamic> agent) {
    final code = agent['agent_code'] as String? ?? '';
    final balance = (agent['commission_balance'] as num?)?.toDouble() ?? 0;
    final status = agent['status'] as String? ?? 'PENDING';
    final isActive = status == 'ACTIVE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          agent['business_name'] as String? ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Share your agent code so new customers get credit to your account.',
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
                  ? 'Your agent account has been deactivated by an admin. Contact support for help.'
                  : 'Your agent account is pending admin approval. Assisted deposits and withdrawals will unlock once approved.',
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
        const SizedBox(height: 20),
        TouchScale(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Agent code copied'),
                backgroundColor: BybitPalette.surface2,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: BybitPalette.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agent code',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.copy_rounded, color: Colors.black, size: 22),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BybitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Commission balance',
                style: TextStyle(
                  color: BybitPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isActive)
          Row(
            children: [
              Expanded(
                child: _AssistButton(
                  icon: Icons.south_rounded,
                  label: 'Assist deposit',
                  onTap: () => _assist(isDeposit: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AssistButton(
                  icon: Icons.north_rounded,
                  label: 'Assist withdrawal',
                  onTap: () => _assist(isDeposit: false),
                ),
              ),
            ],
          ),
        const SizedBox(height: 28),
        const Text(
          'Recent commissions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<dynamic>?>(
          future: ApiService.agentCommissions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                ),
              );
            }
            final commissions = snapshot.data ?? const [];
            if (commissions.isEmpty) {
              return BybitCard(
                child: const Text(
                  'No commissions yet — assist a deposit or withdrawal to start earning.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 13),
                ),
              );
            }
            return Column(
              children:
                  commissions.map((raw) {
                    final commission = Map<String, dynamic>.from(raw as Map);
                    final kind = commission['kind'] as String? ?? '';
                    final relatedUser =
                        commission['related_user_name'] as String?;
                    final amount =
                        (commission['amount'] as num?)?.toDouble() ?? 0;
                    final currency = commission['currency'] as String? ?? 'USD';
                    final createdAt =
                        DateTime.tryParse(
                          commission['created_at'] as String? ?? '',
                        ) ??
                        DateTime.now();
                    return Padding(
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
                              child: Icon(
                                kind == 'deposit'
                                    ? Icons.south_rounded
                                    : kind == 'withdrawal'
                                    ? Icons.north_rounded
                                    : Icons.group_add_outlined,
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
                                    kind == 'onboarding'
                                        ? 'Customer onboarding${relatedUser != null ? ' — $relatedUser' : ''}'
                                        : '${kind[0].toUpperCase()}${kind.substring(1)}${relatedUser != null ? ' — $relatedUser' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
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
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AssistButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AssistButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF242832)),
        ),
        child: Column(
          children: [
            Icon(icon, color: BybitPalette.accent, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistResult {
  final String customer;
  final String currency;
  final double amount;
  const _AssistResult({
    required this.customer,
    required this.currency,
    required this.amount,
  });
}

class _AssistSheet extends StatefulWidget {
  final bool isDeposit;
  const _AssistSheet({required this.isDeposit});

  @override
  State<_AssistSheet> createState() => _AssistSheetState();
}

class _AssistSheetState extends State<_AssistSheet> {
  final _customerController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'KES';

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isDeposit ? 'Assist deposit' : 'Assist withdrawal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDeposit
                  ? 'Take cash from the customer, then credit their wallet.'
                  : 'Hand the customer cash, then debit their wallet.',
              style: const TextStyle(color: BybitPalette.muted2, fontSize: 13),
            ),
            const SizedBox(height: 20),
            BybitTextField(
              label: 'Customer phone or email',
              hint: '+252 61 xxx xxxx',
              icon: Icons.person_outline_rounded,
              controller: _customerController,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: BybitTextField(
                    label: 'Amount',
                    hint: '0.00',
                    icon: Icons.payments_outlined,
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Currency',
                        style: TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: BybitPalette.input,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            dropdownColor: BybitPalette.surface2,
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'KES',
                                child: Center(child: Text('KES')),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Center(child: Text('USD')),
                              ),
                            ],
                            onChanged:
                                (value) =>
                                    setState(() => _currency = value ?? 'KES'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            BybitPrimaryButton(
              label: widget.isDeposit ? 'Credit customer' : 'Debit customer',
              onTap: () {
                final amount =
                    double.tryParse(_amountController.text.trim()) ?? 0;
                final customer = _customerController.text.trim();
                if (customer.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a customer and a positive amount'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _AssistResult(
                    customer: customer,
                    currency: _currency,
                    amount: amount,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
