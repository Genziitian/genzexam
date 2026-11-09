/* Manager: login failures. Lists every failed sign-in with its reason, the account's
 * state (has password? has Google? verified?), device and IP, plus counts by reason. */
(function () {
  "use strict";
  const API = ((window.QLStorefront && window.QLStorefront.apiBase) || "https://labapi.genziitian.in/public/api").replace(/\/+$/, "");
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const st = { data: null, reason: "", timer: null, toastTimer: null };
  const METHOD = { email: "Email + password", google: "Google (website)", google_app: "Google (app)", otp: "Signup OTP", register: "Sign up", password_reset: "Password reset", client: "Browser" };
  const FIX = {
    google_only_account: "Tell them to use “Continue with Google”, or set a password via Forgot password.",
    not_verified: "They never finished the OTP. Ask them to sign up again with the same email to get a new OTP (check spam).",
    wrong_password: "Ask them to use Forgot password.",
    no_account: "Typo in the email, or they signed up with a different email / Google.",
    rate_limited: "Many attempts from one IP (college Wi-Fi / mobile data share IPs). Wait a minute and retry.",
    network_error: "The phone could not reach the server: weak network, VPN/ad-blocker, or the host dropped the connection.",
    otp_expired: "OTP is valid for 10 minutes. Resend OTP.",
    otp_email_failed: "Mail server failed: check MAIL_* settings in backend .env.",
    google_exception: "Server-side error: see the detail text.",
    token_invalid: "App's Google client ID does not match the server's GOOGLE_CLIENT_ID, or the token expired.",
    profile_failed: "Google login worked but /auth/me failed right after.",
    deactivated: "Account is deactivated by an admin.",
  };
  function token() { try { return localStorage.getItem("lab_token") || ""; } catch (_) { return ""; } }
  async function api(path, method) {
    const res = await fetch(API + path, { method: method || "GET", headers: { Accept: "application/json", Authorization: "Bearer " + token() } });
    let data = null; try { data = await res.json(); } catch (_) {}
    if (res.status === 401) { location.assign("/login"); throw new Error("Your session expired."); }
    if (!res.ok) throw new Error((data && (data.message || data.error)) || "Request failed (" + res.status + ")");
    return data;
  }
  function toast(m) { const t = $("toast"); t.textContent = m; t.classList.add("show"); clearTimeout(st.toastTimer); st.toastTimer = setTimeout(() => t.classList.remove("show"), 2600); }
  const when = (iso) => (iso ? new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit", second: "2-digit" }) : "");
  function device(ua) {
    ua = ua || "";
    const os = /iPhone|iPad/.test(ua) ? "iPhone/iPad" : /Android/.test(ua) ? "Android" : /Mac OS X/.test(ua) ? "Mac" : /Windows/.test(ua) ? "Windows" : /Linux/.test(ua) ? "Linux" : "?";
    const br = /; wv\)|okhttp|Dalvik/.test(ua) ? "App/WebView" : /CriOS|Chrome\//.test(ua) && !/Edg/.test(ua) ? "Chrome" : /Edg/.test(ua) ? "Edge" : /FxiOS|Firefox/.test(ua) ? "Firefox" : /Safari/.test(ua) ? "Safari" : "?";
    return os + " · " + br;
  }
  function accountLine(u) {
    if (!u) return "";
    const tags = [u.has_password ? "has password" : "no password", u.has_google ? "Google linked" : "no Google", u.verified ? "verified" : "NOT verified", u.active ? "active" : "DEACTIVATED"];
    return '<span class="lf-acct">Account: <b>' + esc(u.name) + "</b> · " + tags.map(esc).join(" · ") + " · joined " + esc(when(u.joined)) + "</span>";
  }
  function row(f, reasons) {
    const fix = FIX[f.reason];
    return '<article class="lf-row r-' + esc(f.reason) + '">' +
      '<div class="lf-top"><span class="lf-reason">' + esc(reasons[f.reason] || f.reason) + '</span><span class="lf-method">' + esc(METHOD[f.method] || f.method) + "</span>" +
      (f.source === "browser" ? '<span class="lf-src">reported by browser</span>' : "") + '<span class="lf-when">' + esc(when(f.at)) + "</span></div>" +
      '<div class="lf-who"><b>' + esc(f.email || "(no email)") + "</b>" + (f.ip ? " · IP " + esc(f.ip) : "") + " · " + esc(device(f.user_agent)) + (f.page ? " · page " + esc(f.page) : "") + "</div>" +
      (f.message ? '<div class="lf-msg">' + esc(f.message) + "</div>" : "") +
      accountLine(f.user) +
      (fix ? '<div class="lf-fix">What to do: ' + esc(fix) + "</div>" : "") +
      (f.detail || f.user_agent ? '<details><summary>Technical detail</summary><pre>' + esc((f.detail ? f.detail + "\n" : "") + (f.user_agent || "")) + "</pre></details>" : "") +
      "</article>";
  }
  function render() {
    const d = st.data; if (!d) return;
    const reasons = d.reasons || {};
    const chips = Object.entries(d.by_reason || {}).map(([k, n]) => '<button type="button" data-reason="' + esc(k) + '" aria-pressed="' + (st.reason === k) + '">' + esc(reasons[k] || k) + " <b>" + n + "</b></button>").join("");
    const top = (d.top_emails || []).filter((t) => t.n > 1).slice(0, 8).map((t) => '<button type="button" class="lf-email" data-email="' + esc(t.email) + '">' + esc(t.email) + " <b>×" + t.n + "</b></button>").join("");
    $("summary").innerHTML = '<div class="lf-total"><b>' + (d.total || 0) + "</b> failures in the last " + d.days + " day" + (d.days > 1 ? "s" : "") + "</div>" +
      (chips ? '<div class="lf-chips"><button type="button" data-reason="" aria-pressed="' + (st.reason === "") + '">All</button>' + chips + "</div>" : "") +
      (top ? '<div class="lf-top-emails"><span>Failing repeatedly:</span>' + top + "</div>" : "");
    const rows = d.failures || [];
    $("list").innerHTML = rows.length ? rows.map((f) => row(f, reasons)).join("") : '<p class="rep-empty">No login failures in this period.</p>';
  }
  async function load(isRetry) {
    $("list").innerHTML = '<p class="rep-empty">Loading…</p>';
    const qs = new URLSearchParams({ days: $("days").value });
    if ($("method").value) qs.set("method", $("method").value);
    if (st.reason) qs.set("reason", st.reason);
    if ($("search").value.trim()) qs.set("q", $("search").value.trim());
    try {
      st.data = await api("/manager/login-failures?" + qs.toString());
      render();
    } catch (e) {
      if (!isRetry) { try { await api("/manager/system/migrate", "POST"); return await load(true); } catch (_) {} }
      $("list").innerHTML = '<p class="rep-empty">Could not load login failures: ' + esc(e.message) + "</p>";
    }
  }
  $("summary").addEventListener("click", (e) => {
    const r = e.target.closest("[data-reason]"); if (r) { st.reason = r.dataset.reason; load(); return; }
    const m = e.target.closest("[data-email]"); if (m) { $("search").value = m.dataset.email; load(); }
  });
  $("days").addEventListener("change", () => load());
  $("method").addEventListener("change", () => load());
  $("search").addEventListener("input", () => { clearTimeout(st.timer); st.timer = setTimeout(load, 350); });
  $("refresh").addEventListener("click", () => { load(); toast("Refreshed"); });
  async function boot() {
    const gate = $("gate");
    if (!token()) return location.assign("/login");
    try {
      const me = await api("/auth/me"); const user = me.user || me;
      if (!user || user.role !== "manager") { gate.textContent = "Only manager accounts can see login failures."; gate.classList.add("error"); return; }
      $("me").textContent = user.name || user.email || "";
    } catch (err) { gate.textContent = "Could not verify your account: " + err.message; gate.classList.add("error"); return; }
    gate.hidden = true; $("workspace").hidden = false; load();
  }
  boot();
})();
