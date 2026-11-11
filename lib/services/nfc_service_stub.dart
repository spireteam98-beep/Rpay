import 'nfc_models.dart';

/// Non-web builds: NFC card tapping is not wired up yet (the web app uses
/// Web NFC in Chrome on Android).
class NfcService {
  static bool get supported => false;

  static Future<NfcTap> read({Duration timeout = const Duration(seconds: 40)}) =>
      Future.error(const NfcException('NFC is not available in this version of the app.'));

  static Future<void> writeUrl(String url, {Duration timeout = const Duration(seconds: 40)}) =>
      Future.error(const NfcException('NFC is not available in this version of the app.'));

  static void stop() {}
}
