import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

class SendMoneyScreen extends StatefulWidget {
  final KashAccount? sourceAccount;

  const SendMoneyScreen({super.key, this.sourceAccount});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  late KashAccountType _sourceType;
  String _rail = 'Crypto address';
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '0.00');

  @override
  void initState() {
    super.initState();
    _sourceType = widget.sourceAccount?.type ?? KashAccountType.crypto;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final source = appState.accountByType(_sourceType);
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Send'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send assets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Route crypto, wallet balance, mobile money or bank transfers from one Bybit-style flow.',
                style: TextStyle(color: BybitPalette.muted2, fontSize: 15, height: 1.35),
              ),
              const SizedBox(height: 24),
              _sourceSelector(appState.accounts),
              const SizedBox(height: 16),
              _railSelector(),
              const SizedBox(height: 16),
              _inputCard(
                label: 'Recipient address',
                hint: _recipientHint,
                icon: Icons.qr_code_scanner_rounded,
                controller: _recipientController,
              ),
              const SizedBox(height: 16),
              _inputCard(
                label: 'Amount',
                hint: '0.00',
                icon: Icons.all_inclusive_rounded,
                controller: _amountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _summary(appState, source),
              const SizedBox(height: 24),
              BybitPrimaryButton(
                label: 'Review transfer',
                onTap: () => _confirm(appState, source),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _recipientHint {
    switch (_rail) {
      case 'Mobile money':
        return '+252 61 000 0000';
      case 'Crypto address':
        return '0x... or wallet address';
      case 'Bank account':
        return 'Account number or IBAN';
      default:
        return '@username or phone';
    }
  }

  Widget _sourceSelector(List<KashAccount> accounts) {
    return BybitCard(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<KashAccountType>(
          value: _sourceType,
          dropdownColor: BybitPalette.surface,
          iconEnabledColor: BybitPalette.muted,
          isExpanded: true,
          items: accounts.map((account) {
            return DropdownMenuItem(
              value: account.type,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: account.accent.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(account.icon, color: account.accent, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          account.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.balance,
                          style: const TextStyle(
                            color: BybitPalette.muted2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (account) {
            if (account != null) setState(() => _sourceType = account);
          },
        ),
      ),
    );
  }

  Widget _railSelector() {
    final rails = ['Crypto address', 'RoyallPay user', 'Mobile money', 'Bank account'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rails.map((rail) {
        final selected = rail == _rail;
        return TouchScale(
          onTap: () => setState(() => _rail = rail),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? BybitPalette.selected : BybitPalette.surface2,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              rail,
              style: TextStyle(
                color: selected ? Colors.white : BybitPalette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _inputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BybitPalette.muted2, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: BybitPalette.muted),
              filled: true,
              fillColor: BybitPalette.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              hintStyle: const TextStyle(color: BybitPalette.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(KashAppState appState, KashAccount source) {
    final fee = appState.transferFee(_rail);
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transfer details', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          BybitInfoLine('Route', '${source.title} -> $_rail'),
          BybitInfoLine('Speed', _rail == 'Crypto address' ? 'Network dependent' : 'Instant sandbox'),
          BybitInfoLine('Fee', fee == 0 ? 'Free' : '\$${fee.toStringAsFixed(2)} estimated'),
          BybitInfoLine('Available', source.balance),
          BybitInfoLine('Limits (${appState.kycTier})', '\$${appState.remainingDailyLimit.toStringAsFixed(0)} left today'),
        ],
      ),
    );
  }

  void _confirm(KashAppState appState, KashAccount source) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final result = appState.submitTransfer(
      sourceType: source.type,
      rail: _rail,
      recipient: _recipientController.text,
      amount: amount,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: BybitPalette.surface2),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: BybitPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: BybitPalette.accent,
                child: Icon(Icons.check_rounded, color: Colors.black, size: 38),
              ),
              const SizedBox(height: 18),
              const Text('Transfer queued', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(result.message, textAlign: TextAlign.center, style: const TextStyle(color: BybitPalette.muted2, fontSize: 14)),
              const SizedBox(height: 22),
              BybitPrimaryButton(
                label: 'Done',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
