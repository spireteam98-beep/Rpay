import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _signedInKey = 'auth_signed_in';
  static const _fullNameKey = 'auth_full_name';
  static const _phoneKey = 'auth_phone';
  static const _passwordHashKey = 'auth_password_hash';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isSignedIn => _prefs.getBool(_signedInKey) ?? false;

  static String? get storedFullName => _prefs.getString(_fullNameKey);

  static String? get storedPhone => _prefs.getString(_phoneKey);

  static bool get hasAccount => _prefs.containsKey(_phoneKey);

  static Future<void> registerUser({
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    await _prefs.setString(_fullNameKey, fullName.trim());
    await _prefs.setString(_phoneKey, phoneNumber.trim());
    await _prefs.setString(_passwordHashKey, _hash(password.trim()));
    await _prefs.setBool(_signedInKey, false);
  }

  static Future<bool> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    final success = _verifyCredentials(phoneNumber.trim(), password.trim());
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

  static bool _verifyCredentials(String phoneNumber, String password) {
    final storedPhone = _prefs.getString(_phoneKey);
    final storedHash = _prefs.getString(_passwordHashKey);
    if (storedPhone == null || storedHash == null) return false;
    return storedPhone == phoneNumber && storedHash == _hash(password);
  }

  static String _hash(String input) {
    return base64Encode(utf8.encode(input));
  }
}
