import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart' show kashRoute;
import '../widgets/touch_scale.dart';

/// Everyone the user has messaged with — customers, agents, Trustees,
/// reviewers. A new message makes the list refresh live.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    _live = RealtimeService.instance.incoming.listen((n) {
      if (n['kind'] == 'message') _load();
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.conversations();
      if (mounted) setState(() { _items = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _newChat() async {
    final ctrl = TextEditingController();
    final to = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BybitPalette.surface,
        title: const Text('New message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Email, phone, @username or Fareenn ID',
            hintStyle: TextStyle(color: BybitPalette.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: BybitPalette.muted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Open chat', style: TextStyle(color: BybitPalette.accent)),
          ),
        ],
      ),
    );
    if (to == null || to.isEmpty || !mounted) return;
    await Navigator.of(context).push(kashRoute(ChatScreen(who: to)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Messages'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: BybitPalette.accent,
        onPressed: _newChat,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: BybitPalette.accent,
          onRefresh: _load,
          child: items == null
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Center(
                    child: _error == null
                        ? const CircularProgressIndicator(color: BybitPalette.accent)
                        : Text(_error!, style: const TextStyle(color: BybitPalette.muted)),
                  ),
                ])
              : items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Icon(Icons.chat_bubble_outline_rounded, color: BybitPalette.muted, size: 46),
                      SizedBox(height: 12),
                      Center(child: Text('No messages yet', style: TextStyle(color: BybitPalette.muted))),
                    ])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(items[i]),
                    ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final user = (c['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = user['fullName'] as String? ?? 'Fareenn user';
    final unread = (c['unread'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse(c['lastAt'] as String? ?? '')?.toLocal();
    return TouchScale(
      onTap: () async {
        await Navigator.of(context).push(kashRoute(ChatScreen(who: user['id'] as String, name: name)));
        _load();
        RealtimeService.instance.refreshCounts();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: BybitPalette.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: BybitPalette.accent,
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: Colors.white, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    '${c['lastFromMe'] == true ? 'You: ' : ''}${c['lastBody'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (at != null) Text(DateFormat('HH:mm').format(at), style: const TextStyle(color: BybitPalette.muted, fontSize: 11.5)),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: BybitPalette.accent, borderRadius: BorderRadius.circular(100)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One conversation. [who] is a user id or any identifier (email, phone,
/// @username, Fareenn ID). New messages from the other person appear live.
class ChatScreen extends StatefulWidget {
  final String who;
  final String? name;
  const ChatScreen({super.key, required this.who, this.name});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  String? _otherId;
  String? _otherName;
  String? _error;
  bool _sending = false;
  bool _loaded = false;
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _otherName = widget.name;
    _load();
    _live = RealtimeService.instance.incoming.listen((n) {
      final data = n['data'];
      if (n['kind'] == 'message' && data is Map && data['userId'] == _otherId) _load();
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final body = await ApiService.messageThread(_otherId ?? widget.who);
      final w = (body['with'] as Map?)?.cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _otherId = w?['id'] as String? ?? _otherId;
        _otherName = w?['fullName'] as String? ?? _otherName;
        _messages = (body['messages'] as List? ?? const []).cast<Map<String, dynamic>>();
        _loaded = true;
        _error = null;
      });
      _toBottom();
      RealtimeService.instance.refreshCounts();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loaded = true; });
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await ApiService.sendMessage(_otherId ?? widget.who, text);
      _ctrl.clear();
      if (mounted) setState(() => _messages = [..._messages, msg]);
      _toBottom();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: BybitSubHeader(_otherName ?? 'Chat'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator(color: BybitPalette.accent))
                  : _error != null && _messages.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: BybitPalette.muted)),
                        ))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _bubble(_messages[i]),
                        ),
            ),
            if (_otherId != null || _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: const TextStyle(color: BybitPalette.muted),
                          filled: true,
                          fillColor: BybitPalette.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: BybitPalette.accent),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['from_me'] == true;
    final at = DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        decoration: BoxDecoration(
          color: mine ? BybitPalette.accent : BybitPalette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(m['body'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
            if (at != null) ...[
              const SizedBox(height: 3),
              Text(DateFormat('d MMM HH:mm').format(at), style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ],
        ),
      ),
    );
  }
}
