import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';

/// E-receipt for one Fareenn card payment. The same receipt is sent to the
/// customer and to the merchant; the customer sees their full name, the
/// merchant sees first name + initial.
class ReceiptScreen extends StatefulWidget {
  final String receiptId;
  const ReceiptScreen({super.key, required this.receiptId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Map<String, dynamic>? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.nfcReceipt(widget.receiptId).then((r) {
      if (mounted) setState(() => _r = r);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load the receipt.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('E-receipt'),
      body: SafeArea(
        child: _r == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator(color: BybitPalette.accent)
                    : Text(_error!, style: const TextStyle(color: BybitPalette.muted)),
              )
            : _receipt(_r!),
      ),
    );
  }

  Widget _receipt(Map<String, dynamic> r) {
    final ok = r['status'] == 'COMPLETED';
    final at = DateTime.tryParse(r['at'] as String? ?? '')?.toLocal();
    final currency = r['currency'] as String? ?? '';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final money = '${currency == 'USD' ? '\$' : '$currency '}${amount.toStringAsFixed(2)}';
    final isMerchant = r['viewer'] == 'merchant';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: BybitPalette.surface, borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: ok ? BybitPalette.accent : BybitPalette.red.withAlpha(40),
              child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: ok ? Colors.black : BybitPalette.red, size: 32),
            ),
            const SizedBox(height: 12),
            Text(ok ? (isMerchant ? 'Payment received' : 'Payment successful') : 'Payment declined',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(money, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
            if (!ok && r['reason'] != null) ...[
              const SizedBox(height: 6),
              Text(r['reason'] as String, style: const TextStyle(color: BybitPalette.red, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            const Divider(color: Color(0x22FFFFFF)),
            _line('Merchant', r['merchant'] as String? ?? ''),
            _line('Till number', r['tillNumber'] as String? ?? ''),
            _line(isMerchant ? 'Customer' : 'Paid by', r['holder'] as String? ?? ''),
            _line('Card', '•••• ${r['last4'] ?? ''}'),
            _line('Method', r['method'] as String? ?? 'Fareenn card'),
            if (at != null) _line('Date', DateFormat('d MMM yyyy · HH:mm').format(at)),
            _line('Reference', r['ref'] as String? ?? '', copy: true),
            const SizedBox(height: 14),
            const Text('Fareenn e-receipt · keep this for your records',
                style: TextStyle(color: BybitPalette.muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool copy = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 13.5)),
            const Spacer(),
            Flexible(
              child: GestureDetector(
                onTap: copy
                    ? () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
                      }
                    : null,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
}
