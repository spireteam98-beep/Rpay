import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'sound_service.dart';

/// Live notifications over Server-Sent Events (GET /social/stream).
///
/// Keeps [unreadNotifications]/[unreadMessages] current for the bell badge
/// and emits each new notification on [incoming] the moment the backend
/// sends it. Reconnects with backoff when the connection drops (network
/// change, server deploy), and re-syncs counts on every reconnect.
class RealtimeService extends ChangeNotifier {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  int unreadNotifications = 0;
  int unreadMessages = 0;
  bool connected = false;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  http.Client? _client;
  bool _running = false;
  int _backoffSeconds = 2;

  /// Starts the connection loop (idempotent). Safe to call on every screen.
  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  /// Closes the connection — call on sign-out.
  void stop() {
    _running = false;
    _client?.close();
    _client = null;
    connected = false;
    unreadNotifications = 0;
    unreadMessages = 0;
    notifyListeners();
  }

  /// Re-reads counts over REST (after marking items read, etc.).
  Future<void> refreshCounts() async {
    try {
      _applyCounts(await ApiService.unreadCounts());
    } catch (_) {/* best-effort */}
  }

  void _applyCounts(Object? counts) {
    if (counts is! Map) return;
    unreadNotifications = (counts['notifications'] as num?)?.toInt() ?? unreadNotifications;
    unreadMessages = (counts['messages'] as num?)?.toInt() ?? unreadMessages;
    notifyListeners();
  }

  Future<void> _loop() async {
    while (_running) {
      if (!ApiService.hasSession) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }
      final client = http.Client();
      _client = client;
      try {
        final req = http.Request('GET', Uri.parse('${ApiService.baseUrl}/social/stream'))
          ..headers.addAll(ApiService.authHeaders)
          ..headers['Accept'] = 'text/event-stream';
        final res = await client.send(req);
        if (res.statusCode != 200) throw Exception('stream ${res.statusCode}');
        connected = true;
        _backoffSeconds = 2;
        notifyListeners();

        String? event;
        final data = StringBuffer();
        await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            data.write(line.substring(5).trim());
          } else if (line.isEmpty && event != null) {
            _handle(event, data.toString());
            event = null;
            data.clear();
          }
        }
      } catch (_) {
        // fall through to reconnect
      } finally {
        client.close();
        if (identical(_client, client)) _client = null;
      }
      if (connected) {
        connected = false;
        notifyListeners();
      }
      if (!_running) break;
      await Future.delayed(Duration(seconds: _backoffSeconds));
      _backoffSeconds = (_backoffSeconds * 2).clamp(2, 30);
    }
  }

  void _handle(String event, String raw) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (event) {
      case 'unread':
        _applyCounts(body);
      case 'notification':
        _applyCounts(body['unread']);
        final item = body['item'];
        if (item is Map<String, dynamic>) {
          _incoming.add(item);
          // A customer's card-payment receipt: confirm it audibly. (The
          // merchant hears the chime on the charge screen itself.)
          final d = item['data'];
          if (d is Map && d['type'] == 'card_receipt' && d['role'] == 'customer') {
            SoundService.paymentSuccess();
          }
        }
      case 'read':
        _applyCounts(body['unread']);
    }
  }
}
