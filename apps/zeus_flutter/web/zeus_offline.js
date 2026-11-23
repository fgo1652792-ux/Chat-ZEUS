'use strict';

const scope = new URL(self.registration.scope);
const cachePrefix = 'zeus-shell:' + scope.pathname + ':';
const cacheName = cachePrefix + '1';
const shell = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'sqlite3.wasm',
  'sqflite_sw.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/assets/brand/zeus.png',
];
const shellPaths = new Set(shell.map((part) => new URL(part, scope).pathname));

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    await cache.addAll(shell.map((part) => new URL(part, scope).href));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const oldCaches = (await caches.keys()).filter(
      (name) => name.startsWith(cachePrefix) && name !== cacheName,
    );
    await Promise.all(oldCaches.map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  const staticAsset = shellPaths.has(url.pathname) ||
    ['assets/', 'icons/', 'canvaskit/'].some((prefix) => {
      return url.pathname.startsWith(scope.pathname + prefix);
    });

  if (request.method !== 'GET' || request.headers.has('authorization') ||
      request.headers.has('range') || url.origin !== scope.origin ||
      url.search || !staticAsset) {
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    try {
      const response = await fetch(request);
      if (response.ok && !/no-store/i.test(response.headers.get('cache-control') ?? '')) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (e) {
      const saved = await cache.match(request);
      if (saved) return saved;
      throw e;
    }
  })());
});
