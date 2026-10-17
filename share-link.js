/* Quiz LAB: share a paper (PA, GA, quiz, end term, mock) by its own link.
 * Any element with data-ql-share="<paper id>" becomes a Share button.
 * The link opens the paper's details on /papers, which handles sign-in,
 * free papers (start straight away) and paid papers (shows the price). */
(function () {
  if (window.QLShare) return;
  var ORIGIN = "https://quiz.genziitian.in";
  function linkFor(id) { return ORIGIN + "/papers?paper=" + encodeURIComponent(id); }
  var ICON = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></svg>';

  var WHATSAPP_ICON = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false"><path d="M20.52 3.48A11.9 11.9 0 0 0 12.05 0C5.45 0 .08 5.37.08 11.97c0 2.11.55 4.17 1.6 5.99L0 24l6.19-1.62a11.98 11.98 0 0 0 5.86 1.49h.01c6.6 0 11.97-5.37 11.97-11.97 0-3.2-1.25-6.2-3.51-8.42ZM12.06 21.85h-.01a9.92 9.92 0 0 1-5.04-1.38l-.36-.21-3.67.96.98-3.58-.23-.37a9.94 9.94 0 0 1-1.52-5.3c0-5.49 4.46-9.95 9.95-9.95a9.88 9.88 0 0 1 7.04 2.92 9.88 9.88 0 0 1 2.91 7.04c0 5.49-4.46 9.95-9.95 9.95Zm5.46-7.45c-.3-.15-1.77-.87-2.04-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.67-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.03-.52-.07-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.07-.79.37-.27.3-1.04 1.02-1.04 2.49s1.07 2.89 1.22 3.09c.15.2 2.1 3.2 5.09 4.49.71.31 1.27.49 1.71.62.72.23 1.37.19 1.88.12.57-.09 1.77-.72 2.02-1.42.25-.7.25-1.3.17-1.42-.07-.12-.27-.2-.57-.35Z"/></svg>';

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
      '<div class="qs-more"><a class="qs-wa" target="_blank" rel="noopener" href="https://wa.me/?text=' + encodeURIComponent((title ? title + " on Quiz LAB: " : "Try this paper on Quiz LAB: ") + url) + '">' + WHATSAPP_ICON + '<span>WhatsApp</span></a>' +
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
    "#ql-share-modal{position:fixed;inset:0;z-index:99998;display:grid;place-items:center;padding:16px;box-sizing:border-box;overflow-y:auto;background:rgba(2,6,23,.78);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px)}" +
    "#ql-share-modal .qs-card{position:relative;width:100%;max-width:440px;max-height:calc(100dvh - 32px);overflow-y:auto;box-sizing:border-box;border:1px solid #cbd5e1;background:#fff;color:#0f172a;border-radius:18px;padding:26px 24px 22px;box-shadow:0 32px 90px rgba(0,0,0,.6),0 0 0 1px rgba(255,255,255,.08);font-family:inherit;text-align:center}" +
    "#ql-share-modal .qs-x{position:absolute;top:10px;right:12px;border:0;background:transparent;font-size:24px;line-height:1;color:#94a3b8;cursor:pointer}" +
    "#ql-share-modal .qs-ico{width:52px;height:52px;margin:0 auto 12px;border-radius:14px;display:grid;place-items:center;background:#eef2ff;color:#4338ca}#ql-share-modal .qs-ico svg{width:24px;height:24px}" +
    "#ql-share-modal h2{margin:0 0 4px;font-size:19px;font-weight:800}" +
    "#ql-share-modal .qs-name{margin:0 0 8px;font-weight:700;color:#4338ca;font-size:14.5px}" +
    "#ql-share-modal .qs-info{margin:0 0 16px;color:#64748b;font-size:13.5px;line-height:1.5}" +
    "#ql-share-modal .qs-row{display:flex;gap:8px}#ql-share-modal .qs-row input{flex:1;min-width:0;font:inherit;font-size:13px;padding:10px 12px;border:1px solid #cbd5e1;border-radius:10px;background:#f8fafc;color:#334155}" +
    "#ql-share-modal .qs-copy{flex-shrink:0;padding:10px 16px;border:0;border-radius:10px;background:#4338ca;color:#fff;font:700 13.5px/1 inherit;font-family:inherit;cursor:pointer}#ql-share-modal .qs-copy.done{background:#16a34a}" +
    "#ql-share-modal .qs-more{display:flex;justify-content:center;flex-wrap:wrap;gap:8px;margin-top:12px}#ql-share-modal .qs-more a,#ql-share-modal .qs-more button{padding:8px 14px;border-radius:9px;border:1px solid #d6dcea;background:#fff;color:#334155;font:600 13px/1 inherit;font-family:inherit;text-decoration:none;cursor:pointer}#ql-share-modal .qs-wa{display:inline-flex;align-items:center;justify-content:center;gap:8px;color:#15803d!important;border-color:#bbf7d0!important;background:#f0fdf4!important}" +
    ":root[data-theme=dark] #ql-share-modal .qs-card{background:#1e293b;border-color:#64748b;color:#f8fafc}:root[data-theme=dark] #ql-share-modal .qs-row input{background:#0f1520;border-color:#263044;color:#cbd5e1}:root[data-theme=dark] #ql-share-modal .qs-ico{background:rgba(99,102,241,.18);color:#a5b4fc}:root[data-theme=dark] #ql-share-modal .qs-more button{background:#1e293b;border-color:#334155;color:#cbd5e1}" +
    ":root[data-theme=dark] #ql-share-modal .qs-info{color:#cbd5e1}:root[data-theme=dark] #ql-share-modal .qs-name{color:#c7d2fe}#ql-share-modal .qs-wa svg{display:block;flex:none}#ql-share-modal :focus-visible{outline:3px solid #818cf8;outline-offset:3px}@media(max-width:400px){#ql-share-modal .qs-row{flex-direction:column}#ql-share-modal .qs-card{padding:26px 18px 20px}}" +
    "#ql-share-toast{position:fixed;left:50%;bottom:28px;transform:translate(-50%,20px);background:#0f172a;color:#fff;padding:10px 16px;border-radius:10px;font:600 13px/1.2 system-ui,sans-serif;opacity:0;pointer-events:none;transition:opacity .2s,transform .2s;z-index:99999}" +
    "#ql-share-toast.show{opacity:1;transform:translate(-50%,0)}";
  (document.head || document.documentElement).appendChild(css);

  window.QLShare = { share: share, button: button, link: linkFor };
})();
