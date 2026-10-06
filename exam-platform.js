/* Server-owned exam management and candidate room. No local exam state or answer keys. */
(function () {
  "use strict";

  let path = location.pathname.replace(/\/+$/, "") || "/";
  const inExamArea =
    path === "/exam" || path === "/exams" || path.startsWith("/exams/");
  const API = (
    (window.QLStorefront && window.QLStorefront.apiBase) ||
    "https://labapi.genziitian.in/public/api"
  ).replace(/\/+$/, "");
  const ROLE_LABEL = { manager: "Manager", student: "Your exams" };
  const TYPES = [
    "mcq_single",
    "mcq_multi",
    "true_false",
    "numerical",
    "short_answer",
    "comprehension",
  ];
  const app = {
    user: null,
    exams: [],
    exam: null,
    state: null,
    screen: "list",
    busy: false,
    error: "",
    notice: "",
    poll: null,
    ticker: null,
    serverOffset: 0,
    stateFetchedAt: 0,
    draftAnswers: {},
    revision: 0,
    answerEditVersion: 0,
    saveTimer: null,
    savePromise: null,
    importQuestions: null,
    papers: null,
    papersLoading: false,
    paperFilter: "",
    paperPick: "",
    selected: null,
    dirty: false,
    pending: {},
    saveError: "",
    epoch: 0,
    eventQueue: [],
    lastEventAt: 0,
  };
  const $ = (s, root = document) => root.querySelector(s);
  const esc = (v) =>
    String(v == null ? "" : v).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const token = () => {
    try {
      return localStorage.getItem("lab_token") || "";
    } catch (_) {
      return "";
    }
  };
  function desktopEligible() {
    const agent = navigator.userAgent || "";
    if (/Android|iPhone|iPad|iPod|Tablet|Kindle|Silk|Mobile/i.test(agent)) return false;
    if (navigator.userAgentData?.mobile) return false;
    if (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1) return false;
    return !window.matchMedia || window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  }
  function showDesktopOnly() {
    const reactRoot = document.getElementById("root");
    if (reactRoot) reactRoot.style.display = "none";
    let root = document.getElementById("ep-app");
    if (!root) { root = document.createElement("main"); root.id = "ep-app"; document.body.appendChild(root); }
    root.innerHTML = '<section class="ep-page ep-narrow"><div class="ep-card"><p class="ep-eyebrow">ONLINE EXAMS</p><h1>Use a laptop or desktop</h1><p>Online proctored exams are available in a desktop browser with a keyboard and mouse. Open this page on your laptop or desktop to manage or take an exam.</p><p>Your exam access and saved answers stay with your account.</p><a class="ep-link" href="/dashboard">Back to Quiz LAB</a></div></section>';
  }
  const isManager = () => app.user && app.user.role === "manager";
  const isAdmin = () => app.user && app.user.role === "admin";
  const contentHtml = (content) => {
    if (
      window.ExamRichContent &&
      typeof window.ExamRichContent.render === "function"
    )
      return window.ExamRichContent.render(content);
    if (Array.isArray(content)) return content.map(contentHtml).join("");
    if (content && typeof content === "object") {
      if (typeof content.text === "string")
        return esc(content.text).replace(/\n/g, "<br>");
      if (typeof content.value === "string")
        return esc(content.value).replace(/\n/g, "<br>");
      if (Array.isArray(content.blocks))
        return content.blocks.map(contentHtml).join("");
      return "";
    }
    return esc(content).replace(/\n/g, "<br>");
  };
  function typeset(root) {
    if (window.ExamRichContent && window.ExamRichContent.typeset)
      window.ExamRichContent.typeset(root);
  }
  async function request(url, options = {}) {
    const headers = {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(token() ? { Authorization: `Bearer ${token()}` } : {}),
      ...(options.headers || {}),
    };
    const response = await fetch(`${API}${url}`, {
      signal: AbortSignal.timeout(20000),
      ...options,
      headers,
      body:
        options.body && typeof options.body !== "string"
          ? JSON.stringify(options.body)
          : options.body,
    });
    let data = null;
    try {
      data = await response.json();
    } catch (_) {
      data = null;
    }
    if (response.status === 401) {
      if (inExamArea) location.assign("/login");
      throw new Error("Your session expired. Please sign in again.");
    }
    if (!response.ok) {
      const details =
        data &&
        ((data.errors && Object.values(data.errors).flat().join(" ")) ||
          data.message ||
          data.error);
      const error = new Error(
        typeof details === "string"
          ? details
          : details
            ? JSON.stringify(details)
            : `Request failed (${response.status})`,
      );
      error.status = response.status;
      throw error;
    }
    return data || {};
  }
  const examFrom = (d) =>
    d && (d.exam || (d.data && d.data.exam) || d.data || d);
  async function verify() {
    if (!token()) {
      try {
        sessionStorage.setItem("ep_return", location.pathname);
      } catch (_) {}
      location.assign("/login");
      return;
    }
    const d = await request("/auth/me");
    app.user = d.user || d;
    if (!app.user || !app.user.id || !app.user.role)
      throw new Error(
        "Could not verify your account. Sign out and sign in again.",
      );
    if (!["manager", "admin", "student"].includes(app.user.role))
      throw new Error("This account cannot access the exam platform.");
  }
  function notice(text, error = false) {
    app.notice = error ? "" : text;
    app.error = error ? text : "";
    render();
  }
  function setBusy(v) {
    app.busy = v;
    render();
  }
  function mount() {
    const reactRoot = document.getElementById("root");
    if (reactRoot) reactRoot.style.display = "none";
    let root = document.getElementById("ep-app");
    if (!root) {
      root = document.createElement("main");
      root.id = "ep-app";
      document.body.appendChild(root);
    }
    root.innerHTML = `<div class="ep-shell"><header class="ep-top"><a class="ep-brand" href="/exams"><span class="ep-mark">QL</span><span><b>Quiz LAB</b><small>Secure exam room</small></span></a><div class="ep-user"><span>${esc(app.user?.name || app.user?.email || "")}</span><a class="ep-link" href="/dashboard">Back to app</a><button class="ep-btn ep-btn-quiet" data-action="logout">Sign out</button></div></header><div id="ep-content"></div><div id="ep-toast" role="status" aria-live="polite"></div></div>`;
    root.addEventListener("click", onClick);
    root.addEventListener("input", onInput);
    root.addEventListener("change", onChange);
    root.addEventListener("submit", onSubmit);
  }
  function showEntry() {
    const current = document.getElementById("ep-role-entry");
    const onLogin = path === "/login";
    if (!desktopEligible() || !ROLE_LABEL[app.user?.role] || inExamArea || onLogin) {
      current?.remove();
      return;
    }
    if (current) return;
    const link = document.createElement("a");
    link.id = "ep-role-entry";
    link.href = "/exams";
    link.textContent = `${ROLE_LABEL[app.user.role]} • Online exams`;
    document.body.appendChild(link);
  }
  function rows(d) {
    return Array.isArray(d)
      ? d
      : Array.isArray(d.exams)
        ? d.exams
        : Array.isArray(d.data)
          ? d.data
          : [];
  }
  async function loadList() {
    clearTimeout(app.saveTimer);
    clearInterval(app.poll);
    clearInterval(app.ticker);
    app.epoch++;
    app.selected = null;
    app.setupDraft = null;
    app.pending = {};
    app.dirty = false;
    app.importQuestions = null;
    app.importText = "";
    const d = await request("/exam-platform/exams");
    app.exams = rows(d);
    app.nextPage = d.next_page;
    app.screen = "list";
    app.exam = null;
    app.state = null;
    render();
  }
  async function loadExam(id) {
    if (app.selected !== id) {
      app.setupDraft = null;
      app.auditEvents = null;
      clearTimeout(app.saveTimer);
      app.epoch++;
      app.pending = {};
      app.saveError = "";
      app.importQuestions = null;
      app.importText = "";
      app.state = null;
      app.draftAnswers = {};
      app.revision = 0;
      app.dirty = false;
      app.answerEditVersion = 0;
    }
    app.selected = id;
    const d = await request(`/exam-platform/exams/${encodeURIComponent(id)}`);
    app.exam = examFrom(d);
    app.screen = app.exam?.status === "draft" ? "edit" : "detail";
    render();
  }
  function applyState(d) {
    app.state = d;
    if (d.exam) app.exam = { ...app.exam, ...d.exam };
    app.stateFetchedAt = Date.now();
    app.draftAnswers = { ...(d.session?.answers || {}), ...app.pending };
    app.revision = Number(d.session?.revision || 0);
    if (!isManager() && d.session?.status === "submitted") {
      app.pending = {};
      app.dirty = false;
      app.screen = "result";
    }
  }
  async function loadState() {
    if (!app.exam) return;
    const epoch = app.epoch,
      id = app.exam.id;
    const d = await request(
      `/exam-platform/exams/${encodeURIComponent(id)}/state`,
    );
    if (epoch !== app.epoch) return;
    applyState(d);
    render();
    startPolling();
  }
  async function updateList(quiet = false) {
    try {
      const d = await request("/exam-platform/exams");
      app.exams = rows(d);
      app.nextPage = d.next_page;
      if (app.screen === "list") render();
    } catch (e) {
      if (!quiet) notice(e.message, true);
    }
  }
  function flash(text, error = false) {
    const toast = $("#ep-toast");
    if (!toast) return;
    toast.textContent = text;
    toast.className = error ? "show error" : "show";
    clearTimeout(flash.timer);
    flash.timer = setTimeout(() => {
      toast.className = "";
    }, 3600);
  }
  /* A manager who opens the Exam tab from the student view sees the list the way a student would. */
  const studentPreview = () =>
    isManager() && new URLSearchParams(location.search).get("preview") === "student";
  function listView() {
    const preview = studentPreview();
    const manager = isManager() && !preview;
    const list = preview ? app.exams.filter((e) => e.status && e.status !== "draft") : app.exams;
    return `<section class="ep-page"><div class="ep-heading"><div><p class="ep-eyebrow">${manager ? "EXAM MANAGEMENT" : "CANDIDATE PORTAL"}</p><h1>${manager ? "Online proctoring" : "Your exams"}</h1>${manager ? "" : `<p>Select an exam you are enrolled in to read its instructions and check its status.</p>`}</div>${manager ? '<button class="ep-btn ep-btn-primary" data-action="new">Create exam</button>' : ""}</div>${app.error ? `<div class="ep-alert error">${esc(app.error)}</div>` : ""}${app.notice ? `<div class="ep-alert">${esc(app.notice)}</div>` : ""}${preview ? '<div class="ep-alert">Student preview. This is what enrolled students see for your published exams. You are signed in as a manager, so exams cannot be taken from here. <a class="ep-link" href="/exams">Go to exam management</a></div>' : ""}<div class="ep-card"><div class="ep-card-head"><h2>${manager ? "Exams" : "Available exams"}</h2><button class="ep-btn ep-btn-quiet" data-action="refresh-list">Refresh</button></div>${list.length ? `<div class="ep-table-wrap"><table><thead><tr><th>Exam</th><th>Status</th><th>Schedule</th><th>Questions</th><th></th></tr></thead><tbody>${list.map((e) => `<tr><td><b>${esc(e.title)}</b><small>${esc(e.subject || "—")}</small></td><td><span class="ep-status ${esc(e.closed ? "ended" : e.status)}">${esc(e.closed ? "closed" : e.status || "draft")}</span></td><td>${esc(formatDate(e.scheduled_at))}${e.closes_at ? `<small>Ends ${esc(formatDate(e.closes_at))}</small>` : ""}</td><td>${Number(e.question_count ?? e.questions_count ?? e.questions?.length ?? 0)}</td><td><button class="ep-btn ep-btn-small" data-action="open" data-id="${esc(e.id)}" ${(e.closed && !manager) || preview ? "disabled" : ""}>${manager ? "Manage" : e.closed ? "Closed" : preview ? "Preview" : "Open"}</button></td></tr>`).join("")}</tbody></table></div>` : `<div class="ep-empty"><div class="ep-empty-icon">${manager ? "＋" : "◷"}</div><h3>${manager ? "No exams yet" : "No exams available"}</h3><p>${manager ? "Create a draft exam to begin setting up questions and enrollment." : preview ? "Students see exams here once you publish them and enrol their email." : "Ask your exam manager to enroll your account."}</p></div>`}${app.nextPage ? '<div class="ep-actions"><button class="ep-btn" data-action="more-exams">Load more exams</button></div>' : ""}</div></section>`;
  }
  function formatDate(v) {
    if (!v) return "—";
    const d = new Date(v);
    return Number.isNaN(d.valueOf()) ? esc(v) : d.toLocaleString();
  }
  /* Copy questions from an existing paper in the Quizzes section into this draft. */
  const PAPER_SECTIONS = {
    practice: "Practice",
    practice_graded: "Graded",
    quiz1: "Quiz 1",
    quiz2: "Quiz 2",
    endterm: "End Term",
    mock_test: "Mock",
  };
  function paperOptions() {
    const words = app.paperFilter.toLowerCase().split(/\s+/).filter(Boolean);
    const rows = (app.papers || []).filter((p) => {
      const text = `${p.title} ${p.course_name || ""} ${PAPER_SECTIONS[p.section] || ""}`.toLowerCase();
      return words.every((w) => text.includes(w));
    });
    return (
      `<option value="">${rows.length ? `Choose a paper (${rows.length})` : "No papers match"}</option>` +
      rows
        .slice(0, 300)
        .map(
          (p) =>
            `<option value="${esc(p.id)}" ${String(p.id) === String(app.paperPick) ? "selected" : ""}>${esc(p.course_name || "Course")} · ${esc(PAPER_SECTIONS[p.section] || p.section || "")} · ${esc(p.title)} (${Number(p.questions_count || 0)} q)</option>`,
        )
        .join("")
    );
  }
  function paperPicker() {
    if (!isManager()) return "";
    if (app.papers === null && !app.papersLoading) {
      app.papersLoading = true;
      request("/admin/quizzes")
        .then((d) => {
          app.papers = Array.isArray(d) ? d : rows(d).length ? rows(d) : d.quizzes || [];
        })
        .catch(() => {
          app.papers = [];
        })
        .finally(() => {
          app.papersLoading = false;
          if (app.screen === "edit") {
            const box = $("#ep-paper-picker");
            if (box) box.outerHTML = paperPicker();
          }
        });
    }
    const ready = Array.isArray(app.papers);
    return `<div class="ep-paper-picker" id="ep-paper-picker"><b>Or copy questions from an existing paper</b><p class="ep-muted">The questions are copied into this exam. The paper itself is not linked or changed.</p>${
      !ready
        ? '<p class="ep-muted">Loading papers…</p>'
        : !app.papers.length
          ? '<p class="ep-muted">No papers were found in the Quizzes section.</p>'
          : `<div class="ep-paper-row"><input type="search" id="ep-paper-filter" placeholder="Filter by course, type or title" value="${esc(app.paperFilter)}" autocomplete="off" aria-label="Filter papers" /><select id="ep-paper-select" aria-label="Paper to copy questions from">${paperOptions()}</select><button class="ep-btn" data-action="load-paper" ${app.paperPick ? "" : "disabled"}>Load questions</button></div>`
    }</div>`;
  }
  function paperText(value) {
    let text = String(value == null ? "" : value);
    if (/<\/?[a-z][\s\S]*>/i.test(text))
      text = text
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/(p|div|li|h[1-6])>/gi, "\n")
        .replace(/<[^>]+>/g, "")
        .replace(/&nbsp;/gi, " ")
        .replace(/&lt;/gi, "<")
        .replace(/&gt;/gi, ">")
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi, "'")
        .replace(/&amp;/gi, "&");
    return text.trim();
  }
  function paperImage(value) {
    const p = String(value || "").trim();
    if (!p || /[\s"'<>\\]/.test(p)) return "";
    const root = API.replace(/\/api$/i, "");
    let origin = root;
    try {
      origin = new URL(API).origin;
    } catch (_) {}
    if (/^https:\/\//i.test(p)) return p;
    if (/^[a-z][a-z0-9+.-]*:/i.test(p)) return "";
    if (p.startsWith("/storage/")) return root + p;
    if (p.startsWith("/question-images/")) return root + "/storage" + p;
    if (p.startsWith("question-images/")) return root + "/storage/" + p;
    if (p.startsWith("/")) return origin + p;
    return root + "/" + p;
  }
  function paperQuestion(q) {
    const types = {
      mcq: "mcq_single",
      multi_select: "mcq_multi",
      true_false: "true_false",
      numerical: "numerical",
      short_answer: "short_answer",
      comprehension: "comprehension",
    };
    const type = types[q.type] || q.type;
    const prompt = [];
    const stem = paperText(q.stem);
    if (stem) prompt.push({ kind: "text", value: stem });
    if (q.stem_code)
      prompt.push({ kind: "code", value: String(q.stem_code), language: q.stem_code_language || "text" });
    const table = q.stem_table;
    if (table && Array.isArray(table.headers) && table.headers.length && Array.isArray(table.rows))
      prompt.push({
        kind: "table",
        headers: table.headers.map((h) => String(h ?? "")),
        rows: table.rows.filter(Array.isArray).map((r) => r.map((c) => String(c ?? ""))),
        ...(table.caption ? { caption: String(table.caption) } : {}),
      });
    const image = paperImage(q.stem_image);
    if (image) prompt.push({ kind: "image", url: image, alt: "Question figure" });
    const out = { id: `q${q.id}`, type, prompt, marks: Number(q.marks) || 1, negative: 0 };
    if (["easy", "medium", "hard"].includes(q.difficulty)) out.difficulty = q.difficulty;
    const explanation = paperText(q.explanation);
    if (explanation) out.explanation = [{ kind: "text", value: explanation }];
    const options = q.question_options || q.questionOptions || [];
    if (type === "true_false") {
      const right = options.find((o) => o.is_correct);
      out.correct_answer = right ? /^true$/i.test(paperText(right.option_text)) : null;
    } else if (type === "mcq_single" || type === "mcq_multi") {
      out.options = options.map((o) =>
        o.option_type === "code"
          ? [{ kind: "code", value: String(o.option_text || ""), language: o.code_language || "text" }]
          : paperText(o.option_text),
      );
      const right = options.map((o, i) => (o.is_correct ? i : -1)).filter((i) => i >= 0);
      if (type === "mcq_multi") out.correct_answers = right;
      else out.correct_answer = right.length ? right[0] : null;
    } else if (type === "numerical") {
      out.numerical_answer = q.numerical_answer;
      if (q.numerical_tolerance != null && Number(q.numerical_tolerance) > 0)
        out.numerical_tolerance = Number(q.numerical_tolerance);
    } else if (type === "short_answer") {
      out.acceptable_answers = (q.short_answer_acceptables || q.shortAnswerAcceptables || [])
        .map((a) => String(a.acceptable_text ?? "").trim())
        .filter(Boolean);
      if (!out.acceptable_answers.length) out.acceptable_answers = null;
    }
    return out;
  }
  function formView() {
    const e = { ...app.exam, ...app.setupDraft };
    const qn = e.questions?.length || 0;
    return `<section class="ep-page"><div class="ep-back"><button class="ep-btn ep-btn-quiet" data-action="back">← Exams</button></div><div class="ep-heading"><div><p class="ep-eyebrow">DRAFT SETUP</p><h1>${e.id ? "Configure exam" : "Create an exam"}</h1><p>Save a draft, import and review questions, enroll candidates, then publish when ready.</p></div></div>${app.error ? `<div class="ep-alert error">${esc(app.error)}</div>` : ""}<form class="ep-card ep-form" data-form="exam"><div class="ep-grid"><label>Exam title<input required name="title" maxlength="180" value="${esc(e.title || "")}" placeholder="e.g. Statistics Midterm" /></label><label>Subject<input name="subject" maxlength="180" value="${esc(e.subject || "")}" placeholder="Statistics" /></label><label>Duration (minutes)<input required type="number" name="duration_minutes" min="1" max="600" value="${Number(e.duration_minutes || 60)}" /></label><label>Violation warning limit<input required type="number" name="max_warnings" min="1" max="100" value="${Number(e.max_warnings || 3)}" /></label><label>Scheduled start<input type="datetime-local" name="scheduled_at" value="${esc(toLocalInput(e.scheduled_at))}" /></label><label>Exam end (date and time)<input type="datetime-local" name="closes_at" value="${esc(toLocalInput(e.closes_at))}" /><span class="ep-muted">Optional. The exam closes at this time even if the duration has not run out.</span></label><label class="ep-span">Instructions<textarea name="instructions" rows="4" maxlength="10000" placeholder="Exam instructions and permitted materials">${esc(e.instructions || "")}</textarea></label></div><div class="ep-actions"><button class="ep-btn ep-btn-primary" type="submit" ${app.busy ? "disabled" : ""}>Save draft</button><span class="ep-muted">${qn} question${qn === 1 ? "" : "s"} imported</span></div></form><div class="ep-card"><div class="ep-card-head"><div><h2>Import questions</h2><p>Save your draft first, then upload or paste JSON. Math can be included in prompts, options, tables, and explanations. Import replaces the draft’s entire question set.</p></div><div class="ep-actions">${e.questions?.length ? '<button class="ep-btn ep-btn-quiet" data-action="edit-json">Edit imported JSON</button>' : ""}<button class="ep-btn ep-btn-quiet" data-action="download-template">Download JSON template</button></div></div><div class="ep-import-tools"><label class="ep-file">Choose JSON file<input type="file" accept="application/json,.json" data-import-file /></label><span class="ep-muted">or paste JSON</span></div>${paperPicker()}<textarea id="ep-import-json" class="ep-codearea" spellcheck="false" placeholder='{"questions":[{"id":"q1","type":"mcq_single","prompt":"Solve $x^2=4$","options":["$x=2$","$x=±2$"],"correct":1,"marks":2,"negative":0}]}'>${esc(app.importText || "")}</textarea><div class="ep-actions"><button class="ep-btn" data-action="preview-import">Preview JSON</button><button class="ep-btn ep-btn-primary" data-action="import" ${!e.id || !app.importQuestions ? "disabled" : ""}>Import all questions</button><span class="ep-muted">All-or-nothing: any invalid question prevents import.</span></div>${app.importQuestions ? `<div class="ep-preview"><h3>Preview · ${app.importQuestions.length} questions</h3>${app.importQuestions.map((q, i) => `<article class="ep-preview-q"><b>${i + 1}. ${esc(q.type)} · ${Number(q.marks || 0)} marks</b><div>${contentHtml(q.prompt)}</div>${(q.options || []).map((o, j) => `<div class="ep-preview-option">${String.fromCharCode(65 + j)}. ${contentHtml(o)}</div>`).join("")}</article>`).join("")}</div>` : ""}</div><div class="ep-card"><div class="ep-card-head"><div><h2>Candidate enrollment</h2><p>One email per line. Enrollment takes effect when saved.</p></div><button class="ep-btn ep-btn-primary" data-action="save-enrollments" ${!e.id ? "disabled" : ""}>Save enrollment</button></div><textarea class="ep-textarea" id="ep-enrollment-list" rows="7" placeholder="candidate@example.edu">${esc((e.enrollments || e.enrolled_emails || []).map((x) => (typeof x === "string" ? x : x.email)).join("\n"))}</textarea></div>${qn ? managerQuestions(e.questions) : ""}<div class="ep-card ep-publish-card"><div><h2>Publish this exam?</h2><p>Publishing makes this exam available to enrolled candidates. Start the exam from the manager controls at its scheduled time.</p></div><button class="ep-btn ep-btn-primary" data-action="publish" ${!e.id || !qn || app.busy ? "disabled" : ""}>Publish exam</button></div></section>`;
  }
  function toLocalInput(v) {
    if (!v) return "";
    const d = new Date(v);
    if (Number.isNaN(d.valueOf())) return "";
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000)
      .toISOString()
      .slice(0, 16);
  }
  function detailView() {
    const e = app.exam || {},
      state = app.state || {},
      manager = isManager();
    return `<section class="ep-page"><div class="ep-back"><button class="ep-btn ep-btn-quiet" data-action="back">← Exams</button></div><div class="ep-heading"><div><p class="ep-eyebrow">${manager ? "MANAGER CONSOLE" : "EXAM DETAILS"}</p><h1>${esc(e.title)}</h1><p>${esc(e.subject || "")}</p></div><span class="ep-status ${esc(e.status)}">${esc(e.status || "draft")}</span></div>${app.error ? `<div class="ep-alert error">${esc(app.error)}</div>` : ""}<div class="ep-detail-grid"><div class="ep-card"><h2>Exam setup</h2><dl class="ep-facts"><div><dt>Duration</dt><dd>${Number(e.duration_minutes || 0)} minutes</dd></div><div><dt>Scheduled start</dt><dd>${esc(formatDate(e.scheduled_at))}</dd></div><div><dt>Exam end</dt><dd>${esc(formatDate(e.closes_at))}</dd></div><div><dt>Questions</dt><dd>${Number(e.questions?.length || e.question_count || 0)}</dd></div><div><dt>Results</dt><dd>${e.results_published ? "Published" : "Not published"}</dd></div></dl><h3>Instructions</h3><p class="ep-instructions">${contentHtml(e.instructions || "No additional instructions.")}</p><div class="ep-actions">${manager ? `${e.status === "draft" ? '<button class="ep-btn" data-action="edit">Edit draft</button>' : ""}${e.status === "published" ? '<button class="ep-btn" data-action="edit-enrollments">Edit enrollment</button><button class="ep-btn ep-btn-primary" data-action="start">Start exam</button>' : ""}${["live", "paused"].includes(e.status) ? `<button class="ep-btn" data-action="${e.status === "live" ? "pause" : "resume"}">${e.status === "live" ? "Pause" : "Resume"}</button><button class="ep-btn ep-btn-danger" data-action="end">End exam</button><button class="ep-btn" data-action="extend">Add 5 minutes</button>` : ""}${e.status === "ended" && !e.results_published ? '<button class="ep-btn ep-btn-primary" data-action="publish-results">Publish results</button>' : ""}${e.status === "ended" ? '<button class="ep-btn" data-action="archive">Archive</button>' : ""}${e.results_published ? '<button class="ep-btn" data-action="export">Export results CSV</button>' : ""}<button class="ep-btn ep-btn-quiet" data-action="audit">Audit log</button><button class="ep-btn ep-btn-quiet" data-action="copy-link">Copy candidate link</button>` : `<button class="ep-btn ep-btn-primary" data-action="join" ${e.status === "live" ? "" : "disabled"}>Review rules and join</button>`}</div></div>${manager ? `<div class="ep-card"><div class="ep-card-head"><h2>Live monitoring</h2><span class="ep-live-dot">${Array.isArray(state.sessions) ? state.sessions.length : Object.keys(state.sessions || {}).length} candidates</span></div><div class="ep-actions"><button class="ep-btn ep-btn-quiet" data-action="refresh-state">Refresh now</button><button class="ep-btn" data-action="messages">Messages</button></div><div id="ep-sessions">${sessionTable(state.sessions || [])}</div><div id="ep-audit">${app.auditEvents ? auditHtml() : ""}</div></div>` : candidateSummary(state)}</div>${manager ? managerQuestions(e.questions || []) : ""}</section>`;
  }
  function candidateSummary(s) {
    const sess = s.session || {};
    return `<div class="ep-card"><h2>Your session</h2><p>Status: <b>${esc(sess.status || "Not joined")}</b></p>${sess.score != null && s.exam?.results_published ? `<p>Score: <b>${Number(sess.score)} / ${Number(sess.total_marks || 0)}</b></p>` : ""}${sess.status === "submitted" ? "<p>Your submission is recorded.</p>" : ""}</div>`;
  }
  function answerHtml(q, value) {
    if (
      value == null ||
      value === "" ||
      (Array.isArray(value) && !value.length)
    )
      return '<span class="ep-muted">No answer</span>';
    if (q.type === "mcq_single")
      return contentHtml(q.options?.[Number(value)] || "—");
    if (q.type === "mcq_multi")
      return (Array.isArray(value) ? value : [])
        .map(
          (v) =>
            `<div>${String.fromCharCode(65 + Number(v))}. ${contentHtml(q.options?.[Number(v)] || "—")}</div>`,
        )
        .join("");
    return contentHtml(
      Array.isArray(value) ? value.join(" · ") : String(value),
    );
  }
  function resultView() {
    const e = app.exam || {},
      sess = app.state?.session || {},
      published = !!e.results_published;
    return `<section class="ep-page"><div class="ep-back"><button class="ep-btn ep-btn-quiet" data-action="back">← Exams</button></div><div class="ep-card ep-result-card"><p class="ep-eyebrow">SUBMISSION RECEIVED</p><h1>${esc(e.title)}</h1><p>Your submission was recorded at ${esc(formatDate(sess.submitted_at))}.</p>${published && sess.score != null ? `<div class="ep-result-score"><b>${Number(sess.score)}</b><span>/ ${Number(sess.total_marks || 0)} marks</span></div>` : '<div class="ep-alert">Your score and answer review will appear here after the exam manager publishes results.</div>'}</div>${published ? `<div class="ep-card"><h2>Answer review</h2>${(e.questions || []).map((q, i) => `<article class="ep-preview-q"><b>${i + 1}. ${esc(q.type)} · ${Number(q.marks || 0)} marks</b><div>${contentHtml(q.prompt)}</div>${q.type === "comprehension" ? "" : `<p class="ep-muted">Your answer</p><div>${answerHtml(q, sess.answers?.[q.id])}</div><p class="ep-muted">Accepted answer</p><div>${answerHtml(q, q.correct_answer ?? q.correct_answers ?? q.numerical_answer ?? q.acceptable_answers)}</div>`}${q.explanation ? `<div>${contentHtml(q.explanation)}</div>` : ""}</article>`).join("")}</div>` : ""}</section>`;
  }
  function sessionTable(sessions) {
    const list = Array.isArray(sessions)
      ? sessions
      : Object.values(sessions || {});
    return list.length
      ? `<div class="ep-table-wrap"><table><thead><tr><th>Candidate</th><th>Status</th><th>Warnings</th><th>Answered</th><th>Last activity</th><th></th></tr></thead><tbody>${list.map((s) => `<tr><td><b>${esc(s.name || s.email || s.user_id)}</b><small>${esc(s.email || "")}</small></td><td><span class="ep-status ${esc(s.status)}">${esc(s.status)}</span></td><td>${Number(s.warnings || 0)}</td><td>${Number(s.answered_count || Object.keys(s.answers || {}).length || 0)}</td><td>${esc(formatDate(s.updated_at || s.last_active))}</td><td>${["in_exam", "locked"].includes(s.status) ? `<button class="ep-btn ep-btn-small" data-action="${s.status === "locked" ? "unlock" : "lock"}" data-user="${esc(s.user_id)}">${s.status === "locked" ? "Unlock" : "Lock"}</button>` : ""}</td></tr>`).join("")}</tbody></table></div>`
      : '<div class="ep-empty compact"><p>No candidate sessions yet.</p></div>';
  }
  function managerQuestions(qs) {
    return `<div class="ep-card"><h2>Questions · ${qs.length}</h2>${qs.length ? qs.map((q, i) => `<article class="ep-preview-q"><b>${i + 1}. ${esc(q.type)} · ${Number(q.marks || 0)} marks · ${Number(q.negative || 0)} penalty for a wrong answer</b><div>${contentHtml(q.prompt)}</div>${(q.options || []).map((o, j) => `<div class="ep-preview-option">${String.fromCharCode(65 + j)}. ${contentHtml(o)}</div>`).join("")}${q.type === "comprehension" ? "" : `<p class="ep-muted">Accepted answer</p><div>${answerHtml(q, q.correct_answer ?? q.correct_answers ?? q.numerical_answer ?? q.acceptable_answers)}</div>`}${q.explanation ? `<div>${contentHtml(q.explanation)}</div>` : ""}</article>`).join("") : '<p class="ep-muted">No questions imported.</p>'}</div>`;
  }
  function rulesView() {
    const e = app.exam || {};
    return `<section class="ep-page ep-narrow"><div class="ep-card"><p class="ep-eyebrow">BEFORE YOU BEGIN</p><h1>${esc(e.title)}</h1><p class="ep-instructions">${contentHtml(e.instructions || "Read each question carefully and submit before time expires.")}</p><p>The timer is shared by all candidates. Joining late does not add time. ${Number(e.max_warnings || 3)} warnings lock your session until the manager reviews it.</p><div class="ep-alert">This platform records limited browser focus and fullscreen events. It does not verify identity or monitor video/audio.</div><label class="ep-check"><input type="checkbox" id="ep-rules-check" /> I have read and agree to follow the exam instructions.</label><div class="ep-actions"><button class="ep-btn" data-action="back">Cancel</button><button class="ep-btn ep-btn-primary" data-action="join-confirm">Accept and continue</button></div></div></section>`;
  }
  function examRoom() {
    const e = app.exam || {},
      s = app.state || {},
      sess = s.session || {};
    const secs =
      s.remaining_seconds == null
        ? null
        : Math.max(
            0,
            Number(s.remaining_seconds) -
              (e.status === "paused"
                ? 0
                : Math.floor((Date.now() - app.stateFetchedAt) / 1000)),
          );
    return `<section class="ep-room"><header class="ep-room-head"><div><p class="ep-eyebrow">EXAM IN PROGRESS</p><h1>${esc(e.title)}</h1></div><div class="ep-room-meta"><span class="ep-status ${esc(e.status)}">${esc(e.status)}</span><span>Warnings: ${Number(sess.warnings || 0)}</span><button class="ep-btn ep-btn-quiet" data-action="fullscreen">Fullscreen</button><strong id="ep-countdown">${secs == null ? "—" : formatClock(secs)}</strong><button class="ep-btn ep-btn-quiet" data-action="messages">Messages</button></div></header>${e.status === "paused" ? '<div class="ep-alert">The manager has paused this exam. Answers remain saved. You can continue when it resumes.</div>' : ""}${sess.status === "locked" ? '<div class="ep-alert error">Your session is locked. Contact the exam manager for help.</div>' : ""}<div class="ep-questions">${(e.questions || []).map((q, i) => questionCard(q, i)).join("")}</div><div class="ep-submit-bar"><span class="ep-save-state" id="ep-save-state">${esc(app.saveError || (app.dirty ? "Unsaved changes…" : "Answers saved on server"))}</span><button class="ep-btn" data-action="retry-save">Save now</button><button class="ep-btn ep-btn-primary" data-action="submit-exam" ${e.status !== "live" || sess.status !== "in_exam" ? "disabled" : ""}>Submit exam</button></div></section>`;
  }
  function questionCard(q, i) {
    const val = app.draftAnswers[q.id];
    const locked =
      !["live"].includes(app.exam.status) ||
      ["locked", "submitted"].includes(app.state?.session?.status);
    let input = "";
    if (["mcq_single", "true_false"].includes(q.type))
      input = (q.options || (q.type === "true_false" ? ["True", "False"] : []))
        .map((o, j) => {
          const ans = q.type === "true_false" ? j === 0 : j;
          return `<label class="ep-answer"><input type="radio" name="answer-${esc(q.id)}" data-answer="${esc(q.id)}" value="${q.type === "true_false" ? String(ans) : j}" ${String(val) === String(ans) ? "checked" : ""} ${locked ? "disabled" : ""}/><span>${contentHtml(o)}</span></label>`;
        })
        .join("");
    else if (q.type === "mcq_multi")
      input = (q.options || [])
        .map(
          (o, j) =>
            `<label class="ep-answer"><input type="checkbox" data-answer-multi="${esc(q.id)}" value="${j}" ${Array.isArray(val) && val.map(String).includes(String(j)) ? "checked" : ""} ${locked ? "disabled" : ""}/><span>${contentHtml(o)}</span></label>`,
        )
        .join("");
    else if (q.type === "comprehension")
      input =
        '<p class="ep-muted">This reading passage is provided for the questions that follow.</p>';
    else
      input = `<label class="ep-answer ep-answer-text"><span>${q.type === "numerical" ? "Your answer" : "Your response"}</span><textarea data-answer-text="${esc(q.id)}" rows="2" maxlength="2000" ${locked ? "disabled" : ""}>${esc(val ?? "")}</textarea></label>`;
    return `<article class="ep-question"><header><span>Question ${i + 1}</span><span>${Number(q.marks || 0)} marks</span></header><div class="ep-question-prompt">${contentHtml(q.prompt)}</div>${input}${q.type !== "comprehension" ? `<button class="ep-btn ep-btn-quiet" data-action="clear-answer" data-id="${esc(q.id)}" ${locked ? "disabled" : ""}>Clear answer</button>` : ""}</article>`;
  }
  function formatClock(s) {
    s = Math.max(0, Math.floor(s));
    return `${String(Math.floor(s / 3600)).padStart(2, "0")}:${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  }
  function render() {
    const root = $("#ep-content");
    if (!root) return;
    const focused = document.activeElement;
    const focusSelector = focused?.dataset?.answerText
      ? `[data-answer-text="${CSS.escape(focused.dataset.answerText)}"]`
      : null;
    const selection = focusSelector
      ? [focused.selectionStart, focused.selectionEnd]
      : null;
    root.innerHTML =
      app.screen === "list"
        ? listView()
        : app.screen === "edit"
          ? formView()
          : app.screen === "detail"
            ? detailView()
            : app.screen === "rules"
              ? rulesView()
              : app.screen === "room"
                ? examRoom()
                : app.screen === "result"
                  ? resultView()
                  : '<section class="ep-page"><div class="ep-card"><p>Loading exam…</p></div></section>';
    typeset(root);
    if (focusSelector) {
      const input = $(focusSelector);
      if (input && !input.disabled) {
        input.focus({ preventScroll: true });
        if (selection[0] != null) input.setSelectionRange(...selection);
      }
    }
    const toast = $("#ep-toast");
    if (toast && (app.notice || app.error))
      flash(app.error || app.notice, !!app.error);
  }
  function formData(form) {
    const d = Object.fromEntries(new FormData(form).entries());
    d.duration_minutes = Number(d.duration_minutes);
    d.max_warnings = Number(d.max_warnings);
    d.scheduled_at = d.scheduled_at
      ? new Date(d.scheduled_at).toISOString()
      : null;
    d.closes_at = d.closes_at ? new Date(d.closes_at).toISOString() : null;
    if (d.closes_at && d.scheduled_at && d.closes_at <= d.scheduled_at)
      throw new Error("The exam end must be after the scheduled start.");
    return d;
  }
  function normalizeQuestion(q, i) {
    if (!q || typeof q !== "object" || Array.isArray(q))
      throw new Error(`Question ${i + 1} must be an object.`);
    const aliases = {
      mcq: "mcq_single",
      multi_select: "mcq_multi",
      single_choice: "mcq_single",
      multiple_choice: "mcq_multi",
      multi_choice: "mcq_multi",
      boolean: "true_false",
      numeric: "numerical",
      free_text: "short_answer",
      passage: "comprehension",
    };
    q.type = aliases[q.type] || q.type;
    if (q.prompt == null) {
      q.prompt = q.passage ?? q.stem;
      if (q.stem_code || q.stem_table) {
        q.prompt = [
          ...(q.prompt ? [{ kind: "text", value: q.prompt }] : []),
          ...(q.stem_code
            ? [
                {
                  kind: "code",
                  value: q.stem_code,
                  language: q.stem_code_language || "text",
                },
              ]
            : []),
          ...(q.stem_table ? [{ kind: "table", ...q.stem_table }] : []),
        ];
      }
    }
    if (!TYPES.includes(q.type))
      throw new Error(`Question ${i + 1} has unsupported type “${q.type}”.`);
    if (
      q.prompt == null ||
      (typeof q.prompt === "string" && !q.prompt.trim()) ||
      (Array.isArray(q.prompt) && !q.prompt.length)
    )
      throw new Error(`Question ${i + 1} needs a prompt.`);
    q.id = String(q.id || `q${i + 1}`);
    q.marks = q.type === "comprehension" ? 0 : Number(q.marks ?? 1);
    q.negative = Number(q.negative ?? q.negative_marks ?? 0);
    if (
      !Number.isFinite(q.marks) ||
      (q.type !== "comprehension" && q.marks <= 0)
    )
      throw new Error(`Question ${i + 1} marks must be greater than zero.`);
    if (!Number.isFinite(q.negative) || q.negative < 0)
      throw new Error(`Question ${i + 1} negative marks cannot be below zero.`);
    if (["mcq_single", "mcq_multi", "true_false"].includes(q.type)) {
      if (q.type === "true_false" && !q.options) q.options = ["True", "False"];
      if (
        !Array.isArray(q.options) ||
        q.options.length < 2 ||
        q.options.some((x) => x == null || x === "")
      )
        throw new Error(
          `Question ${i + 1} needs at least two non-empty options.`,
        );
      const raw = q.correct_answer ?? q.correct_answers ?? q.correct;
      if (raw == null)
        throw new Error(`Question ${i + 1} needs an answer key.`);
      if (q.type === "true_false") {
        const v = Array.isArray(raw) ? raw[0] : raw;
        if (typeof v === "boolean") q.correct_answer = v;
        else if (/^(true|false)$/i.test(String(v)))
          q.correct_answer = String(v).toLowerCase() === "true";
        else if (Number.isInteger(Number(v)) && [0, 1].includes(Number(v)))
          q.correct_answer = Number(v) === 0;
        else
          throw new Error(
            `Question ${i + 1} true/false answer must be true or false.`,
          );
      } else {
        const answers = Array.isArray(raw) ? raw : [raw];
        for (const a of answers)
          if (
            !Number.isInteger(Number(a)) ||
            Number(a) < 0 ||
            Number(a) >= q.options.length
          )
            throw new Error(
              `Question ${i + 1} answer key must use option indexes (0–${q.options.length - 1}).`,
            );
        if (q.type === "mcq_multi") q.correct_answers = answers.map(Number);
        else q.correct_answer = Number(answers[0]);
      }
      delete q.correct;
    } else if (q.type === "numerical") {
      const raw = q.numerical_answer ?? q.correct_answer ?? q.correct;
      if (raw == null || raw === "" || !Number.isFinite(Number(raw)))
        throw new Error(`Question ${i + 1} needs a numeric answer.`);
      q.numerical_answer = Number(raw);
      delete q.correct;
      delete q.correct_answer;
    } else if (q.type === "short_answer") {
      const raw = q.acceptable_answers ?? q.correct_answer ?? q.correct;
      if (raw == null || raw === "")
        throw new Error(
          `Question ${i + 1} needs at least one acceptable answer.`,
        );
      q.acceptable_answers = Array.isArray(raw)
        ? raw.map(String)
        : [String(raw)];
      delete q.correct;
      delete q.correct_answer;
    } else {
      delete q.correct;
      delete q.correct_answer;
      delete q.correct_answers;
    }
    return q;
  }
  function parseImport(raw) {
    if (new Blob([raw]).size > 5 * 1024 * 1024)
      throw new Error("Import must be smaller than 5 MB.");
    let data = JSON.parse(raw);
    data = data.example_payload || data;
    let questions = Array.isArray(data) ? data : data.questions;
    if (
      !Array.isArray(questions) &&
      data.quiz &&
      Array.isArray(data.quiz.questions)
    )
      questions = data.quiz.questions;
    if (
      !Array.isArray(questions) ||
      !questions.length ||
      questions.length > 500
    )
      throw new Error("JSON must contain between 1 and 500 questions.");
    const ids = new Set();
    const normalized = questions.map(normalizeQuestion);
    normalized.forEach((q, i) => {
      if (ids.has(q.id))
        throw new Error(`Duplicate question id “${q.id}” (question ${i + 1}).`);
      ids.add(q.id);
    });
    return normalized;
  }
  function startPolling() {
    clearInterval(app.poll);
    clearInterval(app.ticker);
    if (
      app.exam &&
      ["room", "detail", "rules", "result"].includes(app.screen)
    ) {
      app.poll = setInterval(
        () =>
          pollState().catch((e) =>
            flash(`Connection lost: ${e.message}`, true),
          ),
        6000,
      );
    }
    if (app.screen === "room")
      app.ticker = setInterval(() => {
        const node = $("#ep-countdown");
        if (!node || app.state?.remaining_seconds == null) return;
        const elapsed =
          app.exam.status === "paused"
            ? 0
            : Math.floor((Date.now() - app.stateFetchedAt) / 1000);
        node.textContent = formatClock(
          Number(app.state.remaining_seconds) - elapsed,
        );
      }, 1000);
  }
  async function pollState() {
    if (!app.exam || app.polling) return;
    app.polling = true;
    const epoch = app.epoch,
      id = app.exam.id;
    try {
      const before = [
        app.exam.status,
        app.state?.session?.status,
        app.exam.results_published,
        app.state?.session?.warnings,
      ].join("|");
      const d = await request(
        `/exam-platform/exams/${encodeURIComponent(id)}/state?compact=1`,
      );
      if (epoch !== app.epoch) return;
      const after = [
        d.exam.status,
        d.session?.status,
        d.exam.results_published,
        d.session?.warnings,
      ].join("|");
      // Fetch full content only when session/results change. Ordinary polls never replace typing.
      if (before !== after) {
        await loadState();
        return;
      }
      app.state = {
        ...app.state,
        ...d,
        session: d.session ? { ...app.state?.session, ...d.session } : null,
      };
      app.exam = { ...app.exam, ...d.exam };
      app.stateFetchedAt = Date.now();
      if (isManager() && app.screen === "detail") {
        const sessions = $("#ep-sessions");
        if (sessions) sessions.innerHTML = sessionTable(d.sessions || []);
        const count = $(".ep-live-dot");
        if (count)
          count.textContent = `${(d.sessions || []).length} candidates`;
      }
      if (app.dirty && !app.savePromise && app.exam.status === "live")
        saveAnswers().catch(() => {});
      flushEvents();
    } finally {
      app.polling = false;
    }
  }
  function changedAnswer(id, value) {
    app.draftAnswers[id] = value;
    app.pending[id] = value;
    app.dirty = true;
    app.saveError = "";
    const status = $("#ep-save-state");
    if (status) status.textContent = "Unsaved changes…";
    clearTimeout(app.saveTimer);
    app.saveTimer = setTimeout(() => saveAnswers().catch(() => {}), 700);
  }
  function wireAnswers(source) {
    const out = { ...source };
    for (const q of app.exam?.questions || [])
      if (q.id in out) {
        if (
          out[q.id] === "" ||
          out[q.id] == null ||
          (Array.isArray(out[q.id]) && !out[q.id].length)
        ) {
          out[q.id] = null;
          continue;
        }
        if (q.type === "numerical") {
          if (!String(out[q.id]).trim() || !Number.isFinite(Number(out[q.id])))
            throw new Error("Enter a finite number for each numerical answer.");
          out[q.id] = Number(out[q.id]);
        }
      }
    return out;
  }
  async function saveAnswers() {
    if (app.savePromise) {
      await app.savePromise;
      if (app.dirty) return saveAnswers();
      return;
    }
    if (!app.dirty) return;
    if (app.exam?.status !== "live" || app.state?.session?.status !== "in_exam")
      throw new Error("Saving will resume when your exam session is active.");
    const epoch = app.epoch,
      id = app.exam.id;
    app.savePromise = (async () => {
      for (let attempt = 0; attempt < 3; attempt++) {
        const pending = { ...app.pending },
          answers = wireAnswers(pending),
          revision = app.revision;
        try {
          const d = await request(
            `/exam-platform/exams/${encodeURIComponent(id)}/answers`,
            { method: "PATCH", body: { answers, revision } },
          );
          if (epoch !== app.epoch) return;
          for (const key of Object.keys(pending))
            if (
              JSON.stringify(app.pending[key]) === JSON.stringify(pending[key])
            )
              delete app.pending[key];
          app.dirty = Object.keys(app.pending).length > 0;
          app.saveError = "";
          app.revision = d.session.revision;
          app.state.session = { ...app.state.session, ...d.session };
          app.draftAnswers = { ...d.session.answers, ...app.pending };
          const status = $("#ep-save-state");
          if (status)
            status.textContent = app.dirty
              ? "Unsaved changes…"
              : "Answers saved on server";
          return;
        } catch (e) {
          if (e.status !== 409 || attempt === 2) throw e;
          const d = await request(
            `/exam-platform/exams/${encodeURIComponent(id)}/state`,
          );
          if (epoch !== app.epoch) return;
          applyState(d);
          render();
          if (d.exam.status !== "live" || d.session?.status !== "in_exam") {
            render();
            throw e;
          }
        }
      }
    })();
    try {
      await app.savePromise;
    } catch (e) {
      if (epoch === app.epoch) {
        app.saveError = `Not saved: ${e.message}`;
        const status = $("#ep-save-state");
        if (status) status.textContent = app.saveError;
      }
      throw e;
    } finally {
      app.savePromise = null;
      if (epoch === app.epoch && app.dirty) {
        clearTimeout(app.saveTimer);
        app.saveTimer = setTimeout(
          () => saveAnswers().catch(() => {}),
          app.saveError ? 5000 : 0,
        );
      }
    }
  }
  async function event(type) {
    if (
      app.screen !== "room" ||
      app.exam?.status !== "live" ||
      app.state?.session?.status !== "in_exam" ||
      Date.now() - app.lastEventAt < 1200
    )
      return;
    app.lastEventAt = Date.now();
    if (app.eventQueue.length < 100)
      app.eventQueue.push({
        examId: app.exam.id,
        id: crypto.randomUUID(),
        type,
      });
    await flushEvents();
  }
  async function flushEvents() {
    if (app.flushingEvents) return;
    app.flushingEvents = true;
    try {
      while (app.eventQueue.length) {
        const item = app.eventQueue[0];
        try {
          const d = await request(
            `/exam-platform/exams/${encodeURIComponent(item.examId)}/events`,
            { method: "POST", body: { id: item.id, type: item.type } },
          );
          app.eventQueue.shift();
          if (app.exam?.id === item.examId) {
            app.state.session = { ...app.state.session, ...d.session };
            render();
            flash(`Browser warning recorded (${d.session.warnings}).`, true);
          }
        } catch (e) {
          if ([403, 404, 409, 422].includes(e.status)) app.eventQueue.shift();
          else break;
        }
      }
    } finally {
      app.flushingEvents = false;
    }
  }
  async function fullscreen() {
    try {
      if (
        !document.fullscreenElement &&
        document.documentElement.requestFullscreen
      )
        await document.documentElement.requestFullscreen();
    } catch (_) {
      flash(
        "Fullscreen is unavailable in this browser. Browser focus events are still recorded.",
      );
    }
  }
  function rememberSetup() {
    const form = $('form[data-form="exam"]');
    if (form) app.setupDraft = formData(form);
    const roster = $("#ep-enrollment-list");
    if (roster)
      app.exam = {
        ...app.exam,
        enrollments: roster.value
          .split(/\n/)
          .filter(Boolean)
          .map((email) => ({ email })),
      };
  }
  async function onClick(ev) {
    const b = ev.target.closest("[data-action]");
    if (!b) return;
    ev.preventDefault();
    if (b.disabled) return;
    const action = b.dataset.action;
    b.disabled = true;
    try {
      if (action === "logout") {
        if (app.dirty) await saveAnswers();
        await request("/auth/logout", { method: "POST" });
        localStorage.removeItem("lab_token");
        localStorage.removeItem("lab_user");
        location.assign("/login");
        return;
      }
      if (action === "back") {
        if (app.dirty) await saveAnswers();
        clearInterval(app.poll);
        await loadList();
        return;
      }
      if (action === "refresh-list") {
        await updateList();
        return;
      }
      if (action === "open") {
        await loadExam(b.dataset.id);
        if (app.exam.status !== "draft") {
          await loadState();
          if (
            !isManager() &&
            ["in_exam", "locked"].includes(app.state.session?.status)
          )
            app.screen = "room";
          render();
          startPolling();
        }
        return;
      }
      if (action === "copy-link") {
        await navigator.clipboard.writeText(
          `${location.origin}/exams/${app.exam.id}`,
        );
        flash("Candidate link copied. Only enrolled accounts can join.");
        return;
      }
      if (action === "more-exams") {
        const d = await request(`/exam-platform/exams?page=${app.nextPage}`);
        app.exams.push(...rows(d));
        app.nextPage = d.next_page;
        render();
        return;
      }
      if (action === "fullscreen") {
        await fullscreen();
        return;
      }
      if (action === "clear-answer") {
        changedAnswer(b.dataset.id, null);
        render();
        return;
      }
      if (action === "retry-save") {
        await saveAnswers();
        return;
      }
      if (action === "edit-enrollments") {
        const dialog = document.createElement("dialog");
        dialog.className = "ep-dialog";
        dialog.innerHTML = `<h2>Candidate enrollment</h2><p>One email per line. Replace the full roster before starting.</p><textarea rows="10">${esc((app.exam.enrollments || []).map((x) => x.email).join("\n"))}</textarea><div class="ep-actions"><button class="ep-btn" data-close>Cancel</button><button class="ep-btn ep-btn-primary" data-save>Save enrollment</button></div><p role="alert"></p>`;
        document.body.append(dialog);
        dialog.showModal();
        dialog.onclose = () => dialog.remove();
        dialog.querySelector("[data-close]").onclick = () => dialog.close();
        dialog.querySelector("[data-save]").onclick = async () => {
          try {
            const emails = dialog
              .querySelector("textarea")
              .value.split(/[\n,;]/)
              .map((x) => x.trim())
              .filter(Boolean);
            await request(`/exam-platform/exams/${app.exam.id}/enrollments`, {
              method: "PUT",
              body: { emails },
            });
            dialog.close();
            await loadExam(app.exam.id);
            startPolling();
          } catch (e) {
            dialog.querySelector("[role=alert]").textContent = e.message;
          }
        };
        return;
      }
      if (action === "new") {
        app.exam = null;
        app.importQuestions = null;
        app.importText = "";
        app.screen = "edit";
        render();
        return;
      }
      if (action === "edit") {
        app.screen = "edit";
        app.importQuestions = null;
        render();
        return;
      }
      if (action === "edit-json") {
        rememberSetup();
        app.importText = JSON.stringify(
          { questions: app.exam.questions },
          null,
          2,
        );
        app.importQuestions = null;
        render();
        $("#ep-import-json").focus();
        return;
      }
      if (action === "download-template") {
        const a = document.createElement("a");
        a.href = "/templates/proctored-exam-template.json";
        a.download = "proctored-exam-template.json";
        a.click();
        return;
      }
      if (action === "load-paper") {
        rememberSetup();
        const paper = (app.papers || []).find((p) => String(p.id) === String(app.paperPick));
        if (!paper) return;
        const data = await request(`/admin/quizzes/${encodeURIComponent(paper.id)}/questions`);
        const list = Array.isArray(data) ? data : data.questions || [];
        if (!list.length) throw new Error("That paper has no questions to copy.");
        app.importText = JSON.stringify({ questions: list.map(paperQuestion) }, null, 2);
        app.importQuestions = null;
        render();
        app.importQuestions = parseImport(app.importText);
        render();
        flash(`Copied ${list.length} questions from “${paper.title}”. Review the preview, then press Import all questions.`);
        return;
      }
      if (action === "preview-import") {
        rememberSetup();
        app.importText = $("#ep-import-json")?.value || "";
        app.importQuestions = parseImport(app.importText);
        render();
        return;
      }
      if (action === "import") {
        rememberSetup();
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/import`,
          { method: "POST", body: { questions: app.importQuestions } },
        );
        app.importQuestions = null;
        await loadExam(app.exam.id);
        app.screen = "edit";
        flash("Questions imported.");
        return;
      }
      if (action === "save-enrollments") {
        rememberSetup();
        const emails = ($("#ep-enrollment-list")?.value || "")
          .split(/[\n,;]/)
          .map((x) => x.trim().toLowerCase())
          .filter(Boolean);
        const invalid = emails.find((x) => !/^\S+@\S+\.\S+$/.test(x));
        if (invalid) throw new Error(`Invalid email address: ${invalid}`);
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/enrollments`,
          { method: "PUT", body: { emails: [...new Set(emails)] } },
        );
        await loadExam(app.exam.id);
        app.screen = "edit";
        flash("Candidate enrollment saved.");
        return;
      }
      if (action === "publish") {
        const form = $("form[data-form=exam]");
        if (form) {
          const payload = formData(form);
          app.exam = examFrom(
            await request(`/exam-platform/exams/${app.exam.id}`, {
              method: "PATCH",
              body: payload,
            }),
          );
        }
        if (
          !confirm(
            "Publish this exam to enrolled candidates? You can no longer edit its questions after publishing.",
          )
        )
          return;
        await act("publish");
        await loadExam(app.exam.id);
        flash("Exam published.");
        return;
      }
      if (
        action === "start" ||
        action === "pause" ||
        action === "resume" ||
        action === "end" ||
        action === "publish-results"
      ) {
        const actionName =
          action === "publish-results" ? "publish_results" : action;
        const prompts = {
          start: "Start this exam for enrolled candidates?",
          pause: "Pause the live exam?",
          resume: "Resume the live exam?",
          end: "End this exam now? Candidates will no longer be able to continue.",
          publish_results: "Publish results and answer review to candidates?",
        };
        if (!confirm(prompts[actionName])) return;
        await act(actionName);
        await loadExam(app.exam.id);
        await loadState();
        flash("Exam updated.");
        return;
      }
      if (action === "extend") {
        await act("extend", { minutes: 5 });
        await loadState();
        flash("Exam time extended by 5 minutes.");
        return;
      }
      if (action === "archive") {
        if (
          !confirm(
            "Archive this ended exam? It will be removed from the active exam list.",
          )
        )
          return;
        await act("archive");
        await loadList();
        flash("Exam archived.");
        return;
      }
      if (action === "lock" || action === "unlock") {
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/sessions/${encodeURIComponent(b.dataset.user)}/action`,
          { method: "POST", body: { action } },
        );
        await loadState();
        return;
      }
      if (action === "refresh-state") {
        await loadState();
        return;
      }
      if (action === "join") {
        app.screen = "rules";
        render();
        return;
      }
      if (action === "join-confirm") {
        await fullscreen();
        if (!$("#ep-rules-check")?.checked)
          throw new Error("Please accept the exam rules before continuing.");
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/join`,
          { method: "POST", body: { acceptedRules: true } },
        );
        await loadState();
        app.draftAnswers = { ...(app.state.session?.answers || {}) };
        app.screen = "room";
        render();
        startPolling();
        return;
      }
      if (action === "submit-exam") {
        await saveAnswers();
        if (app.dirty)
          throw new Error(
            "Your answers are not saved yet. Please wait for the save confirmation.",
          );
        const unanswered = (app.exam.questions || []).filter(
          (q) =>
            q.type !== "comprehension" &&
            (app.draftAnswers[q.id] === undefined ||
              app.draftAnswers[q.id] === ""),
        ).length;
        if (
          !confirm(
            `Submit your exam now? ${unanswered ? `${unanswered} question(s) are unanswered. ` : ""}You cannot change answers after submission.`,
          )
        )
          return;
        const d = await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/submit`,
          { method: "POST", body: { revision: app.revision } },
        );
        app.state = {
          ...app.state,
          ...d,
          session: d.session || {
            ...app.state.session,
            status: "submitted",
            score: d.score,
            total_marks: d.total_marks,
          },
        };
        app.screen = "result";
        app.pending = {};
        app.dirty = false;
        await loadState();
        render();
        flash("Your submission was recorded.");
        startPolling();
        return;
      }
      if (action === "export") {
        const r = await fetch(
          `${API}/exam-platform/exams/${encodeURIComponent(app.exam.id)}/export`,
          {
            headers: { Accept: "text/csv", Authorization: `Bearer ${token()}` },
          },
        );
        if (!r.ok) throw new Error(`Export failed (${r.status})`);
        const blob = await r.blob();
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = `exam-${app.exam.id}-results.csv`;
        a.click();
        URL.revokeObjectURL(a.href);
        return;
      }
      if (action === "audit" || action === "older-audit") {
        const d = await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/audit${action === "older-audit" ? `?before=${app.auditBefore}` : ""}`,
        );
        app.auditEvents =
          action === "older-audit" ? [...app.auditEvents, ...d.audit] : d.audit;
        app.auditBefore = d.next_before;
        $("#ep-audit").innerHTML = auditHtml();
        return;
      }
      if (action === "messages") {
        await messagesPanel();
        return;
      }
    } catch (e) {
      flash(e.message || "The request failed.", true);
    } finally {
      if (b.isConnected) b.disabled = false;
    }
  }
  function auditHtml() {
    return `<h3>Audit history</h3>${(app.auditEvents || []).map((x) => `<p class="ep-audit-item"><b>${esc(x.event)}</b> · ${esc(formatDate(x.created_at))} · ${esc(x.actor?.name || "System")}</p>`).join("") || "<p>No audit events.</p>"}${app.auditBefore ? '<button class="ep-btn" data-action="older-audit">Load older events</button>' : ""}`;
  }
  async function act(action, extra = {}) {
    await request(
      `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/actions`,
      { method: "POST", body: { action, ...extra } },
    );
  }
  async function messagesPanel() {
    const d = await request(
      `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/messages`,
    );
    const items = Array.isArray(d) ? d : d.messages || [];
    const dialog = document.createElement("dialog");
    dialog.className = "ep-dialog";
    dialog.innerHTML = `<form method="dialog"><header><h2>Exam messages</h2><button class="ep-btn ep-btn-quiet">Close</button></header><div class="ep-message-list">${items.map((m) => `<article><b>${esc(m.sender_name || m.name || m.role || "Participant")}</b><small>${esc(formatDate(m.created_at))}</small><p>${esc(m.text)}</p></article>`).join("") || '<p class="ep-muted">No messages yet.</p>'}</div><div class="ep-message-compose"><textarea name="text" maxlength="2000" placeholder="Write a message to the exam room…"></textarea><button type="button" class="ep-btn ep-btn-primary" data-send-message>Send</button></div></form>`;
    document.body.appendChild(dialog);
    dialog.showModal();
    dialog.querySelector("[data-send-message]").onclick = async () => {
      const text = dialog.querySelector("textarea").value.trim();
      if (!text) return;
      try {
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/messages`,
          { method: "POST", body: { text } },
        );
        dialog.close();
        dialog.remove();
        await messagesPanel();
      } catch (e) {
        flash(e.message, true);
      }
    };
    dialog.addEventListener("close", () => dialog.remove());
  }
  function onBlur() {
    event("blur");
  }
  function onVisibility() {
    if (document.visibilityState === "hidden") event("visibility_hidden");
  }
  function onFullscreen() {
    if (!document.fullscreenElement) event("fullscreen_exit");
  }
  function onInput(ev) {
    const t = ev.target;
    if (t.matches("#ep-paper-filter")) {
      app.paperFilter = t.value;
      app.paperPick = "";
      const select = $("#ep-paper-select");
      if (select) select.innerHTML = paperOptions();
      const load = $('[data-action="load-paper"]');
      if (load) load.disabled = true;
    }
    if (t.matches("#ep-import-json")) {
      app.importText = t.value;
      app.importQuestions = null;
      const b = $('[data-action="import"]');
      if (b) b.disabled = true;
    }
    if (t.matches("[data-answer-text]"))
      changedAnswer(t.dataset.answerText, t.value);
    if (t.matches("[data-answer-multi]")) {
      const id = t.dataset.answerMulti;
      const vals = Array.from(
        document.querySelectorAll(
          `[data-answer-multi="${CSS.escape(id)}"]:checked`,
        ),
      )
        .map((x) => Number(x.value))
        .sort((a, b) => a - b);
      changedAnswer(id, vals);
    }
  }
  function onChange(ev) {
    const t = ev.target;
    if (t.matches("[data-answer]"))
      changedAnswer(
        t.dataset.answer,
        t.value === "true"
          ? true
          : t.value === "false"
            ? false
            : Number(t.value),
      );
    if (t.matches("#ep-paper-select")) {
      app.paperPick = t.value;
      const load = $('[data-action="load-paper"]');
      if (load) load.disabled = !t.value;
    }
    if (t.matches("[data-import-file]") && t.files?.[0]) {
      if (t.files[0].size > 5 * 1024 * 1024) {
        flash("Import must be smaller than 5 MB.", true);
        return;
      }
      rememberSetup();
      const reader = new FileReader();
      reader.onload = () => {
        app.importText = String(reader.result || "");
        const area = $("#ep-import-json");
        if (area) area.value = app.importText;
        try {
          app.importQuestions = parseImport(app.importText);
          render();
        } catch (e) {
          flash(e.message, true);
        }
      };
      reader.readAsText(t.files[0]);
    }
  }
  async function onSubmit(ev) {
    const form = ev.target.closest('form[data-form="exam"]');
    if (!form) return;
    ev.preventDefault();
    try {
      const payload = formData(form);
      app.busy = true;
      form.querySelector("[type=submit]").disabled = true;
      let exam;
      if (app.exam?.id)
        exam = examFrom(
          await request(
            `/exam-platform/exams/${encodeURIComponent(app.exam.id)}`,
            { method: "PATCH", body: payload },
          ),
        );
      else
        exam = examFrom(
          await request("/exam-platform/exams", {
            method: "POST",
            body: payload,
          }),
        );
      app.exam = exam;
      app.setupDraft = null;
      await loadExam(exam.id);
      app.screen = "edit";
      flash("Draft saved.");
    } catch (e) {
      app.error = e.message;
      render();
    } finally {
      app.busy = false;
      render();
    }
  }
  async function boot() {
    if (!desktopEligible()) { if(inExamArea) showDesktopOnly(); return; }
    if (!inExamArea) {
      let lastToken = "";
      const check = async () => {
        if (/^\/exams?(\/|$)/.test(location.pathname)) {
          location.reload();
          return;
        }
        if (!token() || token() === lastToken) return;
        lastToken = token();
        try {
          await verify();
          path = location.pathname;
          showEntry();
          const target = sessionStorage.getItem("ep_return");
          if (target && /^\/exams?(\/[-a-zA-Z0-9]+)?$/.test(target)) {
            sessionStorage.removeItem("ep_return");
            location.assign(target);
          }
        } catch (_) {}
      };
      await check();
      setInterval(check, 500);
      return;
    }
    mount();
    try {
      await verify();
      const name = $(".ep-user span");
      if (name) name.textContent = app.user.name || app.user.email;
      showEntry();
      await loadList();
      if (path.startsWith("/exams/") && path.split("/")[2]) {
        await loadExam(decodeURIComponent(path.split("/")[2]));
        if (app.exam.status !== "draft") {
          await loadState();
          app.screen = isManager()
            ? "detail"
            : ["in_exam", "locked"].includes(app.state.session?.status)
              ? "room"
              : app.state.session?.status === "submitted"
                ? "result"
                : "detail";
          render();
          startPolling();
        }
      }
    } catch (e) {
      app.error = e.message;
      app.screen = "list";
      render();
    }
  }
  window.addEventListener("blur", onBlur);
  document.addEventListener("visibilitychange", onVisibility);
  document.addEventListener("fullscreenchange", onFullscreen);
  window.addEventListener("online", () => {
    if (app.dirty) saveAnswers().catch(() => {});
    flushEvents();
  });
  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", boot);
  else boot();
  window.addEventListener("beforeunload", (ev) => {
    if (app.screen === "room" && app.dirty) {
      ev.preventDefault();
      ev.returnValue = "";
    }
  });
})();
