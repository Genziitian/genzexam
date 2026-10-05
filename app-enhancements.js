/*
 * Quiz Lab — UI enhancements layered over the built React app.
 *
 * The React source for the student app no longer exists, only the compiled
 * bundle, so changes that need new component behaviour are applied here
 * against the rendered DOM instead of by editing minified JavaScript.
 *
 * Everything in this file is defensive: if the markup it expects is not
 * found it simply does nothing, leaving the app exactly as it was.
 */
(function () {
  "use strict";

  /* ---------------------------------------------------------------
   * Discussions: turn the long SUBJECT / COURSE chip rows into selects.
   * The select drives the original chips, so React still owns the state.
   * ------------------------------------------------------------- */

  var ROWS = ["SUBJECT", "COURSE"];

  function injectStyles() {
    if (document.getElementById("ql-enhance-styles")) return;
    var css = document.createElement("style");
    css.id = "ql-enhance-styles";
    css.textContent =
      ".ql-filter-select{appearance:none;-webkit-appearance:none;background-color:#fff;" +
      "background-image:url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2364748b' stroke-width='2.5' stroke-linecap='round'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E\");" +
      "background-repeat:no-repeat;background-position:right 11px center;" +
      "border:1px solid #e2e8f0;border-radius:9px;color:#0f172a;cursor:pointer;" +
      "font:500 13px/1 Inter,system-ui,-apple-system,sans-serif;" +
      "padding:9px 32px 9px 12px;min-width:170px;transition:border-color .15s ease,box-shadow .15s ease}" +
      ".ql-filter-select:hover{border-color:#cbd5e1}" +
      ".ql-filter-select:focus{outline:none;border-color:#16a34a;box-shadow:0 0 0 3px rgba(22,163,74,.12)}" +
      ".ql-chips-hidden{display:none!important}";
    document.head.appendChild(css);
  }

  function luminance(rgb) {
    var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(rgb || "");
    if (!m) return 255;
    return 0.299 * +m[1] + 0.587 * +m[2] + 0.114 * +m[3];
  }

  /** The selected chip is the visually darkest one in the row. */
  function activeChip(chips) {
    var best = null, bestLum = 1e9;
    chips.forEach(function (c) {
      var lum = luminance(getComputedStyle(c).backgroundColor);
      if (lum < bestLum) { bestLum = lum; best = c; }
    });
    return bestLum < 160 ? best : null;
  }

  function findLabel(text) {
    var nodes = document.querySelectorAll("span,p,div,label");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.children.length === 0 && el.textContent.trim().toUpperCase() === text) return el;
    }
    return null;
  }

  function convertRow(labelText) {
    var label = findLabel(labelText);
    if (!label || !label.parentElement) return;

    var row = label.parentElement;
    var chips = Array.prototype.filter.call(row.querySelectorAll("button"), function (b) {
      return b.textContent.trim().length > 0 && !b.classList.contains("ql-skip");
    });
    if (chips.length < 3) return; // not the row we are looking for

    var existing = row.querySelector(".ql-filter-select");
    var current = activeChip(chips);
    var currentText = current ? current.textContent.trim() : chips[0].textContent.trim();

    if (existing) {
      // React re-rendered: keep the select in step rather than rebuilding it.
      if (existing.value !== currentText) existing.value = currentText;
      chips.forEach(function (c) { c.classList.add("ql-chips-hidden"); });
      return;
    }

    var select = document.createElement("select");
    select.className = "ql-filter-select";
    select.setAttribute("aria-label", labelText.toLowerCase() + " filter");

    chips.forEach(function (c) {
      var t = c.textContent.trim();
      var opt = document.createElement("option");
      opt.value = t;
      opt.textContent = t === "All" ? "All " + labelText.toLowerCase() + "s" : t;
      select.appendChild(opt);
    });
    select.value = currentText;

    select.addEventListener("change", function () {
      var want = select.value;
      var target = chips.filter(function (c) { return c.textContent.trim() === want; })[0];
      if (target) {
        target.classList.remove("ql-chips-hidden");
        target.click();
        target.classList.add("ql-chips-hidden");
      }
    });

    chips.forEach(function (c) { c.classList.add("ql-chips-hidden"); });
    row.appendChild(select);
  }

  function run() {
    if (!/\/discussions/i.test(window.location.pathname)) return;
    injectStyles();
    ROWS.forEach(convertRow);
  }

  var pending = null;
  function schedule() {
    clearTimeout(pending);
    pending = setTimeout(run, 120);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule);
  } else {
    schedule();
  }

  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener("popstate", schedule);

  var lastPath = window.location.pathname;
  setInterval(function () {
    if (window.location.pathname !== lastPath) { lastPath = window.location.pathname; schedule(); }
  }, 500);
})();
