import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

@JS('window.wayakiCanPrompt')
external bool? get wayakiCanPrompt;

@JS('window.wayakiPromptInstall')
external JSPromise<JSBoolean> promptInstall();

@JS('window.wayakiIsIOSSafari')
external JSBoolean isIOSSafari();

@JS('window.wayakiIsStandalone')
external JSBoolean _isStandalone();

class PwaService {
  static const String _pwaDismissedKey = 'pwa_prompt_dismissed_v1';
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Has the user permanently dismissed the install prompt?
  static bool get hasDismissedPrompt {
    return _prefs.getBool(_pwaDismissedKey) ?? false;
  }

  /// Mark the prompt as dismissed.
  static Future<void> dismissPrompt() async {
    await _prefs.setBool(_pwaDismissedKey, true);
  }

  /// Is the app currently running installed (standalone mode)?
  static bool get isStandalone {
    if (!kIsWeb) return false;
    return _isStandalone().toDart;
  }

  /// Is this iOS Safari?
  static bool get isIOS {
    if (!kIsWeb) return false;
    return isIOSSafari().toDart;
  }

  /// Can we show the native Android/Chrome prompt right now?
  static bool get canShowNativePrompt {
    if (!kIsWeb) return false;
    return wayakiCanPrompt == true;
  }

  /// Trigger the native prompt. Returns true if accepted.
  static Future<bool> showNativePrompt() async {
    if (!canShowNativePrompt) return false;
    final result = await promptInstall().toDart;
    return result.toDart;
  }
}
