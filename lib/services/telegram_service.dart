// Bridge to the Telegram Mini Apps JS SDK. Resolves to the real
// `dart:js_interop` implementation on web builds and a no-op stub
// everywhere else (Android/iOS/desktop), since `dart:js_interop` external
// declarations only compile for web targets.
export 'telegram_service_stub.dart'
    if (dart.library.js_interop) 'telegram_service_web.dart';
