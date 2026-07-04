import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'state/kash_app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return ChangeNotifierProvider(
      create: (_) => KashAppState(),
      child: MaterialApp(
        title: 'Kashflip',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const WelcomeScreen(),
      ),
    );
  }
}
