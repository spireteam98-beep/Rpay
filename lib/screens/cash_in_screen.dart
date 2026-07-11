import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/payment_method_form.dart';
import '../widgets/touch_scale.dart';
import 'p2p_buy_screen.dart';

enum _CashInStep { method, amount, process }

const _gateways = [
  (
    'PAYSTACK',
    'M-Pesa',
    'Pay via Safaricom STK push',
    Icons.phone_iphone_rounded,
  ),
  (
    'WAAFI',
    'Waafi',
    'Somali mobile wallet transfer',
    Icons.account_balance_wallet_rounded,
  ),
  (
    'STRIPE',
    'Card',
    'Visa and Mastercard supported',
    Icons.credit_card_rounded,
  ),
];

String _currencyFor(String gateway) => gateway == 'PAYSTACK' ? 'KES' : 'USD';

/// Three-step cash-in wizard: payment method -> amount (keypad) -> payment
/// process. Exactly one step is on screen at a time, driven by [_step]; the
/// header back arrow walks backward through the steps and only pops the
/// route once the user is already on the first one.
class CashInScreen extends StatefulWidget {
  const CashInScreen({super.key});

  @override
  State<CashInScreen> createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  _CashInStep _step = _CashInStep.method;
  String _amountText = '';
  String _gateway = _gateways.first.$1;

  double get _amount => double.tryParse(_amountText) ?? 0;

  void _tapDigit(String digit) {
    if (digit == '.') {
      if (_amountText.contains('.')) return;
      setState(
        () => _amountText = _amountText.isEmpty ? '0.' : '$_amountText.',
      );
      return;
    }
    if (_amountText.contains('.')) {
      final decimals = _amountText.split('.').last;
      if (decimals.length >= 2) return;
    }
    if (_amountText == '0') {
      setState(() => _amountText = digit);
      return;
    }
    if (_amountText.replaceAll('.', '').length >= 9) return;
    setState(() => _amountText += digit);
  }

  void _backspace() {
    if (_amountText.isEmpty) return;
    setState(
      () => _amountText = _amountText.substring(0, _amountText.length - 1),
    );
  }

  void _goToAmount(String gateway) {
    setState(() {
      _gateway = gateway;
      _step = _CashInStep.amount;
    });
  }

  void _goToProcess() {
    if (_amount <= 0) return;
    setState(() => _step = _CashInStep.process);
  }

  void _openP2p() {
    Navigator.of(context).push(kashRoute(const P2pBuyScreen()));
  }

  /// Steps one screen backward. Returns true if there was nowhere left to
  /// go, meaning the caller should pop the whole route instead.
  bool _stepBack() {
    if (_step == _CashInStep.process) {
      setState(() => _step = _CashInStep.amount);
      return false;
    }
    if (_step == _CashInStep.amount) {
      setState(() => _step = _CashInStep.method);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final wallet = appState.accountByType(KashAccountType.mobileMoney);
    return PopScope(
      canPop: _step == _CashInStep.method,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _stepBack();
      },
      child: Scaffold(
        backgroundColor: BybitPalette.bg,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _CashInStep.method => _MethodListStep(
                  key: const ValueKey('method'),
                  onSelect: _goToAmount,
                  onP2p: _openP2p,
                ),
                _CashInStep.amount => _AmountStep(
                  key: const ValueKey('amount'),
                  amountText: _amountText,
                  gateway: _gateway,
                  onChangeMethod:
                      () => setState(() => _step = _CashInStep.method),
                  onDigit: _tapDigit,
                  onBackspace: _backspace,
                  onNext: _amount > 0 ? _goToProcess : null,
                ),
                _CashInStep.process => _ProcessStep(
                  key: const ValueKey('process'),
                  amount: _amount,
                  gateway: _gateway,
                  wallet: wallet,
                  appState: appState,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = {
      _CashInStep.method: 'Cash in',
      _CashInStep.amount: 'Enter amount',
      _CashInStep.process: 'Cash in',
    };
    return AppBar(
      backgroundColor: BybitPalette.bg,
      elevation: 0,
      centerTitle: true,
      leading: TouchScale(
        onTap: () {
          if (_stepBack()) Navigator.of(context).maybePop();
        },
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          decoration: const BoxDecoration(
            color: BybitPalette.surface2,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      title: Text(
        titles[_step]!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _StepDots(step: _step),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final _CashInStep step;
  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    final index = _CashInStep.values.indexOf(step);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_CashInStep.values.length, (i) {
        final active = i <= index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(left: 5),
          width: i == index ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? BybitPalette.accent : BybitPalette.surface2,
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}

/// Step 1 — full-screen list of deposit options (M-Pesa, Waafi, Card, P2P),
/// the Bybit "Select Payment Method" pattern shown as the first thing the
/// user sees when Cash In opens.
class _MethodListStep extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final VoidCallback onP2p;

  const _MethodListStep({
    super.key,
    required this.onSelect,
    required this.onP2p,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      children: [
        const Text(
          'Choose how you want to add money',
          style: TextStyle(
            color: BybitPalette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ..._gateways.map(
          (g) => _MethodTile(
            icon: g.$4,
            title: g.$2,
            subtitle: g.$3,
            onTap: () => onSelect(g.$1),
          ),
        ),
        _MethodTile(
          icon: Icons.people_alt_rounded,
          title: 'P2P Trading',
          subtitle: 'Buy from a verified agent nearby',
          badge: 'P2P',
          onTap: onP2p,
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TouchScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BybitPalette.surface2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BybitPalette.accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: BybitPalette.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: BybitPalette.selected,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BybitPalette.muted2,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BybitPalette.muted2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 2 — amount entry via a numeric keypad, no system keyboard. Shows a
/// "Pay with" summary row for the method chosen in step 1, tappable to jump
/// back and change it.
class _AmountStep extends StatelessWidget {
  final String amountText;
  final String gateway;
  final VoidCallback onChangeMethod;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onNext;

  const _AmountStep({
    super.key,
    required this.amountText,
    required this.gateway,
    required this.onChangeMethod,
    required this.onDigit,
    required this.onBackspace,
    required this.onNext,
  });

  (String, String, String, IconData) get _selectedGateway =>
      _gateways.firstWhere((g) => g.$1 == gateway);

  @override
  Widget build(BuildContext context) {
    final currency = _currencyFor(gateway);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              amountText.isEmpty ? '$currency 0' : '$currency $amountText',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TouchScale(
            onTap: onChangeMethod,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: BybitPalette.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedGateway.$4,
                    color: BybitPalette.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pay with',
                          style: TextStyle(
                            color: BybitPalette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _selectedGateway.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: BybitPalette.muted2,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _keypad(),
          const SizedBox(height: 20),
          BybitPrimaryButton(
            label: 'Next',
            enabled: onNext != null,
            onTap: onNext ?? () {},
          ),
        ],
      ),
    );
  }

  Widget _keypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'del'],
    ];
    return Column(
      children:
          rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children:
                    row.map((key) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _keypadButton(key),
                        ),
                      );
                    }).toList(),
              ),
            );
          }).toList(),
    );
  }

  Widget _keypadButton(String key) {
    final isDelete = key == 'del';
    return TouchScale(
      onTap: isDelete ? onBackspace : () => onDigit(key),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BybitPalette.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            isDelete
                ? const Icon(
                  Icons.backspace_outlined,
                  color: BybitPalette.muted2,
                  size: 20,
                )
                : Text(
                  key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
      ),
    );
  }
}

/// Step 3 — actual charge, reusing [PaymentMethodForm] with the amount and
/// gateway already locked in from the previous two steps.
class _ProcessStep extends StatelessWidget {
  final double amount;
  final String gateway;
  final KashAccount wallet;
  final KashAppState appState;

  const _ProcessStep({
    super.key,
    required this.amount,
    required this.gateway,
    required this.wallet,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: wallet.accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(wallet.icon, color: wallet.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_currencyFor(gateway)} ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                wallet.balance,
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          BybitCard(
            padding: const EdgeInsets.all(18),
            child: PaymentMethodForm(
              fixedAmount: amount,
              showGatewaySelector: false,
              gateway: gateway,
              submitLabel: 'Cash in now',
              onCredited: (amount, currency, gateway, gatewayLabel) async {
                final amountUsd = currency == 'KES' ? amount / 130 : amount;
                await appState.syncFromBackend();
                if (!context.mounted) return;
                await _showDone(
                  context,
                  'Cash in complete',
                  '${amountUsd.toStringAsFixed(2)} USD credited to your wallet.',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDone(BuildContext context, String title, String message) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: BybitPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: BybitPalette.accent,
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  BybitPrimaryButton(
                    label: 'Done',
                    onTap: () {
                      Navigator.of(dialogContext).pop();
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
