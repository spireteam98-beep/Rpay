import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/google_auth_service.dart';
import 'services/telegram_service.dart';
import 'services/pwa_service.dart';
import 'services/update_service.dart';
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
  
  // Both just open the same local SharedPreferences store — run together.
  await Future.wait([AuthService.init(), PwaService.init()]);
  // Firebase (Google sign-in) loads its JS SDK over the network; start it in
  // the background so it never delays the first frame.
  GoogleAuthService.warmUp();

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
    headerColorHex: '#E60000',
    backgroundColorHex: '#0D0D0D',
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
        title: 'Fareenn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          // Respect the viewer's font-size setting, but cap it so very large
          // system fonts can't break balances, buttons and keypads.
          final textScaler = media.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.2,
          );
          final app = child ?? const SizedBox.shrink();
          return MediaQuery(
            data: media.copyWith(textScaler: textScaler),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  // The signed-in app is a phone UI: on tablets and desktop
                  // browsers it stays a centred phone-width column instead of
                  // stretching edge to edge. The entry screen keeps the full
                  // width, since it has its own wide layout.
                  ListenableBuilder(
                    listenable: appRouter.routerDelegate,
                    builder: (context, _) {
                      final path =
                          appRouter.routerDelegate.currentConfiguration.uri.path;
                      final fullWidth =
                          path == '/' || path == '/login' || path == '/signup';
                      return _PhoneFrame(enabled: !fullWidth, child: app);
                    },
                  ),
                  const PwaInstallBanner(),
                  const _ForceUpdateGate(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen, non-dismissible overlay shown on top of everything (even
/// mid-navigation) when the backend says this APK build is too old to keep
/// using. Invisible and a no-op until the check comes back positive, so it
/// never delays or blocks normal app startup.
class _ForceUpdateGate extends StatefulWidget {
  const _ForceUpdateGate();

  @override
  State<_ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<_ForceUpdateGate> {
  ForcedUpdate? _update;

  @override
  void initState() {
    super.initState();
    UpdateService.checkForcedUpdate().then((update) {
      if (mounted && update != null) setState(() => _update = update);
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: Colors.black.withOpacity(0.94),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Update required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  update.latestVersion.isEmpty
                      ? 'A newer version of Fareenn is required to keep using the app.'
                      : 'Fareenn ${update.latestVersion} is required to keep using the app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        update.updateUrl.isEmpty
                            ? null
                            : () => launchUrl(
                              Uri.parse(update.updateUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                    child: const Text(
                      'Update now',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the app at a comfortable phone width on large screens. Always
/// builds the same widget tree (only the width changes) so switching
/// between full-width and framed screens never resets app state.
class _PhoneFrame extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const _PhoneFrame({required this.enabled, required this.child});

  static const double _maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final framed = enabled && media.size.width > _maxWidth;
    final width = framed ? _maxWidth : media.size.width;
    return ColoredBox(
      color: const Color(0xFF050505),
      child: Center(
        child: SizedBox(
          width: width,
          height: media.size.height,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
