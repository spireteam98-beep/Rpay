import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../services/download_service.dart';
import 'bybit_wallet_ui.dart';
import 'receipt_ticket.dart';
import 'touch_scale.dart';

/// Shows [ReceiptTicket] in a dialog with Share / Save-as-image actions,
/// then pops [popCount] routes on "Done" — pass 2 to close both this dialog
/// and the screen that launched it (matching the confirm-flow screens'
/// existing pop-twice-back-to-the-tab pattern).
Future<void> showReceiptDialog(
  BuildContext context, {
  required String statusTitle,
  required String reference,
  required String dateTime,
  required String paymentMethod,
  required List<ReceiptLine> details,
  required List<ReceiptLine> amountLines,
  required ReceiptLine total,
  int popCount = 2,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder:
        (_) => ReceiptDialog(
          statusTitle: statusTitle,
          reference: reference,
          dateTime: dateTime,
          paymentMethod: paymentMethod,
          details: details,
          amountLines: amountLines,
          total: total,
          popCount: popCount,
        ),
  );
}

class ReceiptDialog extends StatefulWidget {
  final String statusTitle;
  final String reference;
  final String dateTime;
  final String paymentMethod;
  final List<ReceiptLine> details;
  final List<ReceiptLine> amountLines;
  final ReceiptLine total;
  final int popCount;

  const ReceiptDialog({
    super.key,
    required this.statusTitle,
    required this.reference,
    required this.dateTime,
    required this.paymentMethod,
    required this.details,
    required this.amountLines,
    required this.total,
    this.popCount = 2,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final GlobalKey _captureKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _captureImage() async {
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final bytes = await _captureImage();
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) {
      _showMessage('Could not generate receipt image.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'wayaki-receipt-${widget.reference}.png',
          ),
        ],
        text: 'Wayaki payment receipt — ${widget.reference}',
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final bytes = await _captureImage();
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) {
      _showMessage('Could not generate receipt image.');
      return;
    }
    DownloadService.downloadBytes(bytes, 'wayaki-receipt-${widget.reference}.png');
    if (!mounted) return;
    _showMessage('Receipt saved.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _done() {
    var remaining = widget.popCount;
    while (remaining > 0 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      remaining--;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _captureKey,
              child: ReceiptTicket(
                statusTitle: widget.statusTitle,
                reference: widget.reference,
                dateTime: widget.dateTime,
                paymentMethod: widget.paymentMethod,
                details: widget.details,
                amountLines: widget.amountLines,
                total: widget.total,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: _busy ? null : _share,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.download_rounded,
                    label: 'Save image',
                    onTap: _busy ? null : _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BybitPrimaryButton(label: 'Done', onTap: _done),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return TouchScale(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF242832)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BybitPalette.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
