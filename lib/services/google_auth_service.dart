import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// Google sign-in through Firebase Authentication.
///
/// Firebase only proves *who* the user is; the app's real session is still
/// the backend JWT. After Google confirms the account, [signIn] returns a
/// Firebase ID token that the backend verifies (POST /auth/firebase) and
/// swaps for that JWT.
class GoogleAuthService {
  static bool _ready = false;
  static Future<void>? _initFuture;

  /// True once Firebase initialised with real (non-placeholder) options.
  static bool get isConfigured => _ready;

  /// True when this platform has real Firebase options (even if the
  /// background init hasn't finished yet).
  static bool get hasOptions =>
      !DefaultFirebaseOptions.currentPlatform.apiKey.startsWith('REPLACE_');

  /// Starts Firebase in the background without delaying the first frame.
  /// [signIn] waits for it only when the user actually taps Google.
  static void warmUp() {
    _initFuture ??= init();
  }

  static Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.startsWith('REPLACE_')) {
      debugPrint(
        '[GoogleAuth] firebase_options.dart is a placeholder — run '
        '`flutterfire configure` to enable Google sign-in.',
      );
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _ready = true;
    } catch (err) {
      debugPrint('[GoogleAuth] Firebase init failed: $err');
    }
  }

  /// Opens the Google account picker. Returns a fresh Firebase ID token,
  /// or null if the user closed the picker.
  static Future<String?> signIn() async {
    // Only wait for Firebase when it isn't up yet. Any await before the
    // popup opens can cost the browser's "user tapped" permission, and
    // Safari/iOS then blocks the Google window outright.
    if (!_ready) await (_initFuture ??= init());
    if (!_ready) {
      throw const GoogleAuthException(
        'Google sign-in is not set up yet. Please try again later.',
      );
    }

    final provider =
        GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({'prompt': 'select_account'});

    try {
      final UserCredential credential =
          kIsWeb
              ? await FirebaseAuth.instance.signInWithPopup(provider)
              : await FirebaseAuth.instance.signInWithProvider(provider);
      final token = await credential.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const GoogleAuthException(
          'Google did not return an account. Please try again.',
        );
      }
      return token;
    } on FirebaseAuthException catch (err) {
      const cancelled = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
        'web-context-cancelled',
        'canceled',
        'cancelled',
        'user-cancelled',
      };
      if (cancelled.contains(err.code)) {
        throw GoogleAuthException(
          'The Google window closed before sign-in finished. '
          'Try again (${err.code}).',
        );
      }
      if (kIsWeb &&
          (err.code == 'popup-blocked' ||
              err.code == 'operation-not-supported-in-this-environment')) {
        // Fall back to a full-page redirect; the result is picked up by
        // [completeRedirectSignIn] when the app reloads.
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return null;
      }
      if (err.code == 'unauthorized-domain') {
        throw GoogleAuthException(
          'This web address is not allowed for Google sign-in. Add '
          '"${Uri.base.host}" in Firebase console → Authentication → '
          'Settings → Authorized domains.',
        );
      }
      if (err.code == 'operation-not-allowed') {
        throw const GoogleAuthException(
          'Google sign-in is turned off for this Firebase project. Enable it '
          'in Firebase console → Authentication → Sign-in method → Google.',
        );
      }
      if (err.code == 'network-request-failed') {
        throw const GoogleAuthException(
          'No connection. Check your internet and try again.',
        );
      }
      if (err.code == 'account-exists-with-different-credential') {
        throw const GoogleAuthException(
          'This email is already used with another sign-in method.',
        );
      }
      throw GoogleAuthException(
        '${err.message ?? 'Google sign-in failed.'} (${err.code})',
      );
    }
  }

  /// Web only: finishes a sign-in that went through the redirect fallback.
  /// Returns a Firebase ID token, or null if there was no pending redirect.
  static Future<String?> completeRedirectSignIn() async {
    if (!kIsWeb) return null;
    await (_initFuture ??= init());
    if (!_ready) return null;
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      return await result.user?.getIdToken(true);
    } on FirebaseAuthException catch (err) {
      throw GoogleAuthException(
        '${err.message ?? 'Google sign-in failed.'} (${err.code})',
      );
    }
  }

  /// Web: ID token for a Google account already signed in to Firebase on
  /// this site (for example by the landing page's own Google button).
  /// Returns null when nobody is signed in.
  static Future<String?> currentUserToken() async {
    await (_initFuture ??= init());
    if (!_ready) return null;
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? await auth.authStateChanges().first;
    return user?.getIdToken(true);
  }

  /// Google display name of the signed-in Firebase user, if any — used to
  /// prefill first/last name on the profile step.
  static String? get displayName =>
      _ready ? FirebaseAuth.instance.currentUser?.displayName : null;

  static Future<void> signOut() async {
    if (_initFuture != null) await _initFuture;
    if (!_ready) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      /* already signed out */
    }
  }
}
