import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _signedInKey = 'auth_signed_in';
  static const _fullNameKey = 'auth_full_name';
  static const _emailKey = 'auth_email';
  static const _phoneKey = 'auth_phone';
  static const _passwordHashKey = 'auth_password_hash';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Shared storage handle for other services (state persistence).
  static SharedPreferences get prefs => _prefs;

  // ── Demo account (sandbox) ─────────────────────────────────────
  static const String demoName = 'Mohamed Ali';
  static const String demoEmail = 'demo@kashflip.app';
  static const String demoPhone = '+252 61 123 4567';
  static const String demoPassword = 'demo1234';

  /// One-tap sandbox login. Uses the saved account if one exists;
  /// otherwise creates the demo profile, then signs in.
  static Future<void> signInDemo() async {
    if (!hasAccount) {
      await registerUser(
        fullName: demoName,
        email: demoEmail,
        phoneNumber: demoPhone,
        password: demoPassword,
      );
    }
    await _prefs.setBool(_signedInKey, true);
  }

  static bool get isSignedIn => _prefs.getBool(_signedInKey) ?? false;

  static String? get storedFullName => _prefs.getString(_fullNameKey);

  static String? get storedEmail => _prefs.getString(_emailKey);

  static String? get storedPhone => _prefs.getString(_phoneKey);

  static bool get hasAccount => _prefs.containsKey(_emailKey) || _prefs.containsKey(_phoneKey);

  static Future<void> registerUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    await _prefs.setString(_fullNameKey, fullName.trim());
    await _prefs.setString(_emailKey, email.trim().toLowerCase());
    await _prefs.setString(_phoneKey, phoneNumber.trim());
    await _prefs.setString(_passwordHashKey, _hash(password.trim()));
    await _prefs.setBool(_signedInKey, false);
  }

  static Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final success = _verifyCredentials(email.trim().toLowerCase(), password.trim());
    if (!success) return false;
    await _prefs.setBool(_signedInKey, true);
    return true;
  }

  static Future<bool> signInSavedUser() async {
    if (!hasAccount) return false;
    await _prefs.setBool(_signedInKey, true);
    return true;
  }

  static Future<void> signOut() async {
    await _prefs.setBool(_signedInKey, false);
  }

  static bool _verifyCredentials(String email, String password) {
    final storedEmail = _prefs.getString(_emailKey)?.toLowerCase();
    final storedHash = _prefs.getString(_passwordHashKey);
    if (storedEmail == null || storedHash == null) return false;
    return storedEmail == email && storedHash == _hash(password);
  }

  static String _hash(String input) {
    return base64Encode(utf8.encode(input));
  }
}
