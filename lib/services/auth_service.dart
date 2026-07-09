import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _signedInKey = 'auth_signed_in';
  static const _fullNameKey = 'auth_full_name';
  static const _emailKey = 'auth_email';
  static const _phoneKey = 'auth_phone';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Shared storage handle for other services (state persistence).
  static SharedPreferences get prefs => _prefs;

  // ── Demo account (sandbox) ─────────────────────────────────────
  // Demo helpers removed — app requires a real backend session or stored account.

  static bool get isSignedIn => _prefs.getBool(_signedInKey) ?? false;

  static String? get storedFullName => _prefs.getString(_fullNameKey);

  static String? get storedEmail => _prefs.getString(_emailKey);

  static String? get storedPhone => _prefs.getString(_phoneKey);

  static bool get hasAccount => _prefs.containsKey(_emailKey) || _prefs.containsKey(_phoneKey);

  static Future<void> registerUser({
    required String fullName,
    required String email,
    required String phoneNumber,
  }) async {
    await _prefs.setString(_fullNameKey, fullName.trim());
    await _prefs.setString(_emailKey, email.trim().toLowerCase());
    await _prefs.setString(_phoneKey, phoneNumber.trim());
    await _prefs.setBool(_signedInKey, false);
  }

  static Future<bool> signInSavedUser() async {
    if (!hasAccount) return false;
    await _prefs.setBool(_signedInKey, true);
    return true;
  }

  static Future<void> signInBackendUser({required String email}) async {
    await _prefs.setString(_emailKey, email.trim().toLowerCase());
    await _prefs.setBool(_signedInKey, true);
  }

  static Future<void> signOut() async {
    await _prefs.setBool(_signedInKey, false);
  }
}
