/* Quiz LAB: share a paper (PA, GA, quiz, end term, mock) by its own link.
 * Any element with data-ql-share="<paper id>" becomes a Share button.
 * The link opens the paper's details on /papers, which handles sign-in,
 * free papers (start straight away) and paid papers (shows the price). */
(function () {
  if (window.QLShare) return;
  var ORIGIN = "https://quiz.genziitian.in";
  function linkFor(id) { return ORIGIN + "/papers?paper=" + encodeURIComponent(id); }
  var ICON = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></svg>';

  function toast(text) {
    var t = document.getElementById("ql-share-toast");
    if (!t) { t = document.createElement("div"); t.id = "ql-share-toast"; document.body.appendChild(t); }
    t.textContent = text; t.className = "show";
    clearTimeout(toast.timer); toast.timer = setTimeout(function () { t.className = ""; }, 2200);
  }
  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    return new Promise(function (ok, fail) {
      var a = document.createElement("textarea"); a.value = text; a.style.position = "fixed"; a.style.opacity = "0";
      document.body.appendChild(a); a.select();
      try { document.execCommand("copy") ? ok() : fail(); } catch (e) { fail(e); } a.remove();
    });
  }
  function share(id, title) {
    var url = linkFor(id);
    var old = document.getElementById("ql-share-modal"); if (old) old.remove();
    var m = document.createElement("div"); m.id = "ql-share-modal";
    var esc = function (v) { return String(v || "").replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); };
    m.innerHTML =
      '<div class="qs-card" role="dialog" aria-modal="true" aria-labelledby="qs-title">' +
      '<button type="button" class="qs-x" data-qs-close aria-label="Close">×</button>' +
      '<div class="qs-ico" aria-hidden="true">' + ICON + '</div>' +
      '<h2 id="qs-title">Share this paper</h2>' +
      (title ? '<p class="qs-name">' + esc(title) + '</p>' : '') +
      '<p class="qs-info">Anyone with this link can open the paper on Quiz LAB. They sign in first; free papers start straight away and paid papers show the price.</p>' +
      '<div class="qs-row"><input type="text" readonly value="' + esc(url) + '" aria-label="Paper link"><button type="button" class="qs-copy">Copy link</button></div>' +
      '<div class="qs-more"><a class="qs-wa" target="_blank" rel="noopener" href="https://wa.me/?text=' + encodeURIComponent((title ? title + " on Quiz LAB: " : "Try this paper on Quiz LAB: ") + url) + '">WhatsApp</a>' +
      (navigator.share ? '<button type="button" class="qs-native">More options</button>' : '') + '</div>' +
      '</div>';
    document.body.appendChild(m);
    var input = m.querySelector("input"), btn = m.querySelector(".qs-copy");
    var close = function () { m.remove(); document.removeEventListener("keydown", onKey); };
    var onKey = function (e) { if (e.key === "Escape") close(); };
    document.addEventListener("keydown", onKey);
    m.addEventListener("click", function (e) { if (e.target === m || e.target.closest("[data-qs-close]")) close(); });
    input.addEventListener("focus", function () { input.select(); });
    btn.addEventListener("click", function () {
      copy(url).then(function () { btn.textContent = "Copied ✓"; btn.classList.add("done"); setTimeout(function () { btn.textContent = "Copy link"; btn.classList.remove("done"); }, 2000); },
        function () { input.focus(); input.select(); toast("Press Ctrl+C to copy"); });
    });
    var nat = m.querySelector(".qs-native");
    if (nat) nat.addEventListener("click", function () { navigator.share({ title: title || "Quiz LAB paper", url: url }).catch(function () {}); });
    btn.focus();
  }
  function button(id, title, extraClass) {
    var b = document.createElement("button");
    b.type = "button"; b.className = "ql-share-btn" + (extraClass ? " " + extraClass : "");
    b.setAttribute("data-ql-share", id); if (title) b.setAttribute("data-ql-share-title", title);
    b.setAttribute("aria-label", "Share link to this paper"); b.title = "Share link";
    b.innerHTML = ICON + "<span>Share</span>";
    return b;
  }
  // Capture phase so a Share button inside a card link does not open the paper.
  document.addEventListener("click", function (e) {
    var el = e.target.closest && e.target.closest("[data-ql-share]");
    if (!el) return;
    e.preventDefault(); e.stopPropagation();
    share(el.getAttribute("data-ql-share"), el.getAttribute("data-ql-share-title") || "");
  }, true);

  var css = document.createElement("style");
  css.textContent =
    ".ql-share-btn{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 12px;border-radius:8px;border:1px solid #d6dcea;background:#fff;color:#334155;font:600 12.5px/1 inherit;font-family:inherit;cursor:pointer;transition:background .15s,border-color .15s,color .15s}" +
    ".ql-share-btn:hover{border-color:#4338ca;color:#4338ca;background:#eef2ff}" +
    ".ql-share-btn.ql-share-corner{position:absolute;top:10px;right:10px;z-index:2;height:28px;padding:0 9px;font-size:11.5px}" +
    ".ql-share-btn.ql-share-icon span{display:none}.ql-share-btn.ql-share-icon{padding:0 9px}" +
    "html.dark .ql-share-btn,[data-theme=dark] .ql-share-btn{background:#1e293b;border-color:#334155;color:#cbd5e1}" +
    "#ql-share-modal{position:fixed;inset:0;z-index:99998;display:grid;place-items:center;padding:16px;background:rgba(15,23,42,.55)}" +
    "#ql-share-modal .qs-card{position:relative;width:100%;max-width:440px;background:#fff;color:#0f172a;border-radius:18px;padding:26px 24px 22px;box-shadow:0 25px 60px -15px rgba(0,0,0,.4);font-family:inherit;text-align:center}" +
    "#ql-share-modal .qs-x{position:absolute;top:10px;right:12px;border:0;background:transparent;font-size:24px;line-height:1;color:#94a3b8;cursor:pointer}" +
    "#ql-share-modal .qs-ico{width:52px;height:52px;margin:0 auto 12px;border-radius:14px;display:grid;place-items:center;background:#eef2ff;color:#4338ca}#ql-share-modal .qs-ico svg{width:24px;height:24px}" +
    "#ql-share-modal h2{margin:0 0 4px;font-size:19px;font-weight:800}" +
    "#ql-share-modal .qs-name{margin:0 0 8px;font-weight:700;color:#4338ca;font-size:14.5px}" +
    "#ql-share-modal .qs-info{margin:0 0 16px;color:#64748b;font-size:13.5px;line-height:1.5}" +
    "#ql-share-modal .qs-row{display:flex;gap:8px}#ql-share-modal .qs-row input{flex:1;min-width:0;font:inherit;font-size:13px;padding:10px 12px;border:1px solid #cbd5e1;border-radius:10px;background:#f8fafc;color:#334155}" +
    "#ql-share-modal .qs-copy{flex-shrink:0;padding:10px 16px;border:0;border-radius:10px;background:#4338ca;color:#fff;font:700 13.5px/1 inherit;font-family:inherit;cursor:pointer}#ql-share-modal .qs-copy.done{background:#16a34a}" +
    "#ql-share-modal .qs-more{display:flex;justify-content:center;gap:8px;margin-top:12px}#ql-share-modal .qs-more a,#ql-share-modal .qs-more button{padding:8px 14px;border-radius:9px;border:1px solid #d6dcea;background:#fff;color:#334155;font:600 13px/1 inherit;font-family:inherit;text-decoration:none;cursor:pointer}#ql-share-modal .qs-wa{color:#15803d!important;border-color:#bbf7d0!important;background:#f0fdf4!important}" +
    ":root[data-theme=dark] #ql-share-modal .qs-card{background:#151b28;color:#f1f5f9}:root[data-theme=dark] #ql-share-modal .qs-row input{background:#0f1520;border-color:#263044;color:#cbd5e1}:root[data-theme=dark] #ql-share-modal .qs-ico{background:rgba(99,102,241,.18);color:#a5b4fc}:root[data-theme=dark] #ql-share-modal .qs-more button{background:#1e293b;border-color:#334155;color:#cbd5e1}" +
    "#ql-share-toast{position:fixed;left:50%;bottom:28px;transform:translate(-50%,20px);background:#0f172a;color:#fff;padding:10px 16px;border-radius:10px;font:600 13px/1.2 system-ui,sans-serif;opacity:0;pointer-events:none;transition:opacity .2s,transform .2s;z-index:99999}" +
    "#ql-share-toast.show{opacity:1;transform:translate(-50%,0)}";
  (document.head || document.documentElement).appendChild(css);

  window.QLShare = { share: share, button: button, link: linkFor };
})();
