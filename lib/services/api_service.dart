import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Bridge to the RoyallPay backend (backend/ folder — Node + Postgres).
/// This app requires a live backend session and does not use local sandbox-only mode.
class ApiService {
  /// Backend URL, overridable at build time with `--dart-define=API_BASE_URL=`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Stripe publishable key (safe to ship client-side by design).
  /// Overridable with `--dart-define=STRIPE_PUBLISHABLE_KEY=`.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_live_51RdTmVP6aNiJxRzPl7AiE5MTIrm2pGCIuMfQ0pYIbCrT62GZjtMiOA6APngCOVPmtQwfY1dRgNJKr5fgqIBuUsbg00zyyRnl1M',
  );
  static const _tokenKey = 'api_jwt';
  // Render's free tier spins the backend down after 15 minutes idle, and a
  // cold start can take 30-50s — a short timeout here just turns "the
  // server is waking up" into a false "can't reach backend" error.
  static const Duration _timeout = Duration(seconds: 25);

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

  /// Fire-and-forget ping sent as soon as the app starts, so a sleeping
  /// Render instance is already waking up in the background by the time the
  /// user reaches a screen that actually needs it — shortens or avoids the
  /// cold-start wait on the first real request entirely.
  static void warmUp() {
    unawaited(
      http.get(Uri.parse('$baseUrl/health')).timeout(
            const Duration(seconds: 60),
            onTimeout: () => http.Response('', 0),
          ),
    );
  }

  /// Registers on the backend; returns the on-chain deposit address.
  /// Sign-in is email + a one-time code, so signup never takes a password.
  /// If the backend is unreachable, signup fails with an error.
  static Future<String?> signup({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: _headers(),
            body: jsonEncode({
              'fullName': fullName,
              'email': email,
              'phone': phone,
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
      return null;
    }
  }

  /// Sends a 6-digit sign-in code to an existing account's email.
  /// Returns true once sent, null if the backend is unreachable.
  static Future<bool?> requestLoginOtp({required String email}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login/request-otp'),
            headers: _headers(),
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return body['sent'] == true;
      // The backend reports email-delivery failures under `warning` (a
      // failed send isn't really a request "error") — check that first so
      // the real reason surfaces instead of a generic fallback message.
      throw ApiException(body['warning'] as String? ??
          body['error'] as String? ??
          'Could not send sign-in code');
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Exchanges an email sign-in code for a session; true on success,
  /// null if the backend is unreachable.
  static Future<bool?> verifyLoginOtp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login/verify-otp'),
            headers: _headers(),
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        await _prefs.setString(_tokenKey, body['token'] as String);
        return true;
      }
      throw ApiException(body['error'] as String? ?? 'Incorrect or expired code');
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
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

  /// Combined mobile-money + trading-cash + crypto wallet summary.
  static Future<Map<String, dynamic>?> hybridWallet() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/wallet/hybrid'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Real virtual bank account (account number/name/status); auto-created
  /// on the backend the first time it's requested.
  static Future<Map<String, dynamic>?> bankAccount() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/banking/account'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Submit a mobile-money deposit reference for admin approval.
  static Future<Map<String, dynamic>?> submitMobileMoneyDeposit({
    required String rail,
    required double amountKes,
    required String reference,
    String? phone,
  }) async {
    if (!hasSession) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/mobile-money/deposits'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'rail': rail,
            'amountKes': amountKes,
            'reference': reference,
            if (phone != null) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 202) return body;
    throw ApiException(body['error'] as String? ?? 'Deposit request failed');
  }

  /// Starts a payment gateway top-up and credits the wallet after verification.
  /// In backend sandbox mode, this returns an already-credited top-up.
  static Future<Map<String, dynamic>?> createTopUp({
    required String gateway,
    required String currency,
    required double amount,
    String? phone,
  }) async {
    if (!hasSession) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/payments/topups'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'gateway': gateway,
            'currency': currency,
            'amount': amount,
            if (AuthService.storedEmail != null) 'email': AuthService.storedEmail,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Top-up failed');
  }

  /// Verify a payment gateway top-up after an external checkout completes.
  static Future<Map<String, dynamic>?> verifyTopUp({
    required String gateway,
    required String reference,
  }) async {
    if (!hasSession) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/payments/topups/verify'),
          headers: _headers(authed: true),
          body: jsonEncode({'gateway': gateway, 'reference': reference}),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Top-up verification failed');
  }

  /// Queue a mobile-money payout; backend immediately holds the KES balance.
  static Future<Map<String, dynamic>?> submitMobileMoneyWithdrawal({
    required String rail,
    required double amountKes,
    required String phone,
  }) async {
    if (!hasSession) return null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/mobile-money/withdrawals'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'rail': rail,
            'amountKes': amountKes,
            'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 202) return body;
    throw ApiException(body['error'] as String? ?? 'Withdrawal request failed');
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

  /// Sends a 6-digit verification code to the user's email.
  static Future<bool> requestEmailOtp() async {
    if (!hasSession) return false;
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/request-email-otp'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['sent'] == true;
    throw ApiException(body['warning'] as String? ??
        body['error'] as String? ??
        'Email code request failed');
  }

  /// Verifies the 6-digit email OTP.
  static Future<bool> verifyEmail(String code) async {
    if (!hasSession) return false;
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/verify-email'),
          headers: _headers(authed: true),
          body: jsonEncode({'code': code}),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['verified'] == true;
    throw ApiException(body['error'] as String? ?? 'Email verification failed');
  }

  /// KYC approval on the backend (raises tier to Full KYC).
  static Future<void> submitKyc() async {
    if (!hasSession) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/auth/kyc'), headers: _headers(authed: true))
          .timeout(_timeout);
    } catch (_) {/* offline — sandbox mode */}
  }

  // ── Trading (real market data; testnet/internal execution) ─────

  /// Live market prices from the exchange. Null when backend offline.
  static Future<Map<String, dynamic>?> market() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/trade/market'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// USD funding balance + custody holdings valued at live prices.
  static Future<Map<String, dynamic>?> tradeBalances() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/trade/balances'),
              headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Market order. side: 'buy' | 'sell'. Returns fill details.
  static Future<Map<String, dynamic>> trade({
    required String side,
    required String asset,
    required double usdAmount,
    String quoteCurrency = 'USD',
  }) async {
    final normalizedQuoteCurrency = quoteCurrency.toUpperCase();
    final res = await http
        .post(
          Uri.parse('$baseUrl/trade/$side'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'asset': asset,
            'quoteCurrency': normalizedQuoteCurrency,
            if (normalizedQuoteCurrency == 'KES')
              'kesAmount': usdAmount
            else
              'usdAmount': usdAmount,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Order failed');
  }

  static Future<void> clearSession() async {
    await _prefs.remove(_tokenKey);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
