/// Non-web fallback (Android/iOS/desktop) — there is no Telegram WebApp JS
/// SDK on these platforms, so every call is a safe no-op.
class TelegramService {
  static bool get isAvailable => false;

  static String get rawInitData => '';

  static void notifyReady() {}

  static void expandToFullHeight() {}

  static void applyDarkChrome({
    required String headerColorHex,
    required String backgroundColorHex,
  }) {}

  static void disableSwipeToClose() {}

  static void confirmBeforeClosing() {}

  static void showBackButton(void Function() onBack) {}

  static void hideBackButton() {}

  static void hapticTap() {}

  static void hapticSuccess() {}

  static void hapticError() {}
}
