/* Quiz LAB connection guard.
   Phones sometimes reuse a connection the host has already closed, so the first request after a
   pause fails ("This site can't be reached", "Load failed"). This worker tries such a request again
   on a fresh connection. It stores nothing, and it never repeats a POST or any other write. */
'use strict';

var RETRY_DELAYS = [300, 900];
var API_ORIGIN = 'https://labapi.genziitian.in';

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) { event.waitUntil(self.clients.claim()); });

function wait(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }

function fetchWithRetry(request) {
  var attempt = 0;
  function run() {
    return fetch(request.clone()).catch(function (error) {
      // The page gave up on the request (left the page, or its own timeout): do not repeat it.
      if (request.signal && request.signal.aborted) throw error;
      if (attempt >= RETRY_DELAYS.length) throw error;
      return wait(RETRY_DELAYS[attempt++]).then(run);
    });
  }
  return run();
}

// Shown only when a page still cannot load after the retries; it tries again by itself.
function reconnectingPage() {
  var html = '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta http-equiv="refresh" content="3"><title>Reconnecting · Quiz LAB</title>' +
    '<style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#f7f6f1;color:#1c1c1a;' +
    'font:16px/1.5 system-ui,-apple-system,sans-serif;text-align:center;padding:24px;box-sizing:border-box}' +
    'h1{font-size:20px;margin:0 0 6px}p{margin:0 0 18px;color:#5f5e58}' +
    'a{display:inline-block;padding:10px 18px;border-radius:10px;background:#1f3d22;color:#fff;text-decoration:none;font-weight:600}' +
    '@media(prefers-color-scheme:dark){body{background:#121411;color:#eceae3}p{color:#a3a199}a{background:#b5d99c;color:#12210f}}</style>' +
    '</head><body><div><h1>Reconnecting…</h1><p>The connection dropped. Trying again in a moment.</p>' +
    '<a href="">Try now</a></div></body></html>';
  return new Response(html, {
    status: 503,
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' }
  });
}

self.addEventListener('fetch', function (event) {
  var request = event.request;
  if (request.method !== 'GET') return;
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;
  var url;
  try { url = new URL(request.url); } catch (_) { return; }
  if (url.origin !== self.location.origin && url.origin !== API_ORIGIN) return;

  if (request.mode === 'navigate') {
    event.respondWith(fetchWithRetry(request).catch(reconnectingPage));
    return;
  }
  event.respondWith(fetchWithRetry(request));
});
