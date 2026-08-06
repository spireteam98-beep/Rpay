import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/pay_merchant_screen.dart';
import 'services/auth_service.dart';
import 'services/telegram_service.dart';
import 'widgets/kash_widgets.dart' show kashRoute;

/// Custom transition for GoRouter to match the original kashRoute slide/fade
CustomTransitionPage<T> buildKashTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Mirrors the Flutter navigation stack onto Telegram's native chrome back
/// button: shown whenever there's a screen to pop back to, hidden at the
/// root so Telegram's own close/swipe gesture takes over. Without this,
/// the only way back is the in-app arrow — Telegram users expect its own
/// back button to work too.
class _TelegramBackButtonObserver extends NavigatorObserver {
  void _sync() {
    if (navigator?.canPop() ?? false) {
      TelegramService.showBackButton(() => navigator?.maybePop());
    } else {
      TelegramService.hideBackButton();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync();
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  observers: [_TelegramBackButtonObserver()],
  initialLocation: '/',
  redirect: (context, state) {
    final signedIn = AuthService.isSignedIn;
    final isGoingToAuth = state.matchedLocation == '/' || 
                          state.matchedLocation == '/login' || 
                          state.matchedLocation == '/signup';
                          
    // Handle deep links like ?pay=<till>
    if (state.uri.queryParameters.containsKey('pay') && signedIn) {
      final till = state.uri.queryParameters['pay'];
      if (till != null && till.isNotEmpty) {
        return '/pay?till=$till';
      }
    }

    if (!signedIn && !isGoingToAuth) {
      // If inside Telegram, go straight to signup instead of welcome
      if (TelegramService.isAvailable) {
        return '/signup';
      }
      return '/';
    }

    if (signedIn && isGoingToAuth) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => buildKashTransition(
        context: context,
        state: state,
        child: const WelcomeScreen(),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildKashTransition(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => buildKashTransition(
        context: context,
        state: state,
        child: const SignupScreen(),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => buildKashTransition(
        context: context,
        state: state,
        child: const MainNavigation(),
      ),
    ),
    GoRoute(
      path: '/pay',
      pageBuilder: (context, state) {
        final till = state.uri.queryParameters['till'] ?? '';
        return buildKashTransition(
          context: context,
          state: state,
          child: PayMerchantScreen(tillNumber: till),
        );
      },
    ),
  ],
);
