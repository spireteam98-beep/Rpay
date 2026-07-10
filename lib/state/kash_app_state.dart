import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/aml_case.dart';
import '../models/kash_account.dart';
import '../models/ledger_entry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class TransferResult {
  final bool success;
  final String message;
  final String? transactionId;

  const TransferResult._(this.success, this.message, this.transactionId);

  const TransferResult.success(String message, {String? transactionId})
    : this._(true, message, transactionId);

  const TransferResult.failure(String message) : this._(false, message, null);
}

/// KYC tiers with real transaction limits (Phase 1 compliance-by-design).
enum KycTier { tier1, full }

extension KycTierLimits on KycTier {
  String get label => this == KycTier.tier1 ? 'Tier 1' : 'Full KYC';
  double get perTransferLimit => this == KycTier.tier1 ? 500 : 10000;
  double get dailyLimit => this == KycTier.tier1 ? 1000 : 25000;
}

class KashAppState extends ChangeNotifier {
  static const _stateKey = 'kash_app_state_v1';

  /// Demo sanctions screening list — replaced by a real screening vendor
  /// (OFAC/UN/EU consolidated lists) in production.
  static const List<String> _sanctionsList = [
    'blocked trading co',
    'sanctioned',
    'embargo',
    'denied party',
  ];

  final NumberFormat _money = NumberFormat.currency(symbol: '\$');
  // Static metadata (title/icon/rails) from kashAccounts, zeroed out —
  // real balances arrive via syncFromBackend() once there's a session.
  List<KashAccount> _accounts =
      kashAccounts
          .map(
            (account) =>
                account.copyWith(balanceUsd: 0, transactions: const []),
          )
          .toList();
  String _profileName = 'Mohamed Ali';
  String _phoneNumber = '+252 61 000 0000';
  bool _phoneVerified = false;
  bool _kycSubmitted = false;
  String _role = 'user';
  int _ledgerSequence = 1004;
  final List<LedgerTransaction> _ledgerTransactions = [];
  final List<AmlCase> _amlCases = [];
  final List<DateTime> _recentTransferTimes = [];
  double _spentToday = 0;
  String _spentDate = '';

  KashAppState({String? profileName, String? phoneNumber}) {
    if (profileName != null && profileName.isNotEmpty) {
      _profileName = profileName;
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      _phoneNumber = phoneNumber;
    }
    _restore();
  }

  /// Overwrites the three account balances with the real Postgres-backed
  /// numbers from the backend (crypto custody, domestic wallet, virtual
  /// bank account) — called once the app has a live session. Leaves local
  /// transaction history / transfers alone; this only fixes the balances.
  Future<void> syncFromBackend() async {
    if (!ApiService.hasSession) return;
    final me = await ApiService.me();
    final hybrid = await ApiService.hybridWallet();
    final bank = await ApiService.bankAccount();
    final backendLedger = await ApiService.ledgerTransactions();
    if (me == null && hybrid == null && bank == null && backendLedger == null) {
      return;
    }

    if (me != null) {
      _profileName = me['full_name'] as String? ?? _profileName;
      _phoneNumber = me['phone'] as String? ?? _phoneNumber;
      _phoneVerified = me['phone_verified'] == true;
      final kycTier = me['kyc_tier'];
      _kycSubmitted = kycTier is num ? kycTier >= 2 : _kycSubmitted;
      _role = me['role'] as String? ?? _role;
    }

    _accounts =
        _accounts.map((account) {
          switch (account.type) {
            case KashAccountType.crypto:
              if (hybrid == null) return account;
              final crypto = hybrid['crypto'] as Map<String, dynamic>?;
              final totalUsd = (crypto?['totalUsd'] as num?)?.toDouble() ?? 0;
              final depositAddress = crypto?['depositAddress'] as String?;
              return account.copyWith(
                balanceUsd: totalUsd,
                status:
                    (depositAddress == null || depositAddress.isEmpty)
                        ? account.status
                        : 'Deposit address $depositAddress',
              );
            case KashAccountType.mobileMoney:
              if (hybrid == null) return account;
              final fiat = hybrid['fiat'] as Map<String, dynamic>?;
              final usd = (fiat?['USD'] as num?)?.toDouble() ?? 0;
              final kes = (fiat?['KES'] as num?)?.toDouble() ?? 0;
              final kesPerUsd = (fiat?['kesPerUsd'] as num?)?.toDouble() ?? 0;
              final kesAsUsd = kesPerUsd > 0 ? kes / kesPerUsd : 0;
              return account.copyWith(balanceUsd: usd + kesAsUsd);
            case KashAccountType.bank:
              if (bank == null) return account;
              final accountInfo = bank['account'] as Map<String, dynamic>?;
              final accountNumber = accountInfo?['account_number'] as String?;
              // No banking balance concept yet (Phase 5 per the roadmap) — a
              // real account number with a $0 balance is accurate, not a bug.
              return account.copyWith(
                balanceUsd: 0,
                status:
                    (accountNumber == null || accountNumber.isEmpty)
                        ? account.status
                        : 'Account $accountNumber · IBAN pending EMI phase',
              );
          }
        }).toList();

    if (backendLedger != null) {
      _ledgerTransactions
        ..clear()
        ..addAll(_parseBackendLedger(backendLedger));
    }

    _persist();
    notifyListeners();
  }

  // ── Getters ─────────────────────────────────────────────────────
  List<KashAccount> get accounts => List.unmodifiable(_accounts);
  List<LedgerTransaction> get ledgerTransactions =>
      List.unmodifiable(_ledgerTransactions);
  List<LedgerEntry> get ledgerEntries => List.unmodifiable(
    _ledgerTransactions.expand((transaction) => transaction.entries).toList(),
  );
  List<AmlCase> get amlCases => List.unmodifiable(_amlCases);
  int get openAmlCases =>
      _amlCases.where((amlCase) => amlCase.status == 'Open').length;
  String get profileName => _profileName;
  String get phoneNumber => _phoneNumber;
  bool get phoneVerified => _phoneVerified;
  bool get kycSubmitted => _kycSubmitted;
  bool get isAdmin => _role == 'admin';
  String get firstName => _profileName.split(' ').first;
  KycTier get tier => _kycSubmitted ? KycTier.full : KycTier.tier1;
  String get kycTier => tier.label;
  String get kycLimitSummary =>
      '${_money.format(tier.perTransferLimit)} per transfer · ${_money.format(tier.dailyLimit)} daily';
  double get spentToday => _spentDate == _todayKey() ? _spentToday : 0;
  double get remainingDailyLimit =>
      (tier.dailyLimit - spentToday).clamp(0, tier.dailyLimit);
  String get totalBalance => _money.format(
    _accounts.fold<double>(0, (total, account) => total + account.balanceUsd),
  );

  List<KashTransaction> get recentTransactions {
    return _accounts.expand((account) => account.transactions).take(6).toList();
  }

  KashAccount accountByType(KashAccountType type) {
    return _accounts.firstWhere((account) => account.type == type);
  }

  // ── Identity ────────────────────────────────────────────────────
  void completeSignup({required String fullName, required String phoneNumber}) {
    _profileName = fullName.trim().isEmpty ? 'Mohamed Ali' : fullName.trim();
    _phoneNumber =
        phoneNumber.trim().isEmpty ? '+252 61 000 0000' : phoneNumber.trim();
    _persist();
    notifyListeners();
  }

  void verifyPhone() {
    _phoneVerified = true;
    _persist();
    notifyListeners();
  }

  void submitKyc({required bool fullVerification}) {
    _kycSubmitted = fullVerification;
    _persist();
    notifyListeners();
  }

  // ── Money movement ──────────────────────────────────────────────
  Future<TransferResult> submitTransfer({
    required KashAccountType sourceType,
    required String rail,
    required String recipient,
    required double amount,
  }) async {
    if (amount <= 0) {
      return const TransferResult.failure('Enter an amount greater than 0.');
    }

    if (recipient.trim().isEmpty) {
      return const TransferResult.failure('Add a recipient before review.');
    }

    if (ApiService.hasSession && rail == 'RoyallPay user') {
      try {
        final response = await ApiService.createP2pTransfer(
          recipient: recipient.trim(),
          currency: sourceType == KashAccountType.mobileMoney ? 'KES' : 'USD',
          amount: amount,
          memo: 'Hybrid wallet transfer',
        );
        final transfer = response['transfer'] as Map<String, dynamic>?;
        await syncFromBackend();
        return TransferResult.success(
          '${_money.format(amount)} sent through RoyallPay.',
          transactionId: transfer?['id']?.toString(),
        );
      } on ApiException catch (err) {
        return TransferResult.failure(err.message);
      } catch (_) {
        return const TransferResult.failure(
          'Could not reach the live transfer service. Try again.',
        );
      }
    }

    // ── Compliance checks (Phase 1) ──────────────────────────────
    final sanctionsHit = _screenSanctions(recipient);
    if (sanctionsHit != null) {
      _openCase(
        AmlCaseKind.sanctionsHit,
        recipient.trim(),
        'Recipient matched screening term "$sanctionsHit". Transfer blocked pending review.',
      );
      _persist();
      notifyListeners();
      return const TransferResult.failure(
        'Transfer blocked: recipient requires compliance review.',
      );
    }

    if (amount > tier.perTransferLimit) {
      _openCase(
        AmlCaseKind.limitBreach,
        recipient.trim(),
        'Attempted ${_money.format(amount)} vs ${tier.label} per-transfer limit ${_money.format(tier.perTransferLimit)}.',
      );
      _persist();
      notifyListeners();
      return TransferResult.failure(
        '${tier.label} limit is ${_money.format(tier.perTransferLimit)} per transfer. Complete KYC to raise limits.',
      );
    }

    if (amount > remainingDailyLimit) {
      return TransferResult.failure(
        'Daily limit reached: ${_money.format(remainingDailyLimit)} remaining today on ${tier.label}.',
      );
    }

    final source = accountByType(sourceType);
    final fee = transferFee(rail);
    final debit = amount + fee;
    final transactionId = _nextTransactionId();
    final postedAt = DateTime.now();

    if (source.balanceUsd < debit) {
      return TransferResult.failure('Not enough balance in ${source.title}.');
    }

    // Velocity monitoring: many transfers in a short window gets flagged
    // (transaction still proceeds; the case lands in the Ops queue).
    _recentTransferTimes.add(postedAt);
    _recentTransferTimes.removeWhere(
      (time) => postedAt.difference(time).inMinutes >= 10,
    );
    if (_recentTransferTimes.length >= 4) {
      _openCase(
        AmlCaseKind.velocity,
        _profileName,
        '${_recentTransferTimes.length} transfers within 10 minutes.',
      );
      _recentTransferTimes.clear();
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

    _recordDailySpend(amount + fee);
    _persist();
    notifyListeners();
    return TransferResult.success(
      '${_money.format(amount)} transfer queued through $rail.',
      transactionId: transactionId,
    );
  }

  double transferFee(String rail) {
    switch (rail) {
      case 'RoyallPay user':
        return 0;
      case 'Crypto address':
        return 1.25;
      case 'Bank account':
        return 0.75;
      default:
        return 0.30;
    }
  }

  List<LedgerTransaction> _parseBackendLedger(List<dynamic> rows) {
    return rows.map((row) {
      final tx = Map<String, dynamic>.from(row as Map);
      final id = tx['id'].toString();
      final postedAt =
          DateTime.tryParse(tx['posted_at']?.toString() ?? '') ??
          DateTime.now();
      final entries =
          ((tx['entries'] as List?) ?? []).asMap().entries.map((entry) {
            final value = Map<String, dynamic>.from(entry.value as Map);
            final direction = value['direction']?.toString().toLowerCase();
            final accountName = value['account_name']?.toString() ?? 'Ledger';
            return LedgerEntry(
              id: '$id-${entry.key + 1}',
              transactionId: id,
              postedAt: postedAt,
              accountType: _accountTypeFor(accountName, tx['rail']?.toString()),
              direction:
                  direction == 'debit'
                      ? LedgerDirection.debit
                      : LedgerDirection.credit,
              amountUsd:
                  (value['amount_usd'] as num?)?.toDouble() ??
                  double.tryParse(value['amount_usd']?.toString() ?? '') ??
                  0,
              accountName: accountName,
              memo: value['memo']?.toString() ?? '',
            );
          }).toList();
      return LedgerTransaction(
        id: id,
        postedAt: postedAt,
        title: tx['title']?.toString() ?? 'Ledger transaction',
        rail: tx['rail']?.toString() ?? 'RoyallPay',
        status: tx['status']?.toString() ?? 'Posted',
        entries: entries,
      );
    }).toList();
  }

  KashAccountType _accountTypeFor(String accountName, String? rail) {
    final value = '${accountName.toLowerCase()} ${rail?.toLowerCase() ?? ''}';
    if (value.contains('crypto') ||
        value.contains('custody') ||
        value.contains('btc') ||
        value.contains('eth') ||
        value.contains('usdt')) {
      return KashAccountType.crypto;
    }
    if (value.contains('bank') || value.contains('virtual')) {
      return KashAccountType.bank;
    }
    return KashAccountType.mobileMoney;
  }

  // ── AML ─────────────────────────────────────────────────────────
  void clearAmlCase(String id) {
    final index = _amlCases.indexWhere((amlCase) => amlCase.id == id);
    if (index == -1) return;
    _amlCases[index] = _amlCases[index].copyWith(status: 'Cleared');
    _persist();
    notifyListeners();
  }

  String? _screenSanctions(String recipient) {
    final normalized = recipient.trim().toLowerCase();
    for (final term in _sanctionsList) {
      if (normalized.contains(term)) return term;
    }
    return null;
  }

  void _openCase(AmlCaseKind kind, String subject, String details) {
    _amlCases.insert(
      0,
      AmlCase(
        id: 'AML-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        kind: kind,
        subject: subject,
        details: details,
      ),
    );
  }

  void _recordDailySpend(double amount) {
    final today = _todayKey();
    if (_spentDate != today) {
      _spentDate = today;
      _spentToday = 0;
    }
    _spentToday += amount;
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Persistence ─────────────────────────────────────────────────
  void _persist() {
    final state = {
      'profileName': _profileName,
      'phoneNumber': _phoneNumber,
      'phoneVerified': _phoneVerified,
      'kycSubmitted': _kycSubmitted,
      'role': _role,
      'ledgerSequence': _ledgerSequence,
      'spentToday': _spentToday,
      'spentDate': _spentDate,
      'accounts':
          _accounts
              .map(
                (account) => {
                  'type': account.type.index,
                  'balanceUsd': account.balanceUsd,
                  'status': account.status,
                  'transactions':
                      account.transactions
                          .map((transaction) => transaction.toJson())
                          .toList(),
                },
              )
              .toList(),
      'ledger':
          _ledgerTransactions
              .map((transaction) => transaction.toJson())
              .toList(),
      'amlCases': _amlCases.map((amlCase) => amlCase.toJson()).toList(),
    };
    AuthService.prefs.setString(_stateKey, jsonEncode(state));
  }

  bool _restore() {
    final raw = AuthService.prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final state = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _profileName = state['profileName'] as String? ?? _profileName;
      _phoneNumber = state['phoneNumber'] as String? ?? _phoneNumber;
      _phoneVerified = state['phoneVerified'] as bool? ?? false;
      _kycSubmitted = state['kycSubmitted'] as bool? ?? false;
      _role = state['role'] as String? ?? 'user';
      _ledgerSequence = state['ledgerSequence'] as int? ?? 1004;
      _spentToday = (state['spentToday'] as num?)?.toDouble() ?? 0;
      _spentDate = state['spentDate'] as String? ?? '';

      final storedAccounts = (state['accounts'] as List?) ?? [];
      _accounts =
          kashAccounts.map((template) {
            final match = storedAccounts.cast<Map>().firstWhere(
              (stored) => stored['type'] == template.type.index,
              orElse: () => const {},
            );
            if (match.isEmpty) {
              return template.copyWith(balanceUsd: 0, transactions: const []);
            }
            return template.copyWith(
              balanceUsd: (match['balanceUsd'] as num?)?.toDouble() ?? 0,
              status: match['status'] as String? ?? template.status,
              transactions:
                  ((match['transactions'] as List?) ?? [])
                      .map(
                        (transaction) => KashTransaction.fromJson(
                          Map<String, dynamic>.from(transaction as Map),
                        ),
                      )
                      .toList(),
            );
          }).toList();

      _ledgerTransactions
        ..clear()
        ..addAll(
          ((state['ledger'] as List?) ?? []).map(
            (transaction) => LedgerTransaction.fromJson(
              Map<String, dynamic>.from(transaction as Map),
            ),
          ),
        );

      _amlCases
        ..clear()
        ..addAll(
          ((state['amlCases'] as List?) ?? []).map(
            (amlCase) =>
                AmlCase.fromJson(Map<String, dynamic>.from(amlCase as Map)),
          ),
        );

      return _ledgerTransactions.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Wipes persisted money state (used by Ops console for pilot resets).
  void resetSandbox() {
    AuthService.prefs.remove(_stateKey);
    _accounts =
        List<KashAccount>.from(kashAccounts).map((account) {
          return account.copyWith(balanceUsd: 0, transactions: const []);
        }).toList();
    _ledgerTransactions.clear();
    _amlCases.clear();
    _spentToday = 0;
    _spentDate = '';
    _ledgerSequence = 1004;
    _persist();
    notifyListeners();
    syncFromBackend();
  }

  String _nextTransactionId() {
    _ledgerSequence++;
    return 'KFL-${_ledgerSequence.toString().padLeft(6, '0')}';
  }
}
