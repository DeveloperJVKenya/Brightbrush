{{flutter_js}}
{{flutter_build_config}}

// Flutter's own service worker is deprecated; offline support comes from
// web/sw.js (registered in index.html), so the app loads without it.
_flutter.loader.load();
