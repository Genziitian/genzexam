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
    var phone = window.matchMedia && window.matchMedia("(pointer: coarse)").matches;
    if (phone && navigator.share) {
      navigator.share({ title: title || "Quiz LAB paper", text: (title ? title + " on Quiz LAB" : "Try this paper on Quiz LAB"), url: url }).catch(function () {});
      return;
    }
    copy(url).then(function () { toast("Link copied"); }, function () { window.prompt("Copy this link", url); });
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
    "#ql-share-toast{position:fixed;left:50%;bottom:28px;transform:translate(-50%,20px);background:#0f172a;color:#fff;padding:10px 16px;border-radius:10px;font:600 13px/1.2 system-ui,sans-serif;opacity:0;pointer-events:none;transition:opacity .2s,transform .2s;z-index:99999}" +
    "#ql-share-toast.show{opacity:1;transform:translate(-50%,0)}";
  (document.head || document.documentElement).appendChild(css);

  window.QLShare = { share: share, button: button, link: linkFor };
})();
