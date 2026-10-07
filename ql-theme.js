/* Quiz Lab theme: one saved choice, applied on every page.
   The choice lives in localStorage "ql_theme" ("dark" or "light"); until one is
   saved the page follows the device setting. Load this in <head>, before styles paint. */
(function () {
  var KEY = 'ql_theme';
  var root = document.documentElement;
  var SUN = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>';
  var MOON = '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>';

  function saved() {
    try {
      var v = localStorage.getItem(KEY);
      return v === 'dark' || v === 'light' ? v : null;
    } catch (e) {
      return null;
    }
  }
  function system() {
    return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  function current() {
    return saved() || system();
  }
  function paintToggles(theme) {
    var buttons = document.querySelectorAll('[data-ql-theme-toggle]');
    for (var i = 0; i < buttons.length; i++) {
      var label = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
      buttons[i].setAttribute('aria-label', label);
      buttons[i].setAttribute('title', label);
      buttons[i].innerHTML =
        '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        (theme === 'dark' ? SUN : MOON) + '</svg>';
    }
  }
  function apply(theme) {
    root.setAttribute('data-theme', theme);
    paintToggles(theme);
  }
  function set(theme) {
    theme = theme === 'dark' ? 'dark' : 'light';
    if (theme === current() && root.getAttribute('data-theme') === theme) return;
    try { localStorage.setItem(KEY, theme); } catch (e) {}
    apply(theme);
    try { window.dispatchEvent(new CustomEvent('ql-theme', { detail: theme })); } catch (e) {}
  }

  apply(current());

  window.qlTheme = {
    get: current,
    isDark: function () { return current() === 'dark'; },
    set: set,
    toggle: function () { set(current() === 'dark' ? 'light' : 'dark'); }
  };

  document.addEventListener('click', function (event) {
    var button = event.target && event.target.closest ? event.target.closest('[data-ql-theme-toggle]') : null;
    if (button) window.qlTheme.toggle();
  });
  document.addEventListener('DOMContentLoaded', function () { paintToggles(current()); });

  // Another tab changed the theme, or the device setting changed with nothing saved.
  function follow() {
    var theme = current();
    if (root.getAttribute('data-theme') === theme) return;
    apply(theme);
    try { window.dispatchEvent(new CustomEvent('ql-theme', { detail: theme })); } catch (e) {}
  }
  window.addEventListener('storage', function (event) { if (event.key === KEY) follow(); });
  window.addEventListener('pageshow', follow);
  if (window.matchMedia) {
    var query = matchMedia('(prefers-color-scheme: dark)');
    if (query.addEventListener) query.addEventListener('change', follow);
  }
})();
