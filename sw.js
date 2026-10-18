/* Retire Quiz LAB's old connection guard, including installed /sw.js?v=2 workers.
   The guard intercepted every GET and could replace failed navigations with a
   self-reloading 503 page. Retrying that page re-entered the same worker.
   Keep this URL available so existing installs can update out of that loop.
   Home-screen installation does not depend on this worker. */
'use strict';

self.addEventListener('install', function (event) {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', function (event) {
  // Replace the old controller without reloading an open exam or deleting data.
  event.waitUntil(self.clients.claim().catch(function () {}).then(function () {
    return self.registration.unregister();
  }));
});

// No fetch handler: the browser owns navigation, API requests and recovery.
