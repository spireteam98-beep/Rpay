import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/ledger_entry.dart';
import '../state/kash_app_state.dart';
import '../widgets/kash_widgets.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<KashAppState>().ledgerTransactions;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Core ledger'),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: AppTheme.heroCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleIcon(
                    Icons.account_tree_outlined,
                    color: AppTheme.onLime,
                    size: 52,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Double-entry ledger',
                    style: TextStyle(
                      color: AppTheme.onLime,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${ledger.length} transaction batches tracked',
                    style: const TextStyle(
                      color: AppTheme.onLime,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...ledger.map(_ledgerBatch),
          ],
        ),
      ),
    );
  }

  Widget _ledgerBatch(LedgerTransaction transaction) {
    final time = DateFormat('MMM d, HH:mm').format(transaction.postedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleIcon(
                  transaction.isBalanced
                      ? Icons.check_rounded
                      : Icons.warning_amber_rounded,
                  size: 42,
                  color:
                      transaction.isBalanced ? AppTheme.onLime : AppTheme.priceDown,
                  bg:
                      transaction.isBalanced ? AppTheme.primaryColor : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${transaction.id} - ${transaction.rail} - $time',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  transaction.status,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...transaction.entries.map(_entryRow),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(LedgerEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: entry.direction == LedgerDirection.debit
                  ? AppTheme.priceDown
                  : AppTheme.priceUp,
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
                    color: AppTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.memo,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.amountLabel,
            style: TextStyle(
              color: entry.direction == LedgerDirection.debit
                  ? AppTheme.priceDown
                  : AppTheme.priceUp,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
