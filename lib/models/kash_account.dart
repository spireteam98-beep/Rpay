import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Wayaki USD and Wayaki KES (M-Pesa) are the two real, currently-accepted
/// currency accounts — everything shown on the wallet screen. Crypto custody
/// and the virtual bank account exist as sub-accounts under the same Wayaki
/// account for later phases (Binance custody, IBAN banking) but stay out of
/// the account list/UI until those are actually ready to use.
enum KashAccountType { walletUsd, walletKes, crypto, bank }

const _hiddenAccountTypes = {KashAccountType.crypto, KashAccountType.bank};

class KashAccount {
  final KashAccountType type;
  final String title;
  final String subtitle;

  /// Balance expressed in USD terms — used for totals, transfer limits and
  /// ledger amounts, which are all USD-denominated app-wide. For the KES
  /// account this is the converted USD-equivalent, not what's shown on the
  /// card itself (see [nativeAmount]).
  final double balanceUsd;

  /// The actual balance in the account's own currency, formatted with
  /// [nativeSymbol] for display. Equal to [balanceUsd] for USD accounts.
  final double nativeAmount;
  final String nativeSymbol;

  final String currency;
  final String status;
  final IconData icon;
  final Color accent;
  final List<String> rails;
  final List<KashTransaction> transactions;

  const KashAccount({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.balanceUsd,
    this.nativeAmount = 0,
    this.nativeSymbol = '\$',
    required this.currency,
    required this.status,
    required this.icon,
    required this.accent,
    required this.rails,
    required this.transactions,
  });

  /// True for the accounts that actually show up on the wallet screen.
  bool get isVisible => !_hiddenAccountTypes.contains(type);

  String get balance =>
      NumberFormat.currency(symbol: nativeSymbol).format(nativeAmount);

  KashAccount copyWith({
    double? balanceUsd,
    double? nativeAmount,
    String? status,
    List<KashTransaction>? transactions,
  }) {
    return KashAccount(
      type: type,
      title: title,
      subtitle: subtitle,
      balanceUsd: balanceUsd ?? this.balanceUsd,
      nativeAmount: nativeAmount ?? this.nativeAmount,
      nativeSymbol: nativeSymbol,
      currency: currency,
      status: status ?? this.status,
      icon: icon,
      accent: accent,
      rails: rails,
      transactions: transactions ?? this.transactions,
    );
  }
}

class KashTransaction {
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;

  const KashTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'amount': amount,
    'icon': kashIconKey(icon),
  };

  factory KashTransaction.fromJson(Map<String, dynamic> json) =>
      KashTransaction(
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        amount: json['amount'] as String,
        icon: kashIconFor(json['icon'] as String?),
      );
}

/// Named icon registry so transactions can be persisted without breaking
/// Flutter web's icon tree-shaking (icons stay const).
const Map<String, IconData> kashIconRegistry = {
  'south': Icons.south_rounded,
  'north_east': Icons.north_east_rounded,
  'swap': Icons.sync_alt_rounded,
  'add_card': Icons.add_card_rounded,
  'wallet': Icons.account_balance_wallet_outlined,
  'doc': Icons.description_outlined,
  'bitcoin': Icons.currency_bitcoin_rounded,
  'phone': Icons.phone_iphone_rounded,
  'bank': Icons.account_balance_rounded,
};

String kashIconKey(IconData icon) {
  for (final entry in kashIconRegistry.entries) {
    if (entry.value.codePoint == icon.codePoint) return entry.key;
  }
  return 'wallet';
}

IconData kashIconFor(String? key) =>
    kashIconRegistry[key] ?? Icons.account_balance_wallet_outlined;

const List<KashAccount> kashAccounts = [
  KashAccount(
    type: KashAccountType.walletUsd,
    title: 'Wayaki · USD',
    subtitle: 'Card top-ups, transfers and payments',
    balanceUsd: 0,
    nativeAmount: 0,
    nativeSymbol: '\$',
    currency: 'USD',
    status: 'Active',
    icon: Icons.attach_money_rounded,
    accent: Color(0xFFDDF716),
    rails: ['Card top-up', 'Wayaki transfer', 'Bill pay'],
    transactions: [],
  ),
  KashAccount(
    type: KashAccountType.walletKes,
    title: 'Wayaki · KES',
    subtitle: 'M-Pesa cash in and cash out',
    balanceUsd: 0,
    nativeAmount: 0,
    nativeSymbol: 'KSh ',
    currency: 'KES',
    status: 'Active',
    icon: Icons.phone_iphone_rounded,
    accent: Color(0xFF2ED17C),
    rails: ['M-Pesa', 'Wayaki transfer'],
    transactions: [],
  ),
  // Hidden for now — Binance custody sub-account, coming in a later phase.
  KashAccount(
    type: KashAccountType.crypto,
    title: 'Crypto custody',
    subtitle: 'BTC, ETH and USDT held by Wayaki',
    balanceUsd: 0,
    nativeAmount: 0,
    nativeSymbol: '\$',
    currency: 'USDT value',
    status: 'MPC custody sandbox',
    icon: Icons.currency_bitcoin_rounded,
    accent: Color(0xFFDDF716),
    rails: ['BTC', 'ETH', 'USDT', 'Address screening'],
    transactions: [],
  ),
  // Hidden for now — virtual bank sub-account, coming in a later phase.
  KashAccount(
    type: KashAccountType.bank,
    title: 'Virtual bank account',
    subtitle: 'Named account now, IBAN later',
    balanceUsd: 0,
    nativeAmount: 0,
    nativeSymbol: '\$',
    currency: 'USD account',
    status: 'IBAN pending EMI phase',
    icon: Icons.account_balance_rounded,
    accent: Color(0xFF8FA7FF),
    rails: ['Account number', 'Statements', 'SEPA ready', 'Cards later'],
    transactions: [],
  ),
];
