import 'package:flutter/material.dart';

import 'bybit_wallet_ui.dart';

/// What the person chose in [showAccountMoveSheet].
class AccountMove {
  final String currency;
  final double amount;
  const AccountMove(this.currency, this.amount);
}

/// Bottom sheet to move money between accounts (Business → wallet, wallet →
/// Agent float, Agent float/commission → wallet). [available] maps currency
/// to the most that can be moved; a currency missing from it isn't offered.
Future<AccountMove?> showAccountMoveSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Map<String, double> available,
  required String actionLabel,
}) {
  final currencies = available.keys.toList();
  var currency = currencies.first;
  final ctrl = TextEditingController();
  String? error;
  return showModalBottomSheet<AccountMove>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BybitPalette.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final max = available[currency] ?? 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: BybitPalette.muted, fontSize: 13)),
              const SizedBox(height: 14),
              if (currencies.length > 1)
                Row(
                  children: [
                    for (final c in currencies)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: currency == c,
                          onSelected: (_) => setSheet(() {
                            currency = c;
                            error = null;
                          }),
                          backgroundColor: BybitPalette.surface2,
                          selectedColor: BybitPalette.accent,
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          side: BorderSide.none,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  prefixStyle: const TextStyle(color: BybitPalette.muted, fontSize: 22),
                  hintText: '0.00',
                  hintStyle: const TextStyle(color: BybitPalette.muted),
                  filled: true,
                  fillColor: BybitPalette.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  suffixIcon: TextButton(
                    onPressed: () => setSheet(() => ctrl.text = max.toStringAsFixed(2)),
                    child: const Text('Max', style: TextStyle(color: BybitPalette.accent)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Available: $currency ${max.toStringAsFixed(2)}',
                  style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error!, style: const TextStyle(color: BybitPalette.red, fontSize: 13)),
              ],
              const SizedBox(height: 14),
              BybitPrimaryButton(
                label: actionLabel,
                onTap: () {
                  final value = double.tryParse(ctrl.text.trim().replaceAll(',', ''));
                  if (value == null || value <= 0) {
                    setSheet(() => error = 'Enter an amount');
                  } else if (value > max + 0.001) {
                    setSheet(() => error = 'That is more than is available');
                  } else {
                    Navigator.of(ctx).pop(AccountMove(currency, double.parse(value.toStringAsFixed(2))));
                  }
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
