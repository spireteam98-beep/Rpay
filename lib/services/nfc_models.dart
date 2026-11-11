/// One NFC card tap: the chip's factory UID and the first URL/text record.
class NfcTap {
  final String uid; // hex, upper case, no separators
  final String data;
  const NfcTap({required this.uid, required this.data});

  /// The Fareenn card token from a https://www.fareenn.com/c/<token> record.
  String? get token {
    final at = data.indexOf('/c/');
    if (at < 0) return null;
    final t = data.substring(at + 3).split(RegExp(r'[?#/]')).first;
    return RegExp(r'^[A-Za-z0-9_-]{20,40}$').hasMatch(t) ? t : null;
  }

  String get last4 => uid.length >= 4 ? uid.substring(uid.length - 4) : uid;
}

class NfcException implements Exception {
  final String message;
  const NfcException(this.message);
  @override
  String toString() => message;
}

/// Normalises a Web NFC serial number ("04:a1:2b:…") to "04A12B…".
String normaliseUid(String raw) => raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
