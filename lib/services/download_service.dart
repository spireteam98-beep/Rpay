// Triggers a browser file download on web; no-op elsewhere (native builds
// use the OS share sheet's own "Save" option instead — see receipt_dialog.dart).
export 'download_service_stub.dart'
    if (dart.library.js_interop) 'download_service_web.dart';
