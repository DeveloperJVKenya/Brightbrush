// BrightBrush offline service worker.
//
// Lets the web app open and show what it last loaded when the connection is
// weak or gone. Data (orders, catalog…) is cached separately by Firestore's
// own offline storage; this worker only keeps the app files, the SDKs it
// loads from Google's CDN, fonts and product photos.
//
//  - App pages and code (index.html, main.dart.js, bootstrap): network first,
//    so a new release is picked up straight away when online; if the network
//    is slow (> 4 s) or down, the saved copy is used.
//  - Other app files (assets, icons, CanvasKit): served from the cache and
//    refreshed in the background.
//  - Versioned CDN files (Firebase JS SDK, CanvasKit, Google Fonts) and
//    Firebase Storage photos (unique, tokened URLs): cache first.
//  - Everything else (Firestore, Functions, Auth, reCAPTCHA, Maps) is never
//    touched.
const VERSION = 'bb-offline-v1';
const SHELL = VERSION + '-shell';
const MEDIA = VERSION + '-media';
const MAX_MEDIA = 400;

const PRECACHE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL).then((cache) =>
      Promise.all(PRECACHE.map((url) => cache.add(url).catch(() => undefined))),
    ),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        // Old versions of this worker and Flutter's retired service worker.
        if (!key.startsWith(VERSION) && (key.startsWith('bb-offline-') || key.startsWith('flutter-'))) {
          await caches.delete(key);
        }
      }
      await self.clients.claim();
    })(),
  );
});

const NETWORK_FIRST = /(^\/$|\/index\.html$|\/main\.dart\.js$|\/flutter_bootstrap\.js$|\/flutter\.js$|\/manifest\.json$)/;
const CDN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.origin === self.location.origin) {
    // The connection monitor's probe and the service worker itself must
    // always hit the network.
    if (url.pathname.endsWith('/version.json') || url.pathname.endsWith('/sw.js') ||
        url.pathname.endsWith('firebase-messaging-sw.js')) {
      return;
    }
    if (req.mode === 'navigate') {
      event.respondWith(networkFirst(req, SHELL, 'index.html'));
      return;
    }
    if (NETWORK_FIRST.test(url.pathname)) {
      event.respondWith(networkFirst(req, SHELL));
      return;
    }
    event.respondWith(staleWhileRevalidate(req, SHELL));
    return;
  }

  if (CDN_HOSTS.includes(url.hostname) &&
      (url.hostname !== 'www.gstatic.com' || /\/(firebasejs|flutter-canvaskit)\//.test(url.pathname))) {
    event.respondWith(cacheFirst(req, SHELL));
    return;
  }

  if (url.hostname === 'firebasestorage.googleapis.com') {
    event.respondWith(cacheFirst(req, MEDIA, MAX_MEDIA));
  }
});

async function networkFirst(req, cacheName, fallbackUrl) {
  const cache = await caches.open(cacheName);
  const network = fetch(req).then((res) => {
    if (res && (res.ok || res.type === 'opaque')) cache.put(fallbackUrl || req, res.clone());
    return res;
  });
  // If the saved copy is served first, a later network failure is expected.
  network.catch(() => undefined);
  // Give the network 4 seconds; on a weak connection fall back to the copy.
  const timeout = new Promise((resolve) => setTimeout(resolve, 4000, null));
  try {
    const first = await Promise.race([network, timeout]);
    if (first) return first;
    const cached = await cache.match(fallbackUrl || req);
    return cached || (await network);
  } catch (e) {
    const cached = await cache.match(fallbackUrl || req);
    if (cached) return cached;
    throw e;
  }
}

async function staleWhileRevalidate(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  const refresh = fetch(req)
    .then((res) => {
      if (res && res.ok) cache.put(req, res.clone());
      return res;
    })
    .catch(() => undefined);
  return cached || (await refresh) || Response.error();
}

async function cacheFirst(req, cacheName, maxEntries) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  if (cached) return cached;
  const res = await fetch(req);
  if (res && (res.ok || res.type === 'opaque')) {
    await cache.put(req, res.clone());
    if (maxEntries) trim(cache, maxEntries);
  }
  return res;
}

async function trim(cache, maxEntries) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - maxEntries; i++) await cache.delete(keys[i]);
}
