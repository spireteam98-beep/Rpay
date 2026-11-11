import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// What this device can do for biometric unlock. The OS decides which
/// sensor actually prompts — the app can only ask "authenticate the owner".
class BiometricSupport {
  final bool available;
  final bool face;
  final bool fingerprint;

  const BiometricSupport({
    required this.available,
    required this.face,
    required this.fingerprint,
  });

  static const none = BiometricSupport(
    available: false,
    face: false,
    fingerprint: false,
  );
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Biometrics only exist in the installed iOS/Android app, never on web.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<BiometricSupport> check() async {
    if (!platformSupported) return BiometricSupport.none;
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!deviceSupported || !canCheck) return BiometricSupport.none;

      final types = await _auth.getAvailableBiometrics();
      final face = types.contains(BiometricType.face);
      var fingerprint = types.contains(BiometricType.fingerprint);
      // Android often only reports a strength class ("strong"/"weak")
      // rather than the sensor type; that's almost always a fingerprint.
      if (!face &&
          !fingerprint &&
          (types.contains(BiometricType.strong) ||
              types.contains(BiometricType.weak))) {
        fingerprint = true;
      }
      return BiometricSupport(
        available: face || fingerprint,
        face: face,
        fingerprint: fingerprint,
      );
    } on PlatformException {
      return BiometricSupport.none;
    }
  }

  /// Shows the system Face ID / fingerprint prompt. True if the owner
  /// authenticated.
  static Future<bool> authenticate(String reason) async {
    if (!platformSupported) return false;
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    }
  }

  /// Human label for the available sensors, e.g. "Face ID or fingerprint".
  static String label(BiometricSupport s) {
    final faceName =
        defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : 'Face unlock';
    if (s.face && s.fingerprint) return '$faceName or fingerprint';
    if (s.face) return faceName;
    if (s.fingerprint) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? 'Touch ID'
          : 'Fingerprint';
    }
    return 'Biometrics';
  }
}
