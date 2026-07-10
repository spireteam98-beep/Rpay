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
      http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(
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
    String? agentCode,
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
              if (agentCode != null && agentCode.isNotEmpty)
                'agentCode': agentCode,
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
      throw ApiException(
        body['warning'] as String? ??
            body['error'] as String? ??
            'Could not send sign-in code',
      );
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
      throw ApiException(
        body['error'] as String? ?? 'Incorrect or expired code',
      );
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
          .get(
            Uri.parse('$baseUrl/wallet/summary'),
            headers: _headers(authed: true),
          )
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
          .get(
            Uri.parse('$baseUrl/wallet/hybrid'),
            headers: _headers(authed: true),
          )
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
          .get(
            Uri.parse('$baseUrl/banking/account'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Current authenticated profile and compliance state.
  static Future<Map<String, dynamic>?> me() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/auth/me'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Real RoyallPay user-to-user transfer.
  static Future<Map<String, dynamic>> createP2pTransfer({
    required String recipient,
    required String currency,
    required double amount,
    String? memo,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/transfers'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'recipient': recipient,
            'currency': currency.toUpperCase(),
            'amount': amount,
            if (memo != null && memo.isNotEmpty) 'memo': memo,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Transfer failed');
  }

  /// Real ledger history from the backend.
  static Future<List<dynamic>?> ledgerTransactions() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/ledger'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
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
            if (AuthService.storedEmail != null)
              'email': AuthService.storedEmail,
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
    throw ApiException(
      body['error'] as String? ?? 'Top-up verification failed',
    );
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
    } catch (_) {
      /* offline — sandbox mode */
    }
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
    throw ApiException(
      body['warning'] as String? ??
          body['error'] as String? ??
          'Email code request failed',
    );
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
    } catch (_) {
      /* offline — sandbox mode */
    }
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
          .get(
            Uri.parse('$baseUrl/trade/balances'),
            headers: _headers(authed: true),
          )
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

  // ── Merchant ─────────────────────────────────────────────────────

  /// Registers a business under the current user — till number doubles as
  /// the merchant number / business account for receiving payments.
  static Future<Map<String, dynamic>> registerMerchant({
    required String name,
    String? businessType,
    String? phone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/merchants'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'name': name,
            if (businessType != null && businessType.isNotEmpty)
              'businessType': businessType,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(
      body['error'] as String? ?? 'Merchant registration failed',
    );
  }

  /// The current user's registered businesses (usually zero or one).
  static Future<List<dynamic>?> myMerchants() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/merchants/me'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Recent payments a merchant has received (the till's transaction feed).
  static Future<List<dynamic>?> merchantPayments(String merchantId) async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/merchants/$merchantId/payments'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Pays a merchant directly by till number — the QR-scan-to-pay flow.
  static Future<Map<String, dynamic>> payMerchantTill({
    required String tillNumber,
    required String currency,
    required double amount,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/merchants/pay/$tillNumber'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'currency': currency.toUpperCase(),
            'amount': amount,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Payment failed');
  }

  // ── Agent ────────────────────────────────────────────────────────

  /// Registers the current user as a RoyallPay agent.
  static Future<Map<String, dynamic>> registerAgent({
    required String businessName,
    String? phone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/agents'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'businessName': businessName,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Agent registration failed');
  }

  /// The current user's agent profile (null if not an agent).
  static Future<Map<String, dynamic>?> myAgent() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/agents/me'), headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['agent'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// The agent's commission history.
  static Future<List<dynamic>?> agentCommissions() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/agents/commissions'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Agent-assisted cash-in: the agent hands the customer cash and the
  /// system credits their wallet, paying the agent a commission.
  static Future<Map<String, dynamic>> agentAssistedDeposit({
    required String customer,
    required String currency,
    required double amount,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/agents/deposits'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'customer': customer,
            'currency': currency.toUpperCase(),
            'amount': amount,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Deposit failed');
  }

  /// Agent-assisted cash-out: the system debits the customer's wallet and
  /// the agent hands over cash, earning a commission.
  static Future<Map<String, dynamic>> agentAssistedWithdrawal({
    required String customer,
    required String currency,
    required double amount,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/agents/withdrawals'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'customer': customer,
            'currency': currency.toUpperCase(),
            'amount': amount,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Withdrawal failed');
  }

  // ── Admin: agents & merchants ──────────────────────────────────

  /// All agents (optionally filtered by status: PENDING, ACTIVE, SUSPENDED).
  static Future<List<dynamic>?> adminAgents({String? status}) async {
    if (!hasSession) return null;
    try {
      final uri = Uri.parse('$baseUrl/admin/agents').replace(
        queryParameters:
            (status != null && status.isNotEmpty) ? {'status': status} : null,
      );
      final res = await http
          .get(uri, headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Admin directly onboards an existing user as a pre-approved agent.
  static Future<Map<String, dynamic>> adminCreateAgent({
    required String identifier,
    required String businessName,
    String? phone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/agents'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'identifier': identifier,
            'businessName': businessName,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Could not create agent');
  }

  static Future<Map<String, dynamic>> adminApproveAgent(String id) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/agents/$id/approve'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Could not approve agent');
  }

  static Future<Map<String, dynamic>> adminDeactivateAgent(String id) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/agents/$id/deactivate'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(
      body['error'] as String? ?? 'Could not deactivate agent',
    );
  }

  static Future<List<dynamic>?> adminAgentCommissions(String agentId) async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/admin/agents/$agentId/commissions'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Commission liability across all agents, sorted by balance descending.
  static Future<Map<String, dynamic>?> adminCommissionSummary() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/admin/commissions/summary'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// All merchants (optionally filtered by status: PENDING, ACTIVE, SUSPENDED).
  static Future<List<dynamic>?> adminMerchants({String? status}) async {
    if (!hasSession) return null;
    try {
      final uri = Uri.parse('$baseUrl/admin/merchants').replace(
        queryParameters:
            (status != null && status.isNotEmpty) ? {'status': status} : null,
      );
      final res = await http
          .get(uri, headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Admin directly onboards an existing user as a pre-approved merchant.
  static Future<Map<String, dynamic>> adminCreateMerchant({
    required String identifier,
    required String name,
    String? businessType,
    String? phone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/merchants'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'identifier': identifier,
            'name': name,
            if (businessType != null && businessType.isNotEmpty)
              'businessType': businessType,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Could not create merchant');
  }

  static Future<Map<String, dynamic>> adminApproveMerchant(String id) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/merchants/$id/approve'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(
      body['error'] as String? ?? 'Could not approve merchant',
    );
  }

  static Future<Map<String, dynamic>> adminDeactivateMerchant(String id) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/admin/merchants/$id/deactivate'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(
      body['error'] as String? ?? 'Could not deactivate merchant',
    );
  }

  // ── P2P: agent-mediated crypto buys (Binance-P2P style) ────────

  /// Active agents a customer can buy crypto from.
  static Future<List<dynamic>?> p2pAgents() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/p2p/agents'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Opens a buy order against a chosen agent's float.
  static Future<Map<String, dynamic>> createP2pOrder({
    required String agentId,
    required String asset,
    required double cryptoAmount,
    required String fiatCurrency,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/p2p/orders'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'agentId': agentId,
            'asset': asset.toUpperCase(),
            'cryptoAmount': cryptoAmount,
            'fiatCurrency': fiatCurrency.toUpperCase(),
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return body;
    throw ApiException(body['error'] as String? ?? 'Could not create order');
  }

  /// The customer's own P2P order history.
  static Future<List<dynamic>?> myP2pOrders() async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/p2p/orders/mine'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// A single order's detail (customer or assigned agent may view it).
  static Future<Map<String, dynamic>?> p2pOrder(String orderId) async {
    if (!hasSession) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/p2p/orders/$orderId'),
            headers: _headers(authed: true),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Uploads a payment screenshot (data URL) as proof of the mobile-money payment.
  static Future<Map<String, dynamic>> uploadP2pProof({
    required String orderId,
    required String proofImageDataUrl,
    String? reference,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/p2p/orders/$orderId/proof'),
          headers: _headers(authed: true),
          body: jsonEncode({
            'proofImage': proofImageDataUrl,
            if (reference != null && reference.isNotEmpty)
              'reference': reference,
          }),
        )
        .timeout(const Duration(seconds: 40));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Could not upload proof');
  }

  static Future<Map<String, dynamic>> cancelP2pOrder(String orderId) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/p2p/orders/$orderId/cancel'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Could not cancel order');
  }

  /// Orders assigned to the caller's agent profile, optionally filtered by status.
  static Future<List<dynamic>?> assignedP2pOrders({String? status}) async {
    if (!hasSession) return null;
    try {
      final uri = Uri.parse('$baseUrl/p2p/orders/assigned').replace(
        queryParameters:
            (status != null && status.isNotEmpty) ? {'status': status} : null,
      );
      final res = await http
          .get(uri, headers: _headers(authed: true))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> confirmP2pOrder(String orderId) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/p2p/orders/$orderId/confirm'),
          headers: _headers(authed: true),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(
      body['error'] as String? ?? 'Could not release the order',
    );
  }

  static Future<Map<String, dynamic>> rejectP2pOrder(
    String orderId, {
    String? note,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/p2p/orders/$orderId/reject'),
          headers: _headers(authed: true),
          body: jsonEncode({if (note != null && note.isNotEmpty) 'note': note}),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(body['error'] as String? ?? 'Could not reject order');
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
