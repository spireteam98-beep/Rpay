import 'package:intl/intl.dart';
import 'kash_account.dart';

enum LedgerDirection { debit, credit }

class LedgerEntry {
  final String id;
  final String transactionId;
  final DateTime postedAt;
  final KashAccountType accountType;
  final LedgerDirection direction;
  final double amountUsd;
  final String accountName;
  final String memo;

  LedgerEntry({
    required this.id,
    required this.transactionId,
    required this.postedAt,
    required this.accountType,
    required this.direction,
    required this.amountUsd,
    required this.accountName,
    required this.memo,
  });

  String get directionLabel =>
      direction == LedgerDirection.debit ? 'Debit' : 'Credit';

  String get amountLabel {
    final money = NumberFormat.currency(symbol: '\$');
    return '${direction == LedgerDirection.debit ? '-' : '+'}${money.format(amountUsd)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transactionId': transactionId,
    'postedAt': postedAt.toIso8601String(),
    'accountType': accountType.index,
    'direction': direction.index,
    'amountUsd': amountUsd,
    'accountName': accountName,
    'memo': memo,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as String,
    transactionId: json['transactionId'] as String,
    postedAt: DateTime.parse(json['postedAt'] as String),
    accountType: KashAccountType.values[json['accountType'] as int],
    direction: LedgerDirection.values[json['direction'] as int],
    amountUsd: (json['amountUsd'] as num).toDouble(),
    accountName: json['accountName'] as String,
    memo: json['memo'] as String,
  );
}

class LedgerTransaction {
  final String id;
  final DateTime postedAt;
  final String title;
  final String rail;
  final String status;
  final List<LedgerEntry> entries;

  LedgerTransaction({
    required this.id,
    required this.postedAt,
    required this.title,
    required this.rail,
    required this.status,
    required this.entries,
  });

  double get debits => entries
      .where((entry) => entry.direction == LedgerDirection.debit)
      .fold(0, (total, entry) => total + entry.amountUsd);

  double get credits => entries
      .where((entry) => entry.direction == LedgerDirection.credit)
      .fold(0, (total, entry) => total + entry.amountUsd);

  bool get isBalanced => (debits - credits).abs() < 0.001;

  Map<String, dynamic> toJson() => {
    'id': id,
    'postedAt': postedAt.toIso8601String(),
    'title': title,
    'rail': rail,
    'status': status,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) =>
      LedgerTransaction(
        id: json['id'] as String,
        postedAt: DateTime.parse(json['postedAt'] as String),
        title: json['title'] as String,
        rail: json['rail'] as String,
        status: json['status'] as String,
        entries:
            (json['entries'] as List)
                .map(
                  (entry) => LedgerEntry.fromJson(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .toList(),
      );
}
