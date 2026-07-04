import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Bridge to the RoyalPay backend (backend/ folder — Node + Postgres).
/// Every call fails soft: if the API is down the app keeps working on
/// the local sandbox, so the demo never breaks.
class ApiService {
  /// Where the backend runs. `flutter run -d chrome` and the API share
  /// localhost, so this works out of the box with run_backend.bat.
  static const String baseUrl = 'http://localhost:8080';
  static const _tokenKey = 'api_jwt';
  static const Duration _timeout = Duration(seconds: 6);

  static SharedPreferences get _prefs => AuthService.prefs;

  static String? get token => _prefs.getString(_tokenKey);
  static bool get hasSession => token != null && token!.isNotEmpty;

  static Map<String, String> _headers({bool authed = false}) => {
        'Content-Type': 'application/json',
        if (authed && token != null) 'Authorization': 'Bearer $token',
      };

  /// True when the backend answers /health.
  static Future<bool> isUp() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers on the backend; returns the on-chain deposit address,
  /// or null if the backend is unreachable (caller falls back to sandbox).
  static Future<String?> signup({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: _headers(),
            body: jsonEncode({
              'fullName': fullName,
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) {
        await _prefs.setString(_tokenKey, body['token'] as String);
        return body['ethAddress'] as String?;
      }
      throw ApiException(body['error'] as String? ?? 'Signup failed');
    } on ApiException {
      rethrow;
    } catch (_) {
      return null; // backend offline — sandbox mode
    }
  }

  /// Logs in on the backend; true on success, null if unreachable.
  static Future<bool?> login({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(),
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _prefs.setString(_tokenKey, body['token'] as String);
        return true;
      }
      return false;
    } catch (_) {
      return null; // backend offline
    }
  }

  /// Custody summary: deposit address, on-chain ETH balance, live prices.
  static Future<Map<String, dynamic>?> walletSummary() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/wallet/summary'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// On-chain withdrawal. Returns tx hash.
  static Future<String> withdraw({
    required String toAddress,
    required double amountEth,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/wallet/withdraw'),
          headers: _headers(authed: true),
          body: jsonEncode({'toAddress': toAddress, 'amountEth': amountEth}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['txHash'] as String;
    throw ApiException(body['error'] as String? ?? 'Withdrawal failed');
  }

  /// Verifies the OTP on the backend (marks phone_verified in Postgres).
  /// Fail-soft: returns quietly when the backend is offline.
  static Future<void> verifyPhone(String code) async {
    if (!hasSession) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/auth/verify-phone'),
            headers: _headers(authed: true),
            body: jsonEncode({'code': code}),
          )
          .timeout(_timeout);
    } catch (_) {/* offline — sandbox mode */}
  }

  /// Sandbox KYC approval on the backend (raises tier to Full KYC).
  static Future<void> submitKyc() async {
    if (!hasSession) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/auth/kyc'), headers: _headers(authed: true))
          .timeout(_timeout);
    } catch (_) {/* offline — sandbox mode */}
  }

  static Future<void> clearSession() => Future.value(_prefs.remove(_tokenKey));
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
