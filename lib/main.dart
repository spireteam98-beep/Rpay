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
import 'services/pwa_service.dart';
import 'state/kash_app_state.dart';
import 'widgets/pwa_install_banner.dart';

import 'router.dart';

void main() async {
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
  
  await AuthService.init();
  await PwaService.init();

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

class CryptoExchangeApp extends StatelessWidget {
  const CryptoExchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Fire off the background bootstrap (Telegram sync) without blocking the UI
    _bootstrap();

    return ChangeNotifierProvider(
      create:
          (_) => KashAppState(
            profileName: AuthService.storedFullName,
            phoneNumber: AuthService.storedPhone,
          ),
      child: MaterialApp.router(
        routerConfig: appRouter,
        title: 'Wayaki',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                if (child != null) child,
                const PwaInstallBanner(),
              ],
            ),
          );
        },
      ),
    );
  }
}
