const CACHE_NAME = 'maintego-cache-v1';
const urlsToCache = [
  '/login/',
  '/signup/',
  '/static/images/logo.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        return cache.addAll(urlsToCache);
      })
  );
});

self.addEventListener('fetch', event => {
  // Simple network-first fallback to cache strategy to ensure fresh data while keeping app usable offline
  event.respondWith(
    fetch(event.request).catch(() => {
      return caches.match(event.request);
    })
  );
});
