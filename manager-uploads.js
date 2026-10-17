/* Manager: student uploads. Review what Pro students turned into tests,
 * file one under a course and week, and publish a public copy. */
(function () {
  "use strict";
  const API = ((window.QLStorefront && window.QLStorefront.apiBase) || "https://labapi.genziitian.in/public/api").replace(/\/+$/, "");
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const SECTIONS = { practice: "Practice Assignment", practice_graded: "Graded Assignment", quiz1: "Quiz 1", quiz2: "Quiz 2", endterm: "End Term", mock_test: "Mock Test" };
  const st = { state: "new", rows: [], courses: [], weeks: {}, open: null, toastTimer: null };
  function token() { try { return localStorage.getItem("lab_token") || ""; } catch (_) { return ""; } }
  async function api(path, method, body) {
    const res = await fetch(API + path, { method: method || "GET", headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), Authorization: "Bearer " + token() }, body: body ? JSON.stringify(body) : undefined });
    let data = null; try { data = await res.json(); } catch (_) {}
    if (res.status === 401) { location.assign("/login"); throw new Error("Your session expired."); }
    if (!res.ok) throw new Error((data && (data.message || data.error)) || "Request failed (" + res.status + ")");
    return data;
  }
  function toast(m) { const t = $("toast"); t.textContent = m; t.classList.add("show"); clearTimeout(st.toastTimer); st.toastTimer = setTimeout(() => t.classList.remove("show"), 2800); }
  const when = (iso) => (iso ? new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" }) : "");

  function card(p) {
    const pub = !!p.published_quiz_id;
    return '<article class="up' + (pub ? " published" : "") + '" data-id="' + p.id + '">' +
      '<div class="up-head"><h3>' + esc(p.title) + "</h3><span>" + (pub ? '<span class="up-tag">Published</span> ' : "") + esc(when(p.created_at)) + "</span></div>" +
      '<div class="up-meta"><span>' + esc(p.question_count) + " questions</span><span>By <b>" + esc(p.owner ? p.owner.name : "Deleted user") + "</b>" + (p.owner ? " · " + esc(p.owner.email) : "") + "</span></div>" +
      '<div class="up-actions"><button type="button" class="primary" data-review>' + (pub ? "Edit details" : "Review & publish") + "</button>" +
      (pub ? '<a href="/manager/sales?paper=' + encodeURIComponent(p.published_quiz_id) + '">Edit questions →</a><button type="button" data-unpublish>Unpublish</button>' : "") + "</div>" +
      '<div class="up-slot"></div></article>';
  }
  function render() {
    const term = $("search").value.trim().toLowerCase();
    const rows = st.rows.filter((p) => !term || [p.title, p.owner && p.owner.name, p.owner && p.owner.email].join(" ").toLowerCase().includes(term));
    $("list").innerHTML = rows.length ? rows.map(card).join("") : '<p class="rep-empty">' + (st.state === "new" ? "Nothing waiting for review." : "Nothing here.") + "</p>";
  }
  async function load(isRetry) {
    $("list").innerHTML = '<p class="rep-empty">Loading…</p>';
    try {
      const d = await api("/manager/uploaded-papers?state=" + st.state);
      st.rows = d.papers || [];
      const c = d.counts || {}; $("c-new").textContent = c.new || 0; $("c-published").textContent = c.published || 0;
      render();
    } catch (e) {
      if (!isRetry) {
        try {
          await api("/manager/system/migrate", "POST");
          return await load(true);
        } catch (_) {}
      }
      $("list").innerHTML = '<div class="rep-empty"><p>Could not load uploads: ' + esc(e.message) + '</p><button type="button" class="primary" style="margin-top:12px;padding:8px 16px;font-weight:600;cursor:pointer;" id="up-repair-btn">Run Database Update</button></div>';
      const b = $("up-repair-btn");
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
  async function weeksFor(courseId) {
    if (!courseId) return [];
    if (!st.weeks[courseId]) { try { const w = await api("/manager/courses/" + courseId + "/weeks"); st.weeks[courseId] = Array.isArray(w) ? w : (w.weeks || []); } catch (_) { st.weeks[courseId] = []; } }
    return st.weeks[courseId];
  }
  function options(list, value, label) { return list.map((x) => '<option value="' + esc(x.value) + '"' + (String(x.value) === String(value) ? " selected" : "") + ">" + esc(x.label) + "</option>").join(""); }
  async function openPanel(art) {
    const id = art.dataset.id, slot = art.querySelector(".up-slot");
    if (slot.firstChild) { slot.innerHTML = ""; return; }
    slot.innerHTML = '<p class="rep-empty">Loading…</p>';
    let d;
    try { d = await api("/manager/uploaded-papers/" + id); } catch (e) { slot.innerHTML = '<p class="rep-empty">' + esc(e.message) + "</p>"; return; }
    const p = d.paper, courseId = p.course_id;
    const weeks = await weeksFor(courseId);
    const qs = (d.questions || []).map((q, i) => '<div class="up-q"><p><b>' + (i + 1) + ".</b> " + esc(q.stem) + " <i>(" + esc(q.type) + ", " + esc(q.marks) + " marks)</i></p>" +
      ((q.options || []).length ? "<ul>" + q.options.map((o) => "<li" + (o.is_correct ? ' class="ok"' : "") + ">" + esc(o.text) + (o.is_correct ? " ✓" : "") + "</li>").join("") + "</ul>" : "") +
      (q.type === "numerical" ? "<p>Answer: <b>" + esc(q.numerical_answer) + "</b></p>" : "") + "</div>").join("");
    slot.innerHTML = '<div class="up-panel"><details open><summary><b>Questions (' + esc(p.question_count) + ")</b></summary><div class=\"up-qs\">" + (qs || "<p>No questions.</p>") + "</div></details>" +
      '<form class="up-form"><label class="wide">Title<input name="title" required maxlength="200" value="' + esc(p.title) + '"></label>' +
      '<label>Course<select name="course_id" required>' + options(st.courses.map((c) => ({ value: c.id, label: c.name })), courseId) + "</select></label>" +
      '<label>Week / topic<select name="week_id"><option value="">No week</option>' + options(weeks.map((w) => ({ value: w.id, label: "Week " + w.week_number + (w.title ? " · " + w.title : "") })), "") + "</select></label>" +
      '<label>Paper type<select name="section">' + options(Object.keys(SECTIONS).map((k) => ({ value: k, label: SECTIONS[k] })), p.section || "practice") + "</select></label>" +
      '<label>Year<input name="year" type="number" min="2000" max="2100" placeholder="e.g. 2025"></label>' +
      '<label>Time limit (minutes)<input name="time_limit_minutes" type="number" min="1" max="600" placeholder="Untimed"></label>' +
      '<label class="wide">Description<textarea name="description" rows="2" maxlength="2000" placeholder="Shown on the public paper"></textarea></label>' +
      '<div class="row"><button type="submit" class="primary">' + (p.published_quiz_id ? "Update published copy" : "Publish to everyone") + '</button><button type="button" data-close>Close</button></div></form></div>';
    slot.querySelector("[data-close]").addEventListener("click", () => { slot.innerHTML = ""; });
    const form = slot.querySelector("form");
    form.elements.course_id.addEventListener("change", async () => {
      const w = await weeksFor(form.elements.course_id.value);
      form.elements.week_id.innerHTML = '<option value="">No week</option>' + options(w.map((x) => ({ value: x.id, label: "Week " + x.week_number + (x.title ? " · " + x.title : "") })), "");
    });
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const f = form.elements, btn = form.querySelector(".primary"); btn.disabled = true;
      const num = (v) => (v === "" ? null : Number(v));
      try {
        await api("/manager/uploaded-papers/" + id + "/publish", "POST", { title: f.title.value.trim(), course_id: Number(f.course_id.value), week_id: num(f.week_id.value), section: f.section.value, year: num(f.year.value), time_limit_minutes: num(f.time_limit_minutes.value), description: f.description.value.trim() || null });
        toast("Published. Students can find it under Practice."); await load();
      } catch (err) { toast(err.message); btn.disabled = false; }
    });
  }
  document.querySelector(".rep-tabs").addEventListener("click", (e) => {
    const b = e.target.closest("[data-state]"); if (!b) return;
    st.state = b.dataset.state;
    document.querySelectorAll(".rep-tabs [data-state]").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
    load();
  });
  $("search").addEventListener("input", render);
  $("refresh").addEventListener("click", load);
  $("list").addEventListener("click", async (e) => {
    const art = e.target.closest("[data-id]"); if (!art) return;
    if (e.target.closest("[data-review]")) openPanel(art);
    else if (e.target.closest("[data-unpublish]")) {
      if (!confirm("Take the public copy offline and move this back to review?")) return;
      try { await api("/manager/uploaded-papers/" + art.dataset.id + "/unpublish", "POST"); toast("Unpublished"); await load(); } catch (err) { toast(err.message); }
    }
  });
  async function boot() {
    const gate = $("gate");
    if (!token()) return location.assign("/login");
    try {
      const me = await api("/auth/me"); const user = me.user || me;
      if (!user || user.role !== "manager") { gate.textContent = "Only manager accounts can review student uploads."; gate.classList.add("error"); return; }
      $("me").textContent = user.name || user.email || "";
      const c = await api("/manager/courses"); st.courses = Array.isArray(c) ? c : (c.courses || []);
    } catch (err) { gate.textContent = "Could not verify your account: " + err.message; gate.classList.add("error"); return; }
    gate.hidden = true; $("workspace").hidden = false; load();
  }
  boot();
})();
