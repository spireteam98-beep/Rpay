/// Brand identity — Fareenn.
library;

const String kBrandName = 'Fareenn';
const String kBrandSlogan = 'Friendly Banking';

/// White 3D wordmark (with ®) cut from the master logo, transparent
/// background — sits on the brand red or on black.
const String kBrandWordmarkAsset = 'assets/images/fareenn_wordmark.png';

/// The in-app transfer rail is still identified as 'Wayaki' in the backend
/// and stored ledger data; show it under the brand name.
String displayRail(String rail) => rail == 'Wayaki' ? kBrandName : rail;
