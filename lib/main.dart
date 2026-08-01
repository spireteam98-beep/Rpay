import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/pay_merchant_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/telegram_service.dart';
import 'state/kash_app_state.dart';

/// Set once a merchant payment link's `?pay=<till>` has been handed off to
/// the navigator, so a rebuild of CryptoExchangeApp (e.g. from the
/// ChangeNotifierProvider above it) doesn't push the pay screen twice.
bool _didHandlePayLink = false;
final _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kick off a health ping immediately — harmless no-op now that the
  // backend (Cloud Run, min-instances=1) never sleeps, but cheap insurance
  // if a future deploy ever points back at a backend that can cold-start.
  ApiService.warmUp();
  Stripe.publishableKey = ApiService.stripePublishableKey;
  // Set preferred orientations to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Set system overlay style for status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CryptoExchangeApp());
}

/// Runs auth-service init plus, when this page was opened as a Telegram
/// Mini App, a silent Telegram sign-in — done before the entry screen is
/// picked so a Telegram user lands straight in MainNavigation instead of
/// seeing the email/password welcome screen. Outside Telegram (or if the
/// backend can't verify it), this quietly falls through to the normal flow.
Future<void> _bootstrap() async {
  TelegramService.expandToFullHeight();
  TelegramService.applyDarkChrome(
    headerColorHex: '#050506',
    backgroundColorHex: '#050506',
  );
  // A stray vertical scroll shouldn't be read as "swipe to dismiss the Mini
  // App", and a wallet shouldn't let a stray tap close it mid-transfer.
  TelegramService.disableSwipeToClose();
  TelegramService.confirmBeforeClosing();

  await AuthService.init();

  if (!AuthService.isSignedIn && TelegramService.isAvailable) {
    try {
      final signedIn = await ApiService.telegramLogin(
        initData: TelegramService.rawInitData,
      );
      if (signedIn == true) {
        await AuthService.signInTelegramUser();
      }
    } catch (_) {
      // Backend unreachable or Telegram data failed verification — fall
      // through to the normal welcome/login screen below.
    }
  }

  TelegramService.notifyReady();
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

class CryptoExchangeApp extends StatelessWidget {
  const CryptoExchangeApp({super.key});

  Widget _signedOutEntryScreen() {
    final requestedScreen = Uri.base.queryParameters['screen'];
    if (requestedScreen == 'login') {
      return const LoginScreen();
    }
    if (requestedScreen == 'signup') {
      return const SignupScreen();
    }
    // Inside Telegram there's no need for the marketing welcome screen —
    // the user already arrived via the bot, so go straight to signup. This
    // is also the fallback for anyone silent Telegram sign-in didn't cover
    // (e.g. an older Telegram client). Regular web visitors still see the
    // welcome screen first.
    if (TelegramService.isAvailable) {
      return const SignupScreen();
    }
    return const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'Wayaki',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              backgroundColor: AppTheme.darkBackground,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ),
          );
        }

        // A merchant payment link (wayaki.com/app/?pay=<till>) opened by an
        // already-signed-in user should land straight on the pay screen,
        // not the wallet home. Signed-out visitors just see the normal
        // welcome/login flow for now — the link isn't preserved across
        // that round trip yet.
        final payTill = Uri.base.queryParameters['pay'];
        if (AuthService.isSignedIn && payTill != null && payTill.isNotEmpty && !_didHandlePayLink) {
          _didHandlePayLink = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _rootNavigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => PayMerchantScreen(tillNumber: payTill),
              ),
            );
          });
        }

        return ChangeNotifierProvider(
          create:
              (_) => KashAppState(
                profileName: AuthService.storedFullName,
                phoneNumber: AuthService.storedPhone,
              ),
          child: MaterialApp(
            navigatorKey: _rootNavigatorKey,
            title: 'Wayaki',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            navigatorObservers: [_TelegramBackButtonObserver()],
            home:
                AuthService.isSignedIn
                    ? const MainNavigation()
                    : _signedOutEntryScreen(),
          ),
        );
      },
    );
  }
}
