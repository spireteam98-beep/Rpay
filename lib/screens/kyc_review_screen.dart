import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../widgets/kash_widgets.dart' show kashRoute;
import 'messages_screen.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

/// Customers waiting for identity approval. Agents and Trustee Agents see
/// the customers they onboarded; Fareenn HQ ([admin]) sees customers who
/// joined without an agent. Approving issues the customer's Wallet ID.
class KycReviewScreen extends StatefulWidget {
  final bool admin;
  const KycReviewScreen({super.key, this.admin = false});

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends State<KycReviewScreen> {
  List<Map<String, dynamic>>? _customers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ApiService.kycPending(admin: widget.admin);
      if (mounted) setState(() => _customers = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _customers;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Customer approvals'),
      body: RefreshIndicator(
        color: BybitPalette.accent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              widget.admin
                  ? 'Customers who joined without an agent.'
                  : 'Customers you onboarded. Check their details and photos, then approve to issue their Wallet ID.',
              style: const TextStyle(color: BybitPalette.muted, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: BybitPalette.red))
            else if (list == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(color: BybitPalette.accent),
                ),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No customers waiting for approval.',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 15),
                  ),
                ),
              )
            else
              for (final c in list) ...[
                _row(c),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final name = c['full_name'] as String? ?? 'Customer';
    return TouchScale(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _KycDetailScreen(customer: c, admin: widget.admin),
          ),
        );
        if (changed == true) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: BybitPalette.accent,
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${c['phone'] ?? ''} · ${c['region'] ?? ''}',
                    style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BybitPalette.muted),
          ],
        ),
      ),
    );
  }
}

class _KycDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final bool admin;
  const _KycDetailScreen({required this.customer, required this.admin});

  @override
  State<_KycDetailScreen> createState() => _KycDetailScreenState();
}

class _KycDetailScreenState extends State<_KycDetailScreen> {
  Map<String, dynamic>? _docs;
  String? _error;
  bool _busy = false;

  /// Optional card to hand this customer, scanned before approving.
  String? _cardUid;
  bool _scanning = false;
  String? _cardError;

  Future<void> _scanCard() async {
    if (!NfcService.supported) {
      setState(() => _cardError = 'Card scanning needs the Fareenn Android app with NFC turned on.');
      return;
    }
    setState(() {
      _scanning = true;
      _cardError = null;
    });
    try {
      final tap = await NfcService.read(timeout: const Duration(seconds: 40));
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _cardUid = tap.uid);
    } on NfcException catch (e) {
      if (mounted) setState(() => _cardError = e.message);
    } catch (_) {
      if (mounted) setState(() => _cardError = 'Card read failed. Try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _cancelScan() {
    NfcService.stop();
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    NfcService.stop();
    super.dispose();
  }

  String _last4(String uid) => uid.length >= 4 ? uid.substring(uid.length - 4) : uid;

  Widget _cardSection() {
    final uid = _cardUid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: BybitPalette.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contactless_outlined, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Fareenn card (optional)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (uid != null && !_busy)
                TextButton(
                  onPressed: () => setState(() => _cardUid = null),
                  child: const Text('Remove', style: TextStyle(color: BybitPalette.muted)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            uid != null
                ? 'Card •••• ${_last4(uid)} scanned (serial $uid). It will be linked to this customer when you approve.'
                : _scanning
                    ? 'Hold the card on the back of this phone…'
                    : 'Hand the customer a card: scan it now and it is linked when you approve.',
            style: const TextStyle(color: BybitPalette.muted, fontSize: 13, height: 1.35),
          ),
          if (_cardError != null) ...[
            const SizedBox(height: 6),
            Text(_cardError!, style: const TextStyle(color: BybitPalette.red, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          if (_scanning)
            Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: BybitPalette.accent)),
                const Spacer(),
                TextButton(onPressed: _cancelScan, child: const Text('Cancel', style: TextStyle(color: Colors.white))),
              ],
            )
          else if (!_busy)
            TouchScale(
              onTap: _scanCard,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: BybitPalette.accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(uid == null ? 'Scan card' : 'Scan a different card',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  String get _id => widget.customer['id'] as String;

  @override
  void initState() {
    super.initState();
    ApiService.kycDocuments(_id, admin: widget.admin).then(
      (d) {
        if (mounted) setState(() => _docs = d);
      },
      onError: (e) {
        if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
      },
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final result = await ApiService.kycApprove(_id, admin: widget.admin, cardUid: _cardUid);
      final walletNumber = result['walletNumber']?.toString() ?? '';
      final card = result['card'];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BybitPalette.surface,
          title: const Text('Customer approved', style: TextStyle(color: Colors.white)),
          content: Text(
            'Wallet ID $walletNumber has been issued. The customer can now receive money with it.'
            '${card is Map ? '\n\nFareenn card •••• ${card['last4']} is linked and ready to tap and pay.' : ''}',
            style: const TextStyle(color: BybitPalette.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done', style: TextStyle(color: BybitPalette.accent)),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A card problem (already linked, too many cards) undoes the whole
        // approval; show it on the card section so they can rescan.
        if (e.code == 'CARD_ERROR') _cardError = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Problems a reviewer can tick when asking a customer to fix their KYC.
  static const _kycIssues = [
    'ID photo is blurry or unreadable',
    'ID document is expired',
    'Back of the ID is missing',
    'Selfie does not match the ID',
    'Selfie is unclear',
    'Name does not match the ID',
    'Address is missing or incomplete',
    'ID number does not match the photo',
  ];

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final picked = <String>{};
    final result = await showModalBottomSheet<(List<String>, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What needs fixing?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tick every issue. The customer gets this as a chat message they can reply to.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final issue in _kycIssues)
                      FilterChip(
                        label: Text(issue),
                        selected: picked.contains(issue),
                        onSelected: (on) => setSheet(() => on ? picked.add(issue) : picked.remove(issue)),
                        backgroundColor: BybitPalette.surface2,
                        selectedColor: BybitPalette.accent,
                        checkmarkColor: Colors.white,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a message (optional)',
                    hintStyle: const TextStyle(color: BybitPalette.muted),
                    filled: true,
                    fillColor: BybitPalette.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BybitPrimaryButton(
                  label: 'Send to customer',
                  onTap: () => Navigator.of(ctx).pop((picked.toList(), noteCtrl.text.trim())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    final (issues, note) = result;
    if (issues.isEmpty && note.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick an issue or write a message so the customer can fix it')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.kycReject(_id, note, admin: widget.admin, issues: issues);
      if (!mounted) return;
      final openChat = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BybitPalette.surface,
          title: const Text('Changes requested', style: TextStyle(color: Colors.white)),
          content: const Text(
            'The customer got your message. Their reply will arrive in Messages.',
            style: TextStyle(color: BybitPalette.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Done', style: TextStyle(color: BybitPalette.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open chat', style: TextStyle(color: BybitPalette.accent)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (openChat == true) {
        // Swap this review page for the chat; the list still refreshes.
        Navigator.of(context).pushReplacement(
          kashRoute(ChatScreen(who: _id, name: widget.customer['full_name'] as String?)),
          result: true,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final docType = c['doc_type'] == 'passport' ? 'Passport' : 'NIRA ID';
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: BybitSubHeader(c['full_name'] as String? ?? 'Customer'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _info('Phone', c['phone']),
          _info('Email', c['email']),
          _info('Gender', c['gender'] == 'female' ? 'Female' : (c['gender'] == 'male' ? 'Male' : '')),
          _info('Region', c['region']),
          _info('Address', c['address']),
          _info(docType, c['doc_number']),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: BybitPalette.red))
          else if (_docs == null)
            const Center(child: CircularProgressIndicator(color: BybitPalette.accent))
          else ...[
            _photo('Customer photo', _docs!['selfie']),
            _photo('$docType — front', _docs!['front']),
            _photo('$docType — back', _docs!['back']),
          ],
          const SizedBox(height: 18),
          _cardSection(),
          const SizedBox(height: 14),
          BybitPrimaryButton(
            label: _busy
                ? 'Please wait…'
                : (_cardUid != null ? 'Approve, issue Wallet ID & link card' : 'Approve and issue Wallet ID'),
            enabled: !_busy && !_scanning && _docs != null,
            onTap: _approve,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _reject,
                icon: const Icon(Icons.report_gmailerrorred_rounded, color: BybitPalette.red, size: 20),
                label: const Text(
                  'Request changes',
                  style: TextStyle(color: BybitPalette.red, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          kashRoute(ChatScreen(who: _id, name: widget.customer['full_name'] as String?)),
                        ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 19),
                label: const Text(
                  'Message customer',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, Object? value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 13.5)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(String label, Object? img) {
    final map = img is Map ? img : null;
    final b64 = map?['base64'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: b64 == null
                ? Container(
                    height: 120,
                    color: BybitPalette.surface,
                    alignment: Alignment.center,
                    child: const Text('Not provided', style: TextStyle(color: BybitPalette.muted)),
                  )
                : Image.memory(base64Decode(b64), fit: BoxFit.cover, width: double.infinity),
          ),
        ],
      ),
    );
  }
}
