@JS('Telegram.WebApp')
library;

import 'dart:js_interop';

@JS('initData')
external String? get _rawInitDataJs;

@JS()
external void ready();

@JS()
external void expand();

@JS()
external void setHeaderColor(String color);

@JS()
external void setBackgroundColor(String color);

@JS()
external void disableVerticalSwipes();

@JS()
external void enableClosingConfirmation();

@JS()
external void onEvent(String eventType, JSFunction callback);

@JS()
external void offEvent(String eventType, JSFunction callback);

@JS('BackButton.show')
external void _backButtonShow();

@JS('BackButton.hide')
external void _backButtonHide();

@JS('HapticFeedback.impactOccurred')
external void _hapticImpact(String style);

@JS('HapticFeedback.notificationOccurred')
external void _hapticNotification(String type);

/// Bridge to the Telegram Mini Apps JS SDK (telegram-web-app.js), loaded
/// unconditionally in web/index.html. Outside of actual Telegram (a plain
/// browser tab), the script still defines `Telegram.WebApp` with an empty
/// `initData`, so every getter here is safe to call — it just reports
/// "not available" rather than throwing. Every call below is also
/// try/catch-wrapped since older Telegram clients don't implement every
/// method (e.g. disableVerticalSwipes needs Bot API 7.7+) and would
/// otherwise throw a JS TypeError on a "no such method" call.
class TelegramService {
  static String get rawInitData {
    try {
      return _rawInitDataJs ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool get isAvailable => rawInitData.isNotEmpty;

  /// Tells Telegram the Mini App finished loading and is ready to be shown.
  static void notifyReady() {
    try {
      ready();
    } catch (_) {}
  }

  /// Expands the Mini App to full height instead of Telegram's default
  /// half-screen sheet.
  static void expandToFullHeight() {
    try {
      expand();
    } catch (_) {}
  }

  /// Matches Telegram's chrome (header + background) to the app's own dark
  /// theme so the Mini App doesn't flash Telegram's default white chrome
  /// around Wayaki's UI.
  static void applyDarkChrome({
    required String headerColorHex,
    required String backgroundColorHex,
  }) {
    try {
      setHeaderColor(headerColorHex);
      setBackgroundColor(backgroundColorHex);
    } catch (_) {}
  }

  /// Stops a vertical drag inside the app (e.g. scrolling a list) from
  /// being read by Telegram as "swipe down to dismiss the Mini App".
  static void disableSwipeToClose() {
    try {
      disableVerticalSwipes();
    } catch (_) {}
  }

  /// Wallet app: makes Telegram ask for a tap-to-confirm before closing the
  /// Mini App outright, so a stray tap mid-transfer can't drop the session.
  static void confirmBeforeClosing() {
    try {
      enableClosingConfirmation();
    } catch (_) {}
  }

  static JSFunction? _backButtonHandler;

  /// Shows Telegram's native chrome back button and routes taps to
  /// [onBack]. Safe to call repeatedly — replaces any previous handler
  /// rather than stacking listeners.
  static void showBackButton(void Function() onBack) {
    try {
      if (_backButtonHandler != null) {
        offEvent('backButtonClicked', _backButtonHandler!);
      }
      _backButtonHandler = onBack.toJS;
      onEvent('backButtonClicked', _backButtonHandler!);
      _backButtonShow();
    } catch (_) {}
  }

  static void hideBackButton() {
    try {
      _backButtonHide();
    } catch (_) {}
  }

  /// Light tap feedback — wired into the app's shared TouchScale button
  /// wrapper so nearly every tap gets it for free.
  static void hapticTap() {
    try {
      _hapticImpact('light');
    } catch (_) {}
  }

  static void hapticSuccess() {
    try {
      _hapticNotification('success');
    } catch (_) {}
  }

  static void hapticError() {
    try {
      _hapticNotification('error');
    } catch (_) {}
  }
}
