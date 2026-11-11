import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/kash_widgets.dart';
import 'agent_code_screen.dart';
import 'biometric_setup_screen.dart';
import 'pin_setup_screen.dart';
import 'profile_setup_screen.dart';

/// What's known about the user while they move through onboarding.
class OnboardingData {
  String firstName;
  String lastName;
  String email;
  String phone;

  OnboardingData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// The Google-first onboarding sequence:
///   1. Continue with Google (WelcomeScreen)
///   2. Identity (KYC) — name, phone, gender, address, ID document
///                                                (new users only)
///   3. Agent short code — optional, skippable    (new users only)
///   4. 4-digit PIN                               (if none set yet)
///   5. Face ID / fingerprint                     (if the device has it)
/// Each step calls back here to decide what comes next, so returning users
/// skip anything they've already done.
class AuthFlow {
  static const totalSteps = 12;

  /// Called right after the backend accepted the Google sign-in.
  static Future<void> afterGoogle(
    BuildContext context,
    GoogleSignInResult result, {
    String? googleDisplayName,
  }) async {
    var first = result.firstName;
    var last = result.lastName;
    if (first.isEmpty && last.isEmpty) {
      final source =
          (googleDisplayName?.trim().isNotEmpty ?? false)
              ? googleDisplayName!.trim()
              : result.fullName;
      final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      first = parts.isNotEmpty ? parts.first : '';
      last = parts.length > 1 ? parts.skip(1).join(' ') : '';
    }

    final data = OnboardingData(
      firstName: first,
      lastName: last,
      email: result.email,
      phone: result.phone,
    );

    if (!result.profileComplete) {
      Navigator.of(context).push(kashRoute(ProfileSetupScreen(data: data)));
      return;
    }
    if (!result.hasPin) {
      Navigator.of(context).push(kashRoute(PinSetupScreen(data: data)));
      return;
    }
    context.read<KashAppState>().markPinSet();
    await afterPin(context, data);
  }

  /// Called once the identity details are saved: offer the optional
  /// agent-code step.
  static void afterProfile(BuildContext context, OnboardingData data) {
    Navigator.of(context).push(kashRoute(AgentCodeScreen(data: data)));
  }

  /// Called after the agent code is linked or skipped.
  static void afterAgent(BuildContext context, OnboardingData data) {
    Navigator.of(context).push(kashRoute(PinSetupScreen(data: data)));
  }

  /// Called once a PIN exists. Offers biometrics when the device has them
  /// and they aren't already on; otherwise finishes.
  static Future<void> afterPin(
    BuildContext context,
    OnboardingData data,
  ) async {
    final support = await BiometricService.check();
    if (!context.mounted) return;
    if (support.available && !AuthService.biometricLock) {
      Navigator.of(
        context,
      ).push(kashRoute(BiometricSetupScreen(data: data, support: support)));
      return;
    }
    await finish(context, data);
  }

  /// Marks the user signed in and lands them on the wallet.
  static Future<void> finish(BuildContext context, OnboardingData data) async {
    final appState = context.read<KashAppState>();
    appState.completeSignup(
      fullName: data.fullName,
      phoneNumber: data.phone,
      email: data.email,
    );
    await AuthService.completeGoogleSignIn(
      fullName: data.fullName,
      email: data.email,
      phoneNumber: data.phone,
    );
    // MainNavigation syncs balances as soon as it mounts — no second call.
    if (!context.mounted) return;
    GoRouter.of(context).go('/home');
  }
}
