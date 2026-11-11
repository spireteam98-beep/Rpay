import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Short UI sounds, played natively on Android (see MainActivity.kt,
/// channel "fareenn/sound"). Silent no-op on web or if anything fails —
/// a missing sound must never break a payment flow.
class SoundService {
  static const _channel = MethodChannel('fareenn/sound');

  static Future<void> paymentSuccess() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('paymentSuccess');
    } catch (_) {
      // ignore
    }
  }
}
