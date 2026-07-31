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
  String _email = '';
  String? _username;
  String _walletIdType = 'phone';
  bool _phoneVerified = false;
  bool _kycSubmitted = false;
  bool _hasPin = false;
  bool _hasPassword = false;
  bool _biometricEnabled = false;
  bool _trustedDevice = true;
  bool _notifyPush = true;
  bool _notifySms = true;
  bool _notifyEmail = false;
  String _role = 'user';
  int _ledgerSequence = 1004;
  final List<LedgerTransaction> _ledgerTransactions = [];
  final List<Map<String, dynamic>> _frequentRecipients = [];
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
    final meFuture = ApiService.me();
    final hybridFuture = ApiService.hybridWallet();
    final bankFuture = ApiService.bankAccount();
    final ledgerFuture = ApiService.ledgerTransactions();
    final frequentRecipientsFuture = ApiService.frequentRecipients();

    // Publish the wallet balance as soon as it arrives. Bank-account and
    // ledger endpoints must never hold the dashboard header at its old value.
    final hybrid = await hybridFuture;
    if (hybrid != null) {
      _applyHybridBalances(hybrid);
      _persist();
      notifyListeners();
    }

    final results = await Future.wait<dynamic>([
      meFuture,
      bankFuture,
      ledgerFuture,
      frequentRecipientsFuture,
    ]);
    final me = results[0] as Map<String, dynamic>?;
    final bank = results[1] as Map<String, dynamic>?;
    final backendLedger = results[2] as List<dynamic>?;
    final frequentRecipients = results[3] as List<Map<String, dynamic>>?;
    if (frequentRecipients != null) {
      _frequentRecipients
        ..clear()
        ..addAll(frequentRecipients);
    }
    if (me == null && hybrid == null && bank == null && backendLedger == null) {
      return;
    }

    if (me != null) {
      _profileName = me['full_name'] as String? ?? _profileName;
      _phoneNumber = me['phone'] as String? ?? _phoneNumber;
      _email = me['email'] as String? ?? _email;
      _username = me['username'] as String?;
      _walletIdType = me['wallet_id_type'] as String? ?? _walletIdType;
      _phoneVerified = me['phone_verified'] == true;
      final kycTier = me['kyc_tier'];
      _kycSubmitted = kycTier is num ? kycTier >= 2 : _kycSubmitted;
      _role = me['role'] as String? ?? _role;
      _hasPin = me['has_pin'] == true;
      _hasPassword = me['has_password'] == true;
    }

    _accounts =
        _accounts.map((account) {
          switch (account.type) {
            case KashAccountType.walletUsd:
              return account;
            case KashAccountType.walletKes:
              return account;
            case KashAccountType.crypto:
              return account;
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

  void _applyHybridBalances(Map<String, dynamic> hybrid) {
    final fiat = hybrid['fiat'] as Map<String, dynamic>?;
    final crypto = hybrid['crypto'] as Map<String, dynamic>?;
    final usd = _asDouble(fiat?['USD']);
    final kes = _asDouble(fiat?['KES']);
    final kesPerUsd = _asDouble(fiat?['kesPerUsd']);
    final kesAsUsd = kesPerUsd > 0 ? kes / kesPerUsd : 0.0;
    final cryptoTotal = _asDouble(crypto?['totalUsd']);
    final depositAddress = crypto?['depositAddress'] as String?;

    _accounts =
        _accounts.map((account) {
          switch (account.type) {
            case KashAccountType.walletUsd:
              return account.copyWith(balanceUsd: usd, nativeAmount: usd);
            case KashAccountType.walletKes:
              return account.copyWith(
                balanceUsd: kesAsUsd.toDouble(),
                nativeAmount: kes,
              );
            case KashAccountType.crypto:
              return account.copyWith(
                balanceUsd: cryptoTotal,
                nativeAmount: cryptoTotal,
                status:
                    (depositAddress == null || depositAddress.isEmpty)
                        ? account.status
                        : 'Deposit address $depositAddress',
              );
            case KashAccountType.bank:
              return account;
          }
        }).toList();
  }

  // ── Getters ─────────────────────────────────────────────────────
  List<KashAccount> get accounts => List.unmodifiable(_accounts);

  /// The accounts actually shown in the app — Wayaki USD and Wayaki KES.
  /// Crypto custody and the virtual bank account stay in [_accounts] (kept
  /// in sync in the background) but are hidden from the UI until later.
  List<KashAccount> get visibleAccounts =>
      List.unmodifiable(_accounts.where((account) => account.isVisible));
  List<LedgerTransaction> get ledgerTransactions =>
      List.unmodifiable(_ledgerTransactions);
  List<LedgerEntry> get ledgerEntries => List.unmodifiable(
    _ledgerTransactions.expand((transaction) => transaction.entries).toList(),
  );
  List<AmlCase> get amlCases => List.unmodifiable(_amlCases);
  List<Map<String, dynamic>> get frequentRecipients =>
      List.unmodifiable(_frequentRecipients);
  int get openAmlCases =>
      _amlCases.where((amlCase) => amlCase.status == 'Open').length;
  String get profileName => _profileName;
  String get phoneNumber => _phoneNumber;
  String get email => _email;
  String? get username => _username;
  String get walletIdType => _walletIdType;

  /// The identifier this user hands out to receive money — whichever of
  /// phone / email / username they chose as their Wallet ID during signup.
  String get walletId {
    switch (_walletIdType) {
      case 'email':
        return _email;
      case 'username':
        return _username ?? _phoneNumber;
      case 'phone':
      default:
        return _phoneNumber;
    }
  }

  void setWalletIdLocal({required String type, String? username}) {
    _walletIdType = type;
    if (username != null) _username = username;
    _persist();
    notifyListeners();
  }

  bool get phoneVerified => _phoneVerified;
  bool get kycSubmitted => _kycSubmitted;
  bool get hasPin => _hasPin;
  bool get hasPassword => _hasPassword;
  bool get biometricEnabled => _biometricEnabled;
  bool get trustedDevice => _trustedDevice;
  bool get notifyPush => _notifyPush;
  bool get notifySms => _notifySms;
  bool get notifyEmail => _notifyEmail;
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
    visibleAccounts.fold<double>(
      0,
      (total, account) => total + account.balanceUsd,
    ),
  );

  List<KashTransaction> get recentTransactions {
    return visibleAccounts
        .expand((account) => account.transactions)
        .take(6)
        .toList();
  }

  KashAccount accountByType(KashAccountType type) {
    return _accounts.firstWhere((account) => account.type == type);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ── Identity ────────────────────────────────────────────────────
  void completeSignup({
    required String fullName,
    required String phoneNumber,
    String? email,
  }) {
    _profileName = fullName.trim().isEmpty ? 'Mohamed Ali' : fullName.trim();
    _phoneNumber =
        phoneNumber.trim().isEmpty ? '+252 61 000 0000' : phoneNumber.trim();
    if (email != null && email.trim().isNotEmpty) _email = email.trim();
    _persist();
    notifyListeners();
  }

  void verifyPhone() {
    _phoneVerified = true;
    _persist();
    notifyListeners();
  }

  void updateProfileNameLocal(String fullName) {
    _profileName = fullName;
    _persist();
    notifyListeners();
  }

  void updateEmailLocal(String email) {
    _email = email;
    _persist();
    notifyListeners();
  }

  void submitKyc({required bool fullVerification}) {
    _kycSubmitted = fullVerification;
    _persist();
    notifyListeners();
  }

  void markPinSet() {
    _hasPin = true;
    _persist();
    notifyListeners();
  }

  void setBiometricEnabled(bool value) {
    _biometricEnabled = value;
    _persist();
    notifyListeners();
  }

  void setTrustedDevice(bool value) {
    _trustedDevice = value;
    _persist();
    notifyListeners();
  }

  void setNotificationPrefs({bool? push, bool? sms, bool? email}) {
    if (push != null) _notifyPush = push;
    if (sms != null) _notifySms = sms;
    if (email != null) _notifyEmail = email;
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

    if (ApiService.hasSession && rail == 'Wayaki') {
      try {
        final response = await ApiService.createP2pTransfer(
          recipient: recipient.trim(),
          currency: sourceType == KashAccountType.walletKes ? 'KES' : 'USD',
          amount: amount,
          memo: 'Hybrid wallet transfer',
        );
        final transfer = response['transfer'] as Map<String, dynamic>?;
        await syncFromBackend();
        return TransferResult.success(
          '${_money.format(amount)} sent through Wayaki.',
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

    // M-Pesa (phone or Till) can be funded from either wallet (see
    // SendMoneyScreen._channelList) — `amount` is in whatever currency the
    // source account is in, sent as-is; the backend alone converts
    // USD->KES for the actual M-Pesa payout, using its own exchange rate
    // (see ApiService.submitMobileMoneyWithdrawal for why this side never
    // does that math). Fires a real Paystack payout to `recipient` (the
    // phone number or till number typed in), not the local simulated
    // ledger below.
    if (ApiService.hasSession && (rail == 'M-Pesa' || rail == 'M-Pesa Till')) {
      final sourceCurrency = sourceType == KashAccountType.walletUsd ? 'USD' : 'KES';
      final isTill = rail == 'M-Pesa Till';
      try {
        final response = await ApiService.submitMobileMoneyWithdrawal(
          rail: rail,
          amount: amount,
          phone: isTill ? null : recipient.trim(),
          tillNumber: isTill ? recipient.trim() : null,
          sourceCurrency: sourceCurrency,
        );
        // The payout has already been accepted at this point. Refreshing the
        // wallet is best-effort: a timeout from any of the dashboard's
        // follow-up endpoints must not turn a successful M-Pesa payout into
        // a false "could not reach the transfer service" result.
        try {
          await syncFromBackend();
        } catch (_) {
          // The next normal app refresh will reconcile the balance/ledger.
        }
        return TransferResult.success(
          response?['message'] as String? ?? 'Withdrawal submitted.',
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

  /// Converts between the user's own Wayaki USD and Wayaki KES wallets at
  /// the backend's fixed rate — the "intentionally convert to USD" bridge.
  /// Requires a live session; there's no offline/local simulation of this
  /// since the rate and the ledger posting both live on the backend.
  Future<TransferResult> convertCurrency({
    required String from,
    required String to,
    required double amount,
  }) async {
    if (amount <= 0) {
      return const TransferResult.failure('Enter an amount greater than 0.');
    }
    if (!ApiService.hasSession) {
      return const TransferResult.failure(
        'Sign in to convert between USD and KES.',
      );
    }
    try {
      final response = await ApiService.convert(
        from: from,
        to: to,
        amount: amount,
      );
      await syncFromBackend();
      final converted = (response['convertedAmount'] as num).toDouble();
      return TransferResult.success(
        'Converted ${amount.toStringAsFixed(2)} $from to ${converted.toStringAsFixed(2)} $to.',
      );
    } on ApiException catch (err) {
      return TransferResult.failure(err.message);
    } catch (_) {
      return const TransferResult.failure(
        'Could not reach the conversion service. Try again.',
      );
    }
  }

  double transferFee(String rail) {
    switch (rail) {
      case 'Wayaki':
        return 0;
      // No fee for now — the real Paystack payout (services/paystackTransfers.js)
      // doesn't deduct one either. Left at 0 until an admin-configurable fee
      // is built; don't let this drift from the backend in the meantime.
      case 'M-Pesa':
      case 'M-Pesa Till':
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
        rail: tx['rail']?.toString() ?? 'Wayaki',
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
    if (value.contains('kes') ||
        value.contains('m-pesa') ||
        value.contains('mpesa')) {
      return KashAccountType.walletKes;
    }
    return KashAccountType.walletUsd;
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
      'email': _email,
      'username': _username,
      'walletIdType': _walletIdType,
      'phoneVerified': _phoneVerified,
      'kycSubmitted': _kycSubmitted,
      'hasPin': _hasPin,
      'hasPassword': _hasPassword,
      'biometricEnabled': _biometricEnabled,
      'trustedDevice': _trustedDevice,
      'notifyPush': _notifyPush,
      'notifySms': _notifySms,
      'notifyEmail': _notifyEmail,
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
                  'nativeAmount': account.nativeAmount,
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
      _email = state['email'] as String? ?? _email;
      _username = state['username'] as String?;
      _walletIdType = state['walletIdType'] as String? ?? _walletIdType;
      _phoneVerified = state['phoneVerified'] as bool? ?? false;
      _kycSubmitted = state['kycSubmitted'] as bool? ?? false;
      _hasPin = state['hasPin'] as bool? ?? false;
      _hasPassword = state['hasPassword'] as bool? ?? false;
      _biometricEnabled = state['biometricEnabled'] as bool? ?? false;
      _trustedDevice = state['trustedDevice'] as bool? ?? true;
      _notifyPush = state['notifyPush'] as bool? ?? true;
      _notifySms = state['notifySms'] as bool? ?? true;
      _notifyEmail = state['notifyEmail'] as bool? ?? false;
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
              nativeAmount: (match['nativeAmount'] as num?)?.toDouble() ?? 0,
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
    return 'WYK-${_ledgerSequence.toString().padLeft(6, '0')}';
  }
}
