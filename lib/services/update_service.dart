import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

/// What the backend says the user needs to do before they can keep using
/// the app — only ever returned when an update is actually required.
class ForcedUpdate {
  final String latestVersion;
  final String updateUrl;

  const ForcedUpdate({required this.latestVersion, required this.updateUrl});
}

/// Forced-update gate: compares this install's own build number against
/// the minimum the backend (Railway) currently requires. Web always serves
/// the latest build on load, so this only matters for the distributed
/// Android APK.
class UpdateService {
  static Future<ForcedUpdate?> checkForcedUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    if (build <= 0) return null;

    final result = await ApiService.appVersion(build);
    if (result == null || result['forceUpdate'] != true) return null;

    return ForcedUpdate(
      latestVersion: (result['latestVersion'] as String?) ?? '',
      updateUrl: (result['updateUrl'] as String?) ?? '',
    );
  }
}
