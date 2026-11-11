import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart' show kashRoute;
import '../widgets/touch_scale.dart';
import 'receipt_screen.dart';
import 'messages_screen.dart';

/// Opens one notification: a payment receipt shows the e-receipt, anything
/// else shows the complete message.
void openNotification(BuildContext context, Map<String, dynamic> n) {
  final data = n['data'];
  final receiptId = data is Map ? data['receiptId'] as String? : null;
  // A message (incl. a reviewer asking for KYC changes) opens the chat so
  // the user can reply straight away.
  final chatWith = data is Map && n['kind'] == 'message' ? data['userId'] as String? : null;
  Navigator.of(context).push(kashRoute(
    receiptId != null
        ? ReceiptScreen(receiptId: receiptId)
        : chatWith != null
            ? ChatScreen(who: chatWith)
            : NotificationDetailScreen(notification: n),
  ));
}

IconData notificationIcon(String? kind) => switch (kind) {
      'receipt' => Icons.receipt_long_rounded,
      'message' => Icons.chat_bubble_outline_rounded,
      'support' => Icons.support_agent_rounded,
      'follow' => Icons.person_add_alt_1_rounded,
      'role' => Icons.verified_user_outlined,
      'account' => Icons.badge_outlined,
      _ => Icons.notifications_none_rounded,
    };

/// The complete text of one notification.
class NotificationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final at = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Notification'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: BybitPalette.surface, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: BybitPalette.accent.withAlpha(36),
                  child: Icon(notificationIcon(n['kind'] as String?), color: Colors.white, size: 24),
                ),
                const SizedBox(height: 16),
                Text(n['title'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                if (at != null) ...[
                  const SizedBox(height: 6),
                  Text(DateFormat('EEEE d MMM yyyy · HH:mm').format(at),
                      style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
                ],
                const SizedBox(height: 18),
                SelectableText(n['body'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In-app inbox: every notification the backend sends (payment receipts,
/// money received, messages, support replies, role changes) lands here,
/// so a user reachable only through the app still gets all of them.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // New notifications appear at the top while this screen is open.
    _live = RealtimeService.instance.incoming.listen((n) {
      if (!mounted) return;
      setState(() => _items = [n, ...?_items]);
      ApiService.markNotificationsRead([n['id'] as String]);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final body = await ApiService.notifications();
      final items = (body['notifications'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
      if (items.any((n) => n['read_at'] == null)) {
        await ApiService.markNotificationsRead();
        RealtimeService.instance.refreshCounts();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Notifications'),
      body: SafeArea(
        child: RefreshIndicator(
          color: BybitPalette.accent,
          onRefresh: _load,
          child: items == null
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: _error == null
                          ? const CircularProgressIndicator(color: BybitPalette.accent)
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: BybitPalette.muted)),
                            ),
                    ),
                  ],
                )
              : items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.notifications_off_outlined, color: BybitPalette.muted, size: 48),
                        SizedBox(height: 12),
                        Center(child: Text('No notifications yet', style: TextStyle(color: BybitPalette.muted, fontSize: 15))),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _tile(items[i]),
                    ),
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final unread = n['read_at'] == null;
    final at = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
    return TouchScale(
      onTap: () => openNotification(context, n),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: unread ? Border.all(color: BybitPalette.accent.withAlpha(120)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: BybitPalette.accent.withAlpha(36),
              child: Icon(notificationIcon(n['kind'] as String?), color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] as String? ?? '',
                    style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(n['body'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: BybitPalette.muted, fontSize: 13, height: 1.35)),
                  if (at != null) ...[
                    const SizedBox(height: 6),
                    Text(DateFormat('MMM d · HH:mm').format(at), style: const TextStyle(color: BybitPalette.muted, fontSize: 11.5)),
                  ],
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
