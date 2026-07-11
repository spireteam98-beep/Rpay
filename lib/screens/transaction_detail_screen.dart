import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ledger_entry.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Receipt-style detail for a single ledger transaction — fed directly by
/// the [LedgerTransaction] already loaded in [KashAppState.ledgerTransactions],
/// no extra fetch needed since the list endpoint already returns entries.
class TransactionDetailScreen extends StatelessWidget {
  final LedgerTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final balanced = transaction.isBalanced;
    final time = DateFormat('MMM d, yyyy · HH:mm').format(transaction.postedAt);
    final net = transaction.credits - transaction.debits;
    final money = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Transaction'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: BybitPalette.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor:
                          balanced
                              ? BybitPalette.accent
                              : BybitPalette.red.withOpacity(0.16),
                      child: Icon(
                        balanced
                            ? Icons.check_rounded
                            : Icons.error_outline_rounded,
                        color: balanced ? Colors.black : BybitPalette.red,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      transaction.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      net == 0
                          ? money.format(transaction.debits)
                          : (net > 0 ? '+' : '') + money.format(net),
                      style: TextStyle(
                        color: net > 0 ? BybitPalette.green : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _field('Status', transaction.status),
              const SizedBox(height: 10),
              _field('Rail', transaction.rail),
              const SizedBox(height: 10),
              TouchScale(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: transaction.id));
                  BybitToast.show(context, 'Reference copied');
                },
                child: _field('Reference', transaction.id, copyable: true),
              ),
              const SizedBox(height: 10),
              _field('Date', time),
              const SizedBox(height: 24),
              const Text(
                'Entries',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              BybitCard(
                child: Column(
                  children: transaction.entries.map(_entryRow).toList(),
                ),
              ),
              const SizedBox(height: 24),
              BybitPrimaryButton(
                label: 'Contact support',
                onTap: () => showSupportDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, {bool copyable = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.copy_rounded,
              color: BybitPalette.accent,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _entryRow(LedgerEntry entry) {
    final isDebit = entry.direction == LedgerDirection.debit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDebit ? BybitPalette.red : BybitPalette.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.accountName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.memo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.memo,
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            entry.amountLabel,
            style: TextStyle(
              color: isDebit ? BybitPalette.red : BybitPalette.green,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
