/// Android/iOS/desktop builds: there is no browser install prompt.

bool pwaCanPrompt() => false;

Future<bool> pwaPromptInstall() async => false;

bool pwaIsIOSSafari() => false;

bool pwaIsStandalone() => false;
