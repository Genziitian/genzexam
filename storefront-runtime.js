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
    var id = Number(pending.paperId);
    var valid = Number.isSafeInteger(id) && id > 0;
    location.replace(valid ? (pending.open === true ? '/paper/' + id : '/papers?paper=' + id) : '/papers?library=1');
  }

  window.QLStorefront = { apiBase: apiBase, token: token, signIn: signIn };

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
