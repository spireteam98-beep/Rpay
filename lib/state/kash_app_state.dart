import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kash_account.dart';
import '../models/ledger_entry.dart';

class TransferResult {
  final bool success;
  final String message;
  final String? transactionId;

  const TransferResult._(this.success, this.message, this.transactionId);

  const TransferResult.success(String message, {String? transactionId})
    : this._(true, message, transactionId);

  const TransferResult.failure(String message) : this._(false, message, null);
}

class KashAppState extends ChangeNotifier {
  final NumberFormat _money = NumberFormat.currency(symbol: '\$');
  List<KashAccount> _accounts = List<KashAccount>.from(kashAccounts);
  String _profileName = 'Mohamed Ali';
  String _phoneNumber = '+252 61 000 0000';
  bool _phoneVerified = false;
  bool _kycSubmitted = false;
  int _ledgerSequence = 1004;
  final List<LedgerTransaction> _ledgerTransactions = [];

  KashAppState({String? profileName, String? phoneNumber}) {
    if (profileName != null && profileName.isNotEmpty) {
      _profileName = profileName;
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      _phoneNumber = phoneNumber;
    }
    _seedLedger();
  }

  List<KashAccount> get accounts => List.unmodifiable(_accounts);
  List<LedgerTransaction> get ledgerTransactions =>
      List.unmodifiable(_ledgerTransactions);
  List<LedgerEntry> get ledgerEntries => List.unmodifiable(
    _ledgerTransactions.expand((transaction) => transaction.entries).toList(),
  );
  String get profileName => _profileName;
  String get phoneNumber => _phoneNumber;
  bool get phoneVerified => _phoneVerified;
  bool get kycSubmitted => _kycSubmitted;
  String get firstName => _profileName.split(' ').first;
  String get kycTier => _kycSubmitted ? 'Full KYC review' : 'Tier 1';
  String get totalBalance => _money.format(
    _accounts.fold<double>(0, (total, account) => total + account.balanceUsd),
  );

  List<KashTransaction> get recentTransactions {
    return _accounts.expand((account) => account.transactions).take(6).toList();
  }

  KashAccount accountByType(KashAccountType type) {
    return _accounts.firstWhere((account) => account.type == type);
  }

  void completeSignup({required String fullName, required String phoneNumber}) {
    _profileName = fullName.trim().isEmpty ? 'Mohamed Ali' : fullName.trim();
    _phoneNumber =
        phoneNumber.trim().isEmpty ? '+252 61 000 0000' : phoneNumber.trim();
    notifyListeners();
  }

  void verifyPhone() {
    _phoneVerified = true;
    notifyListeners();
  }

  void submitKyc({required bool fullVerification}) {
    _kycSubmitted = fullVerification;
    notifyListeners();
  }

  TransferResult submitCashIn({
    required KashAccountType destinationType,
    required String rail,
    required double amount,
  }) {
    if (amount <= 0) {
      return const TransferResult.failure('Enter an amount greater than 0.');
    }

    final destination = accountByType(destinationType);
    final transactionId = _nextTransactionId();
    final postedAt = DateTime.now();
    final transaction = KashTransaction(
      title: '$rail cash-in',
      subtitle: 'Domestic wallet funding',
      amount: '+${_money.format(amount)}',
      icon: Icons.add_card_rounded,
    );

    _accounts =
        _accounts.map((account) {
          if (account.type != destinationType) return account;
          return account.copyWith(
            balanceUsd: account.balanceUsd + amount,
            transactions: [transaction, ...account.transactions],
          );
        }).toList();

    _ledgerTransactions.insert(
      0,
      LedgerTransaction(
        id: transactionId,
        postedAt: postedAt,
        title: '$rail cash-in',
        rail: rail,
        status: 'Posted',
        entries: [
          LedgerEntry(
            id: '$transactionId-1',
            transactionId: transactionId,
            postedAt: postedAt,
            accountType: destinationType,
            direction: LedgerDirection.credit,
            amountUsd: amount,
            accountName: destination.title,
            memo: 'Customer wallet liability increased',
          ),
          LedgerEntry(
            id: '$transactionId-2',
            transactionId: transactionId,
            postedAt: postedAt,
            accountType: destinationType,
            direction: LedgerDirection.debit,
            amountUsd: amount,
            accountName: '$rail clearing',
            memo: 'Sandbox cash-in receivable',
          ),
        ],
      ),
    );

    notifyListeners();
    return TransferResult.success(
      '${_money.format(amount)} added through $rail.',
      transactionId: transactionId,
    );
  }

  TransferResult submitTransfer({
    required KashAccountType sourceType,
    required String rail,
    required String recipient,
    required double amount,
  }) {
    if (amount <= 0) {
      return const TransferResult.failure('Enter an amount greater than 0.');
    }

    if (recipient.trim().isEmpty) {
      return const TransferResult.failure('Add a recipient before review.');
    }

    final source = accountByType(sourceType);
    final fee = transferFee(rail);
    final debit = amount + fee;
    final transactionId = _nextTransactionId();
    final postedAt = DateTime.now();

    if (source.balanceUsd < debit) {
      return TransferResult.failure('Not enough balance in ${source.title}.');
    }

    final transaction = KashTransaction(
      title: recipient.trim(),
      subtitle: '$rail transfer queued',
      amount: '-${_money.format(debit)}',
      icon: Icons.north_east_rounded,
    );

    _accounts =
        _accounts.map((account) {
          if (account.type != sourceType) return account;
          return account.copyWith(
            balanceUsd: account.balanceUsd - debit,
            transactions: [transaction, ...account.transactions],
          );
        }).toList();

    _ledgerTransactions.insert(
      0,
      LedgerTransaction(
        id: transactionId,
        postedAt: postedAt,
        title: recipient.trim(),
        rail: rail,
        status: 'Queued',
        entries: [
          LedgerEntry(
            id: '$transactionId-1',
            transactionId: transactionId,
            postedAt: postedAt,
            accountType: sourceType,
            direction: LedgerDirection.debit,
            amountUsd: debit,
            accountName: source.title,
            memo: 'Customer wallet balance reduced',
          ),
          LedgerEntry(
            id: '$transactionId-2',
            transactionId: transactionId,
            postedAt: postedAt,
            accountType: sourceType,
            direction: LedgerDirection.credit,
            amountUsd: amount,
            accountName: '$rail clearing',
            memo: 'Outbound transfer payable',
          ),
          if (fee > 0)
            LedgerEntry(
              id: '$transactionId-3',
              transactionId: transactionId,
              postedAt: postedAt,
              accountType: sourceType,
              direction: LedgerDirection.credit,
              amountUsd: fee,
              accountName: 'Fee revenue',
              memo: 'Rail fee',
            ),
        ],
      ),
    );

    notifyListeners();
    return TransferResult.success(
      '${_money.format(amount)} transfer queued through $rail.',
      transactionId: transactionId,
    );
  }

  double transferFee(String rail) {
    switch (rail) {
      case 'Kashflip user':
        return 0;
      case 'Crypto address':
        return 1.25;
      case 'Bank account':
        return 0.75;
      default:
        return 0.30;
    }
  }

  String _nextTransactionId() {
    _ledgerSequence++;
    return 'KFL-${_ledgerSequence.toString().padLeft(6, '0')}';
  }

  void _seedLedger() {
    final postedAt = DateTime.now().subtract(const Duration(hours: 2));
    _ledgerTransactions.addAll([
      LedgerTransaction(
        id: 'KFL-001001',
        postedAt: postedAt,
        title: 'Opening balances',
        rail: 'Core ledger',
        status: 'Posted',
        entries: [
          LedgerEntry(
            id: 'KFL-001001-1',
            transactionId: 'KFL-001001',
            postedAt: postedAt,
            accountType: KashAccountType.crypto,
            direction: LedgerDirection.credit,
            amountUsd: 12840.20,
            accountName: 'Crypto custody',
            memo: 'Customer crypto liability',
          ),
          LedgerEntry(
            id: 'KFL-001001-2',
            transactionId: 'KFL-001001',
            postedAt: postedAt,
            accountType: KashAccountType.crypto,
            direction: LedgerDirection.debit,
            amountUsd: 12840.20,
            accountName: 'Custody reserve',
            memo: 'Sandbox reserve asset',
          ),
        ],
      ),
      LedgerTransaction(
        id: 'KFL-001002',
        postedAt: postedAt.add(const Duration(minutes: 7)),
        title: 'Mobile wallet opening balance',
        rail: 'Domestic wallet',
        status: 'Posted',
        entries: [
          LedgerEntry(
            id: 'KFL-001002-1',
            transactionId: 'KFL-001002',
            postedAt: postedAt.add(const Duration(minutes: 7)),
            accountType: KashAccountType.mobileMoney,
            direction: LedgerDirection.credit,
            amountUsd: 8430.12,
            accountName: 'Mobile money wallet',
            memo: 'Customer wallet liability',
          ),
          LedgerEntry(
            id: 'KFL-001002-2',
            transactionId: 'KFL-001002',
            postedAt: postedAt.add(const Duration(minutes: 7)),
            accountType: KashAccountType.mobileMoney,
            direction: LedgerDirection.debit,
            amountUsd: 8430.12,
            accountName: 'Safeguarding reserve',
            memo: 'Sandbox fiat reserve',
          ),
        ],
      ),
    ]);
  }
}
