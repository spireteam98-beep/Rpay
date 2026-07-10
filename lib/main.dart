import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'state/kash_app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kick off a health ping immediately — if the Render backend is asleep,
  // this starts its cold start now instead of on the user's first tap.
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

class CryptoExchangeApp extends StatelessWidget {
  const CryptoExchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: AuthService.init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'RoyallPay',
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

        return ChangeNotifierProvider(
          create:
              (_) => KashAppState(
                profileName: AuthService.storedFullName,
                phoneNumber: AuthService.storedPhone,
              ),
          child: MaterialApp(
            title: 'RoyallPay',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home:
                AuthService.isSignedIn
                    ? const MainNavigation()
                    : const WelcomeScreen(),
          ),
        );
      },
    );
  }
}
