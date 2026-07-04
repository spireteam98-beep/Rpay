import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';

class SendMoneyScreen extends StatefulWidget {
  final KashAccount? sourceAccount;

  const SendMoneyScreen({super.key, this.sourceAccount});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  late KashAccountType _sourceType;
  String _rail = 'Kashflip user';
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '50',
  );

  @override
  void initState() {
    super.initState();
    _sourceType = widget.sourceAccount?.type ?? KashAccountType.mobileMoney;
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
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Send money'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Move money anywhere',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One flow routes wallet, crypto, mobile money and bank transfers.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _sourceSelector(appState.accounts),
              const SizedBox(height: 20),
              _railSelector(),
              const SizedBox(height: 20),
              KashTextField(
                label: 'Recipient',
                hint: _recipientHint,
                icon: Icons.person_search_rounded,
                controller: _recipientController,
              ),
              const SizedBox(height: 18),
              KashTextField(
                label: 'Amount',
                hint: '0.00',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: _amountController,
              ),
              const SizedBox(height: 22),
              _summary(appState, source),
              const SizedBox(height: 24),
              PrimaryButton(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'From',
          style: TextStyle(
            color: AppTheme.textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GlassTile(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<KashAccountType>(
              value: _sourceType,
              dropdownColor: AppTheme.cardDarkBackground,
              iconEnabledColor: AppTheme.textGrey,
              isExpanded: true,
              items:
                  accounts.map((account) {
                    return DropdownMenuItem(
                      value: account.type,
                      child: Row(
                        children: [
                          CircleIcon(
                            account.icon,
                            size: 40,
                            color: account.accent,
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
                                    color: AppTheme.textWhite,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  account.balance,
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 12,
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
                if (account != null) {
                  setState(() => _sourceType = account);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _railSelector() {
    final rails = [
      'Kashflip user',
      'Mobile money',
      'Crypto address',
      'Bank account',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'To',
          style: TextStyle(
            color: AppTheme.textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              rails.map((rail) {
                final selected = rail == _rail;
                return GestureDetector(
                  onTap: () => setState(() => _rail = rail),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? AppTheme.primaryColor
                              : AppTheme.cardDarkBackground,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color:
                            selected
                                ? AppTheme.primaryColor
                                : AppTheme.glassStroke,
                      ),
                    ),
                    child: Text(
                      rail,
                      style: TextStyle(
                        color:
                            selected ? AppTheme.onLime : AppTheme.textLightGrey,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _summary(KashAppState appState, KashAccount source) {
    final fee = appState.transferFee(_rail);
    return GlassTile(
      child: Column(
        children: [
          _row('Route', '${source.title} -> $_rail'),
          const SizedBox(height: 12),
          _row(
            'Speed',
            _rail == 'Crypto address' ? 'Network dependent' : 'Instant sandbox',
          ),
          const SizedBox(height: 12),
          _row(
            'Fee',
            fee == 0 ? 'Free' : '\$${fee.toStringAsFixed(2)} estimated',
          ),
          const SizedBox(height: 12),
          _row('Available', source.balance),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.cardLightBackground,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: AppTheme.cardDarkBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.rCard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.onLime,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Transfer queued',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
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
