/* Shared with the paper pages and the existing student app. */
(function () {
  'use strict';
  var pendingKey = 'ql_storefront_return';
  // Keep this in step with the API URL embedded in the existing React bundle.
  var apiBase = 'https://labapi.genziitian.in/public/api';

  function token() {
    try { return localStorage.getItem('lab_token') || ''; } catch (_) { return ''; }
  }

  // open: after login go straight into the paper instead of its details.
  function signIn(paperId, open) {
    var id = Number(paperId);
    try {
      sessionStorage.setItem(pendingKey, JSON.stringify({
        paperId: Number.isSafeInteger(id) && id > 0 ? id : null,
        open: open === true,
        at: Date.now()
      }));
    } catch (_) {}
    location.assign('/login');
  }

  function resumeAfterLogin() {
    var pending;
    try { pending = JSON.parse(sessionStorage.getItem(pendingKey) || 'null'); } catch (_) { return; }
    if (!pending) return;
    if (!Number.isFinite(pending.at) || Date.now() - pending.at > 30 * 60 * 1000) {
      sessionStorage.removeItem(pendingKey);
      return;
    }
    // Wait for the existing login flow to finish its account checks and navigation.
    if (!token() || !/^\/(dashboard\/?|admin\/?|)$/.test(location.pathname)) return;
    sessionStorage.removeItem(pendingKey);
    // A page that sent the student to log in (the IDE, for example) asks to come back to itself.
    if (typeof pending.to === 'string' && /^\/(?![\/\\])/.test(pending.to)) { location.replace(pending.to); return; }
    var id = Number(pending.paperId);
    var valid = Number.isSafeInteger(id) && id > 0;
    location.replace(valid ? (pending.open === true ? '/paper/' + id : '/papers?paper=' + id) : '/papers?library=1');
  }

  function updateProBrandIcons() {
    if (typeof document === 'undefined' || typeof document.querySelector !== 'function') return;
    var isPro = false;
    try {
      var user = JSON.parse(localStorage.getItem('lab_user') || 'null');
      if (user && (user.is_pro === true || user.isPro === true)) isPro = true;
    } catch (_) {}

    var icon32 = document.querySelector('link[rel="icon"][sizes="32x32"]');
    if (icon32) icon32.href = isPro ? '/favicon-pro-32x32.png' : '/favicon-32x32.png';

    var icon16 = document.querySelector('link[rel="icon"][sizes="16x16"]');
    if (icon16) icon16.href = isPro ? '/favicon-pro-16x16.png' : '/favicon-16x16.png';

    var appleIcon = document.querySelector('link[rel="apple-touch-icon"]');
    if (appleIcon) appleIcon.href = isPro ? '/apple-touch-icon-pro.png' : '/apple-touch-icon.png';

    var manifest = document.querySelector('link[rel="manifest"]');
    if (manifest) manifest.href = isPro ? '/site-pro.webmanifest' : '/site.webmanifest';

    var fav = document.querySelector('link[rel="icon"]:not([sizes])');
    if (fav) fav.href = isPro ? '/favicon-pro-32x32.png' : '/favicon.ico';
  }

  updateProBrandIcons();
  window.addEventListener('storage', function (e) {
    if (!e || e.key === 'lab_user' || e.key === 'lab_token') updateProBrandIcons();
  });
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') updateProBrandIcons();
  });

  window.QLStorefront = { apiBase: apiBase, token: token, signIn: signIn, updateProBrandIcons: updateProBrandIcons };

  // Retire the old connection guard; do not install it on new pages. Keep other
  // service workers intact. The replacement sw.js releases existing controllers.
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
    try {
      navigator.serviceWorker.getRegistration('/').then(function (registration) {
        if (!registration) return;
        var owned = [registration.active, registration.waiting, registration.installing].some(function (worker) {
          if (!worker || !worker.scriptURL) return false;
          try {
            var script = new URL(worker.scriptURL, location.origin);
            return script.origin === location.origin && script.pathname === '/sw.js';
          } catch (_) { return false; }
        });
        if (!owned) return;
        return registration.update().catch(function () {
          // If the update cannot download, release future navigations anyway.
          return registration.unregister();
        });
      }).catch(function () {});
    } catch (_) {}
  }

  /*
   * Google sign-in from the iPhone home-screen app. Google's page opens in a separate browser
   * sheet with its own storage, so the app never received the login. The app now sends a random
   * one-time id along; the backend parks the login under it, and the app collects it when the
   * person comes back from the sheet.
   */
  var HANDOFF_KEY = 'ql_google_handoff';
  var HANDOFF_MS = 10 * 60 * 1000;
  function homeScreenApp() {
    return window.navigator.standalone === true ||
      !!(window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  }
  function pendingHandoff() {
    try {
      var p = JSON.parse(localStorage.getItem(HANDOFF_KEY) || 'null');
      if (p && typeof p.id === 'string' && Date.now() - p.at < HANDOFF_MS) return p;
      localStorage.removeItem(HANDOFF_KEY);
    } catch (_) {}
    return null;
  }
  var collecting = false;
  function collectHandoff() {
    var pending = pendingHandoff();
    if (!pending || collecting) return;
    collecting = true;
    fetch(apiBase + '/auth/google/handoff', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ handoff: pending.id })
    }).then(function (response) {
      return response.status === 200 ? response.json() : null;
    }).then(function (data) {
      if (!data || !data.token || !data.user) return;
      try {
        localStorage.removeItem(HANDOFF_KEY);
        localStorage.setItem('lab_token', data.token);
        localStorage.setItem('lab_user', JSON.stringify(data.user));
      } catch (_) { return; }
      location.replace('/dashboard');
    }).catch(function () {}).then(function () { collecting = false; });
  }
  document.addEventListener('click', function (event) {
    if (!homeScreenApp()) return;
    var button = event.target && event.target.closest ? event.target.closest('button') : null;
    if (!button || !/continue with google/i.test(button.textContent || '')) return;
    var bytes = new Uint8Array(24);
    try { crypto.getRandomValues(bytes); } catch (_) { return; }
    var id = Array.prototype.map.call(bytes, function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
    try { localStorage.setItem(HANDOFF_KEY, JSON.stringify({ id: id, at: Date.now() })); } catch (_) { return; }
    event.preventDefault();
    event.stopPropagation();
    location.href = apiBase + '/auth/google?handoff=' + id;
  }, true);
  document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'visible') collectHandoff(); });
  window.addEventListener('focus', collectHandoff);
  window.addEventListener('pageshow', collectHandoff);
  setInterval(function () { if (pendingHandoff()) collectHandoff(); }, 2500);

  // Login failure reporter: tells the server about sign-in failures it never saw
  // (phone could not reach the API, 5xx, the Google return page failing to load the profile).
  // Managers see them at /manager/login-failures. Reports that cannot be sent wait in localStorage.
  var failQueueKey = 'ql_login_fail_queue';
  function sendFailure(item) {
    try {
      return fetch(apiBase + '/auth/login-failure', {
        method: 'POST', keepalive: true,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(item)
      }).then(function (r) { return r.ok || r.status === 422 || r.status === 429; }, function () { return false; });
    } catch (_) { return Promise.resolve(false); }
  }
  function queueFailure(item) {
    try {
      var q = JSON.parse(localStorage.getItem(failQueueKey) || '[]');
      q.push(item); localStorage.setItem(failQueueKey, JSON.stringify(q.slice(-10)));
    } catch (_) {}
  }
  function flushFailures() {
    var q; try { q = JSON.parse(localStorage.getItem(failQueueKey) || '[]'); } catch (_) { q = []; }
    if (!q.length || navigator.onLine === false) return;
    try { localStorage.removeItem(failQueueKey); } catch (_) {}
    q.forEach(function (item) { sendFailure(item).then(function (ok) { if (!ok) queueFailure(item); }); });
  }
  function reportLoginFailure(item) {
    item.page = location.pathname;
    item.detail = (item.detail ? item.detail + ' · ' : '') + 'online=' + navigator.onLine + ' · standalone=' + !!(window.matchMedia && matchMedia('(display-mode: standalone)').matches || navigator.standalone);
    if (navigator.onLine === false) { item.detail += ' · queued offline at ' + new Date().toISOString(); queueFailure(item); return; }
    sendFailure(item).then(function (ok) { if (!ok) { item.detail += ' · first send failed ' + new Date().toISOString(); queueFailure(item); } });
  }
  window.QLReportLoginFailure = reportLoginFailure;
  (function watchAuthRequests() {
    if (!window.XMLHttpRequest || XMLHttpRequest.prototype.__qlFailWatch) return;
    XMLHttpRequest.prototype.__qlFailWatch = true;
    var authRe = /\/public\/api\/auth\/(login|register|verify-otp|resend-otp|password\/forgot|password\/reset|google\/mobile|me)(\?|$)/;
    var open = XMLHttpRequest.prototype.open, send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url) { this.__qlUrl = String(url || ''); return open.apply(this, arguments); };
    XMLHttpRequest.prototype.send = function (body) {
      var xhr = this, m = authRe.exec(xhr.__qlUrl || '');
      if (m) {
        var started = Date.now();
        xhr.addEventListener('loadend', function () {
          var path = m[1], st = xhr.status;
          var onCallback = /^\/auth\/callback/.test(location.pathname);
          if (path === 'me' && !onCallback) return; // only the Google return page's profile load counts
          if (st >= 200 && st < 500 && !(path === 'me' && st >= 400)) return; // 4xx are logged by the server itself
          var email = null; try { email = (JSON.parse(body || '{}') || {}).email || null; } catch (_) {}
          if (!email) { try { email = (JSON.parse(localStorage.getItem('lab_user') || '{}') || {}).email || null; } catch (_) {} }
          reportLoginFailure({
            email: email,
            method: path === 'me' ? 'google' : path === 'google/mobile' ? 'google_app' : /otp/.test(path) ? 'otp' : path === 'register' ? 'register' : /password/.test(path) ? 'password_reset' : 'email',
            reason: path === 'me' ? 'profile_failed' : st === 0 ? 'network_error' : 'server_error',
            message: st === 0 ? 'No response from the server for /auth/' + path + ' (connection dropped, blocked or timed out).' : 'Server answered ' + st + ' for /auth/' + path + '.',
            detail: 'status=' + st + ' · ' + (Date.now() - started) + 'ms'
          });
        });
      }
      return send.apply(this, arguments);
    };
  })();
  flushFailures();
  window.addEventListener('online', flushFailures);

  collectHandoff();

  // Papers open in the self-paced paper room, not the old in-app quiz player.
  var oldQuiz = /^\/quiz\/(\d+)\/?$/.exec(location.pathname);
  if (oldQuiz) { location.replace('/paper/' + oldQuiz[1]); return; }
  if (!/^\/(papers|paper-pricing)(\/|\.html|$)/.test(location.pathname)) {
    resumeAfterLogin();
    window.addEventListener('pageshow', resumeAfterLogin);
    window.addEventListener('popstate', resumeAfterLogin);
    var timer = setInterval(function () {
      resumeAfterLogin();
      try { if (!sessionStorage.getItem(pendingKey)) clearInterval(timer); } catch (_) { clearInterval(timer); }
    }, 350);
  }
})();
