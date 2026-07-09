/// Separate Card Number / Expiry / CVC fields (matching the redesigned Buy
/// & Cash-in flows) instead of Stripe's single combined CardField. Web gets
/// a real multi-Element implementation; other platforms fall back to the
/// standard combined field so mobile builds keep working.
library;

export 'split_card_form_stub.dart'
    if (dart.library.js_interop) 'split_card_form_web.dart';
