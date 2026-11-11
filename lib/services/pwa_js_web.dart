import 'dart:js_interop';

/// Web build: bindings to the PWA install helpers defined in web/index.html.

@JS('window.wayakiCanPrompt')
external bool? get _wayakiCanPrompt;

@JS('window.wayakiPromptInstall')
external JSPromise<JSBoolean> _promptInstall();

@JS('window.wayakiIsIOSSafari')
external JSBoolean _isIOSSafari();

@JS('window.wayakiIsStandalone')
external JSBoolean _isStandalone();

bool pwaCanPrompt() => _wayakiCanPrompt == true;

Future<bool> pwaPromptInstall() async => (await _promptInstall().toDart).toDart;

bool pwaIsIOSSafari() => _isIOSSafari().toDart;

bool pwaIsStandalone() => _isStandalone().toDart;
