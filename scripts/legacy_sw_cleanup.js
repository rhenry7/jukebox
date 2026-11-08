// Deployed as flutter_service_worker.js (see deploy.sh and deploy.yml).
//
// Deploys before 2026-11-04 installed Flutter's caching service worker, which
// keeps serving the old app from its cache. A browser still running it fetches
// this file as that worker's update, so this is the one thing that can reach
// it: the new app's own cleanup never runs there, because the old app does.
//
// --pwa-strategy=none would publish an empty file here instead. An empty worker
// never skips waiting, so it can't replace the old one while a tab is using it.
//
// Reloads only when there were old caches to delete, because the app still
// registers this worker on every launch and must not reload each time.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const stale = (await caches.keys()).filter((name) => name.startsWith('flutter-'));
    await Promise.all(stale.map((name) => caches.delete(name)));
    await self.clients.claim();
    await self.registration.unregister();
    if (stale.length === 0) return;
    const tabs = await self.clients.matchAll({ type: 'window' });
    await Promise.all(tabs.map((tab) => tab.navigate(tab.url).catch(() => {})));
  })());
});
