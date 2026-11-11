import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'nfc_models.dart';

// Helpers defined in web/index.html (window.fareennNfc), wrapping Web NFC.
@JS('fareennNfc.supported')
external JSBoolean _supported();

@JS('fareennNfc.read')
external JSPromise<JSString> _read(JSNumber timeoutMs);

@JS('fareennNfc.write')
external JSPromise<JSAny?> _write(JSString url, JSNumber timeoutMs);

@JS('fareennNfc.stop')
external void _stop();

/// Web NFC (Chrome on Android, served over HTTPS). Reads the card's UID and
/// NDEF records, and writes the Fareenn card URL record.
class NfcService {
  static bool get supported {
    try {
      if (!globalContext.has('fareennNfc')) return false;
      return _supported().toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<NfcTap> read({Duration timeout = const Duration(seconds: 40)}) async {
    try {
      final raw = (await _read(timeout.inMilliseconds.toJS).toDart).toDart;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final uid = normaliseUid(m['uid'] as String? ?? '');
      if (uid.isEmpty) {
        throw const NfcException('This card has no readable ID. Use a Fareenn card.');
      }
      return NfcTap(uid: uid, data: m['data'] as String? ?? '');
    } on NfcException {
      rethrow;
    } catch (e) {
      throw NfcException(_message(e));
    }
  }

  static Future<void> writeUrl(String url, {Duration timeout = const Duration(seconds: 40)}) async {
    try {
      await _write(url.toJS, timeout.inMilliseconds.toJS).toDart;
    } catch (e) {
      throw NfcException(_message(e));
    }
  }

  static void stop() {
    try {
      _stop();
    } catch (_) {}
  }

  static String _message(Object e) {
    final s = e.toString();
    if (s.contains('timeout') || s.contains('AbortError')) return 'No card detected. Try again.';
    if (s.contains('NotAllowedError')) {
      return 'Allow NFC for fareenn.com in Chrome and make sure NFC is turned on in your phone settings.';
    }
    if (s.contains('NotSupportedError')) return 'NFC is not available on this phone.';
    if (s.contains('NotReadableError') || s.contains('NetworkError')) {
      return 'The card moved away too soon. Hold it still on the back of the phone.';
    }
    return 'Card read failed. Hold the card still and try again.';
  }
}
