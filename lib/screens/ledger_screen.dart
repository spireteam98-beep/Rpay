import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_entry.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<KashAppState>().ledgerTransactions;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('History'),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          children: [
            const Text(
              'Transaction history',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${ledger.length} batches tracked across wallet rails',
              style: const TextStyle(color: BybitPalette.muted2, fontSize: 15),
            ),
            const SizedBox(height: 22),
            _filters(),
            const SizedBox(height: 18),
            if (ledger.isEmpty) _emptyState() else ...ledger.map(_ledgerBatch),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: BybitPalette.surface2, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: const [
          Expanded(child: _FilterChip('All', true)),
          Expanded(child: _FilterChip('Send', false)),
          Expanded(child: _FilterChip('Receive', false)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const BybitCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: BybitPalette.surface2,
            child: Icon(Icons.receipt_long_rounded, color: BybitPalette.muted, size: 32),
          ),
          SizedBox(height: 16),
          Text('No wallet history yet', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Cash in, send, receive, or trade to see activity here.', textAlign: TextAlign.center, style: TextStyle(color: BybitPalette.muted2, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _ledgerBatch(LedgerTransaction transaction) {
    final time = DateFormat('MMM d, HH:mm').format(transaction.postedAt);
    final balanced = transaction.isBalanced;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BybitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: balanced ? BybitPalette.green.withOpacity(0.15) : BybitPalette.red.withOpacity(0.15),
                  child: Icon(
                    balanced ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: balanced ? BybitPalette.green : BybitPalette.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('${transaction.id} - ${transaction.rail} - $time', style: const TextStyle(color: BybitPalette.muted2, fontSize: 12)),
                    ],
                  ),
                ),
                Text(transaction.status, style: const TextStyle(color: BybitPalette.accent, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            ...transaction.entries.map(_entryRow),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(LedgerEntry entry) {
    final isDebit = entry.direction == LedgerDirection.debit;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: isDebit ? BybitPalette.red : BybitPalette.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.accountName, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(entry.memo, style: const TextStyle(color: BybitPalette.muted2, fontSize: 12)),
              ],
            ),
          ),
          Text(entry.amountLabel, style: TextStyle(color: isDebit ? BybitPalette.red : BybitPalette.green, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? BybitPalette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : BybitPalette.muted,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
