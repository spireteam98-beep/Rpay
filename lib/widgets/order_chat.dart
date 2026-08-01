import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'bybit_wallet_ui.dart';
import 'touch_scale.dart';

/// Binance-P2P-style order chat: a live thread between the two parties on
/// an order, with lightweight polling to feel real-time without needing a
/// websocket. Embed inline (not scrollable itself — the caller's own
/// SingleChildScrollView should wrap it) below the order's payment/status
/// section.
class OrderChatSection extends StatefulWidget {
  final Future<List<dynamic>?> Function() loadMessages;
  final Future<void> Function(String body) sendMessage;

  const OrderChatSection({
    super.key,
    required this.loadMessages,
    required this.sendMessage,
  });

  @override
  State<OrderChatSection> createState() => _OrderChatSectionState();
}

class _OrderChatSectionState extends State<OrderChatSection> {
  List<dynamic> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  final _controller = TextEditingController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final messages = await widget.loadMessages();
    if (!mounted || messages == null) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await widget.sendMessage(text);
      await _load(silent: true);
    } catch (_) {
      if (mounted) _controller.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 80, maxHeight: 320),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child:
              _loading
                  ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BybitPalette.accent,
                        ),
                      ),
                    ),
                  )
                  : _messages.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No messages yet — say hello to coordinate the payment.',
                      style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = Map<String, dynamic>.from(
                        _messages[index] as Map,
                      );
                      return _MessageBubble(
                        body: message['body'] as String? ?? '',
                        fromMe: message['from_me'] == true,
                        createdAt:
                            DateTime.tryParse(
                              message['created_at'] as String? ?? '',
                            ) ??
                            DateTime.now(),
                      );
                    },
                  ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: BybitPalette.input,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: BybitPalette.muted),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TouchScale(
              onTap: _sending ? () {} : _send,
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BybitPalette.accent,
                  shape: BoxShape.circle,
                ),
                child:
                    _sending
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                        : const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String body;
  final bool fromMe;
  final DateTime createdAt;

  const _MessageBubble({
    required this.body,
    required this.fromMe,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: fromMe ? BybitPalette.accent : BybitPalette.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    body,
                    style: TextStyle(
                      color: fromMe ? Colors.black : Colors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm').format(createdAt),
                    style: TextStyle(
                      color: fromMe ? Colors.black54 : BybitPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
