// Firebase config for project fareenn-f29f3. Web is real; to fill in
// Android/iOS, run from the project root:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=fareenn-f29f3
//
// Until then, Google sign-in on mobile shows a "not set up" message instead
// of crashing the app.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // Firebase project "fareenn-f29f3" — web app.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDz5KPtY3bDJWvouZ-orCmxcBAnacgo9BA',
    appId: '1:1051480531190:web:19ce857d09e0a12361ccd7',
    messagingSenderId: '1051480531190',
    projectId: 'fareenn-f29f3',
    authDomain: 'fareenn-f29f3.firebaseapp.com',
    storageBucket: 'fareenn-f29f3.firebasestorage.app',
    measurementId: 'G-FDK09J4Y7W',
  );
  // Android / iOS: still placeholders until the mobile apps are registered
  // in the Firebase console (run `flutterfire configure --project=fareenn-f29f3`).

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBRHZ74yeRCGji4zgdvPubBTMPiPxqEO-Q',
    appId: '1:1051480531190:android:6ccef1994dbf421561ccd7',
    messagingSenderId: '1051480531190',
    projectId: 'fareenn-f29f3',
    storageBucket: 'fareenn-f29f3.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'com.wayaki.app',
  );
}
