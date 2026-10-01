/// The browser's own online/offline signal (navigator.onLine and the
/// window "online"/"offline" events). On other platforms these return null
/// and the connectivity plugin is used instead.
library;

export 'browser_online_stub.dart'
    if (dart.library.js_interop) 'browser_online_web.dart';
