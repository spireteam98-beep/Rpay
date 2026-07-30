import 'dart:typed_data';

/// Non-web fallback — native builds save via the OS share sheet instead.
class DownloadService {
  static void downloadBytes(Uint8List bytes, String filename) {}
}
