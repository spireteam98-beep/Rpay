import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum KashAccountType { crypto, mobileMoney, bank }

class KashAccount {
  final KashAccountType type;
  final String title;
  final String subtitle;
  final double balanceUsd;
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
    required this.currency,
    required this.status,
    required this.icon,
    required this.accent,
    required this.rails,
    required this.transactions,
  });

  String get balance => NumberFormat.currency(symbol: '\$').format(balanceUsd);

  KashAccount copyWith({
    double? balanceUsd,
    String? status,
    List<KashTransaction>? transactions,
  }) {
    return KashAccount(
      type: type,
      title: title,
      subtitle: subtitle,
      balanceUsd: balanceUsd ?? this.balanceUsd,
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
}

const List<KashAccount> kashAccounts = [
  KashAccount(
    type: KashAccountType.crypto,
    title: 'Crypto custody',
    subtitle: 'BTC, ETH and USDT held by RoyalPay',
    balanceUsd: 12840.20,
    currency: 'USDT value',
    status: 'MPC custody sandbox',
    icon: Icons.currency_bitcoin_rounded,
    accent: Color(0xFFD7F53C),
    rails: ['BTC', 'ETH', 'USDT', 'Address screening'],
    transactions: [
      KashTransaction(
        title: 'USDT deposit',
        subtitle: 'Ethereum address confirmed',
        amount: '+420.00 USDT',
        icon: Icons.south_rounded,
      ),
      KashTransaction(
        title: 'BTC to USDT swap',
        subtitle: 'Internal custody ledger',
        amount: '+1,120.50 USDT',
        icon: Icons.sync_alt_rounded,
      ),
    ],
  ),
  KashAccount(
    type: KashAccountType.mobileMoney,
    title: 'Mobile money wallet',
    subtitle: 'Domestic SOS and USD balances',
    balanceUsd: 8430.12,
    currency: 'USD / SOS',
    status: 'Tier 1 limit active',
    icon: Icons.phone_iphone_rounded,
    accent: Color(0xFF35D07F),
    rails: ['EVC Plus', 'Zaad', 'Sahal', 'M-Pesa'],
    transactions: [
      KashTransaction(
        title: 'Amina Hassan',
        subtitle: 'RoyalPay wallet transfer',
        amount: '-85.00 USD',
        icon: Icons.north_east_rounded,
      ),
      KashTransaction(
        title: 'EVC Plus cash-in',
        subtitle: 'Hormuud sandbox rail',
        amount: '+250.00 USD',
        icon: Icons.add_card_rounded,
      ),
    ],
  ),
  KashAccount(
    type: KashAccountType.bank,
    title: 'Virtual bank account',
    subtitle: 'Named account now, IBAN later',
    balanceUsd: 3248.00,
    currency: 'USD account',
    status: 'IBAN pending EMI phase',
    icon: Icons.account_balance_rounded,
    accent: Color(0xFF8FA7FF),
    rails: ['Account number', 'Statements', 'SEPA ready', 'Cards later'],
    transactions: [
      KashTransaction(
        title: 'Salary placeholder',
        subtitle: 'Virtual account credit',
        amount: '+1,800.00 USD',
        icon: Icons.account_balance_wallet_outlined,
      ),
      KashTransaction(
        title: 'Statement generated',
        subtitle: 'July account activity',
        amount: 'PDF',
        icon: Icons.description_outlined,
      ),
    ],
  ),
];
