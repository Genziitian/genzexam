/* Manager: reported questions. Lists student reports with the question,
 * paper, reasons, comment, reporter and time, and lets managers jump to
 * the question editor and mark each report resolved or dismissed. */
(function () {
  "use strict";
  const API = ((window.QLStorefront && window.QLStorefront.apiBase) || "https://labapi.genziitian.in/public/api").replace(/\/+$/, "");
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const st = { status: "open", rows: [], reasons: {}, toastTimer: null };
  function token() { try { return localStorage.getItem("lab_token") || ""; } catch (_) { return ""; } }
  async function api(path, method, body) {
    const res = await fetch(API + path, { method: method || "GET", headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), Authorization: "Bearer " + token() }, body: body ? JSON.stringify(body) : undefined });
    let data = null; try { data = await res.json(); } catch (_) {}
    if (res.status === 401) { location.assign("/login"); throw new Error("Your session expired."); }
    if (!res.ok) throw new Error((data && (data.message || data.error)) || "Request failed (" + res.status + ")");
    return data;
  }
  function toast(m) { const t = $("toast"); t.textContent = m; t.classList.add("show"); clearTimeout(st.toastTimer); st.toastTimer = setTimeout(() => t.classList.remove("show"), 2600); }
  const when = (iso) => (iso ? new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" }) : "");
  const section = { practice: "Practice Assignment", practice_graded: "Graded Assignment", quiz1: "Quiz 1", quiz2: "Quiz 2", end_term: "End Term", mock: "Mock Test" };

  function card(r) {
    const q = r.question, quiz = r.quiz, u = r.user, ide = r.ide_problem;
    const opts = (q && q.question_options || []).slice().sort((a, b) => (a.position || 0) - (b.position || 0));
    const fixHref = quiz && q ? "/manager/sales?paper=" + encodeURIComponent(quiz.id) + "&question=" + encodeURIComponent(q.id) : "";
    return '<article class="rep ' + esc(r.status) + '" data-id="' + r.id + '">' +
      '<div class="rep-head"><h3>' + (ide ? "IDE · " + esc(ide.title) : (r.question_number ? "Question " + esc(r.question_number) + " · " : "") + esc(quiz ? quiz.title : "Deleted paper")) + "</h3>" +
      '<span class="when">' + esc(when(r.created_at)) + "</span></div>" +
      '<div class="rep-meta"><span>' + esc(ide ? (ide.course ? ide.course.name : "") + " · IDE problem" : quiz && quiz.course ? quiz.course.name : "") + (!ide && quiz ? " · " + esc(section[quiz.section] || quiz.section || "") : "") + (!ide && quiz ? (quiz.is_active ? " · Live" : " · Offline") : "") + "</span>" +
      "<span>Reported by <b>" + esc(u ? u.name : "Deleted user") + "</b>" + (u ? " · " + esc(u.email) : "") + "</span></div>" +
      '<div class="rep-reasons">' + (r.reasons || []).map((k) => "<span>" + esc(st.reasons[k] || k) + "</span>").join("") + "</div>" +
      (r.comment ? '<p class="rep-comment">“' + esc(r.comment) + "”</p>" : "") +
      (ide ? '<details class="rep-q"><summary>Show the IDE problem</summary><p>' + esc(ide.description) + "</p><p>Sample input:<br>" + esc(ide.sample_input).replace(/\n/g, "<br>") + "</p><p>Sample output:<br>" + esc(ide.sample_output).replace(/\n/g, "<br>") + "</p></details>" : q ? '<details class="rep-q"><summary>Show the question (' + esc(q.type) + " · " + esc(q.marks) + " marks)</summary><p>" + esc(q.stem) + "</p>" +
        (opts.length ? "<ul>" + opts.map((o) => "<li" + (o.is_correct ? ' class="ok"' : "") + ">" + esc(o.option_text) + (o.is_correct ? " ✓" : "") + "</li>").join("") + "</ul>" : "") +
        (q.type === "numerical" ? "<p>Answer key: <b>" + esc(q.numerical_answer) + "</b> ± " + esc(q.numerical_tolerance) + "</p>" : "") + "</details>"
        : '<p class="rep-empty">This question has been deleted.</p>') +
      (r.status !== "open" ? '<div class="rep-meta"><span>' + (r.status === "resolved" ? "Resolved" : "Dismissed") + (r.resolver ? " by " + esc(r.resolver.name) : "") + " · " + esc(when(r.resolved_at)) + "</span>" + (r.manager_note ? "<span>Note: " + esc(r.manager_note) + "</span>" : "") + "</div>" : "") +
      '<div class="rep-actions">' + (ide ? '<a class="fix" href="/admin/ide-problems">Edit IDE problems →</a>' : fixHref ? '<a class="fix" href="' + fixHref + '">Edit question →</a>' : "") +
      (r.status === "open"
        ? '<input type="text" maxlength="1000" placeholder="Note (optional), e.g. answer key corrected" data-note><button type="button" class="primary" data-set="resolved">Mark resolved</button><button type="button" class="quiet" data-set="dismissed">Dismiss</button>'
        : '<button type="button" class="quiet" data-set="open">Reopen</button>') +
      "</div></article>";
  }
  function render() {
    const term = $("search").value.trim().toLowerCase();
    const rows = st.rows.filter((r) => !term || [r.quiz && r.quiz.title, r.ide_problem && r.ide_problem.title, r.user && r.user.name, r.user && r.user.email, r.comment, r.question && r.question.stem].join(" ").toLowerCase().includes(term));
    $("list").innerHTML = rows.length ? rows.map(card).join("") : '<p class="rep-empty">' + (st.status === "open" ? "No open reports. Nice." : "Nothing here.") + "</p>";
  }
  async function load(isRetry) {
    $("list").innerHTML = '<p class="rep-empty">Loading…</p>';
    try {
      const d = await api("/manager/question-reports?status=" + st.status);
      st.rows = d.reports || []; st.reasons = d.reasons || {};
      const c = d.counts || {}; ["open", "resolved", "dismissed"].forEach((k) => { $("c-" + k).textContent = c[k] || 0; });
      render();
    } catch (e) {
      if (!isRetry) {
        try {
          await api("/manager/system/migrate", "POST");
          return await load(true);
        } catch (_) {}
      }
      $("list").innerHTML = '<div class="rep-empty"><p>Could not load reports: ' + esc(e.message) + '</p><button type="button" class="primary" style="margin-top:12px;padding:8px 16px;font-weight:600;cursor:pointer;" id="rep-repair-btn">Run Database Update</button></div>';
      const b = $("rep-repair-btn");
      if (b) b.onclick = async () => {
        b.disabled = true; b.textContent = "Updating database...";
        try {
          await api("/manager/system/migrate", "POST");
          toast("Database updated!");
          await load(true);
        } catch (err) {
          toast("Update failed: " + err.message);
          b.disabled = false; b.textContent = "Run Database Update";
        }
      };
    }
  }
  document.querySelector(".rep-tabs").addEventListener("click", (e) => {
    const b = e.target.closest("[data-status]"); if (!b) return;
    st.status = b.dataset.status;
    document.querySelectorAll(".rep-tabs [data-status]").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
    load();
  });
  $("search").addEventListener("input", render);
  $("refresh").addEventListener("click", load);
  $("list").addEventListener("click", async (e) => {
    const b = e.target.closest("[data-set]"); if (!b) return;
    const art = b.closest("[data-id]"); const note = art.querySelector("[data-note]");
    b.disabled = true;
    try {
      await api("/manager/question-reports/" + art.dataset.id, "PATCH", { status: b.dataset.set, ...(note ? { manager_note: note.value.trim() || null } : {}) });
      toast(b.dataset.set === "resolved" ? "Marked resolved" : b.dataset.set === "dismissed" ? "Dismissed" : "Reopened");
      await load();
    } catch (err) { toast(err.message); b.disabled = false; }
  });
  async function boot() {
    const gate = $("gate");
    if (!token()) return location.assign("/login");
    try {
      const me = await api("/auth/me"); const user = me.user || me;
      if (!user || user.role !== "manager") { gate.textContent = "Only manager accounts can see reported questions."; gate.classList.add("error"); return; }
      $("me").textContent = user.name || user.email || "";
    } catch (err) { gate.textContent = "Could not verify your account: " + err.message; gate.classList.add("error"); return; }
    gate.hidden = true; $("workspace").hidden = false; load();
  }
  boot();
})();
