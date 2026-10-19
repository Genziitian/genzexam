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
