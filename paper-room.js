/*
 * Self-paced paper room.
 *
 * Papers open here in the exam portal's own exam screen: header with timer and
 * Submit, question palette on the left, one question at a time with Prev, Clear,
 * Review & Next and Save & Next. Nothing is proctored: no fullscreen, no focus
 * tracking, no shared clock and no manager.
 * It runs on the ordinary quiz API (start attempt, submit, result). Answers in
 * progress are kept in this browser until the paper is submitted.
 */
(function () {
  "use strict";

  const match = /^\/paper\/(\d+)\/?$/.exec(location.pathname);
  if (!match) return;
  const quizId = Number(match[1]);
  const API = (
    (window.QLStorefront && window.QLStorefront.apiBase) ||
    "https://labapi.genziitian.in/public/api"
  ).replace(/\/+$/, "");
  const API_ROOT = API.replace(/\/api$/i, "");
  let API_ORIGIN = "https://labapi.genziitian.in";
  try {
    API_ORIGIN = new URL(API).origin;
  } catch (_) {}
  const STORE_KEY = "ql_paper_room:" + quizId;
  const CHOICE = ["mcq", "true_false", "multi_select"];

  const st = {
    screen: "loading",
    quiz: null,
    error: "",
    blocked: null,
    attemptId: null,
    startedAt: 0,
    durationMinutes: null,
    answers: {},
    review: {},
    visited: {},
    current: 0,
    confirming: false,
    busy: false,
    submitError: "",
    summary: null,
    result: null,
    ticker: null,
  };

  const $ = (s, root = document) => root.querySelector(s);
  async function fetchWithTimeout(url, options, timeoutMs) {
    if (typeof AbortController !== "function") return fetch(url, options);

    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      window.clearTimeout(timeout);
    }
  }
  const esc = (v) =>
    String(v == null ? "" : v).replace(
      /[&<>"']/g,
      (c) =>
        ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
    );
  const token = () => {
    try {
      return localStorage.getItem("lab_token") || "";
    } catch (_) {
      return "";
    }
  };
  const userName = () => {
    try {
      const user = JSON.parse(localStorage.getItem("lab_user") || "{}");
      return user.name || user.email || "";
    } catch (_) {
      return "";
    }
  };

  /* ---------------------------- storage ---------------------------- */
  function readStore() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
      return saved && saved.attemptId ? saved : null;
    } catch (_) {
      return null;
    }
  }
  function writeStore() {
    try {
      localStorage.setItem(
        STORE_KEY,
        JSON.stringify({
          attemptId: st.attemptId,
          startedAt: st.startedAt,
          durationMinutes: st.durationMinutes,
          answers: st.answers,
          review: st.review,
          visited: st.visited,
          current: st.current,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
  function clearStore() {
    try {
      localStorage.removeItem(STORE_KEY);
    } catch (_) {}
  }

  /* ------------------------------ API ------------------------------ */
  async function request(url, options = {}) {
    const response = await fetchWithTimeout(API + url, {
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        Authorization: "Bearer " + token(),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
    }, 25000);
    let data = null;
    try {
      data = await response.json();
    } catch (_) {}
    if (response.status === 401) {
      signIn();
      throw new Error("Please sign in again.");
    }
    if (!response.ok) {
      const error = new Error(
        (data && (data.message || (typeof data.error === "string" && data.error))) ||
          "Request failed (" + response.status + ")",
      );
      error.status = response.status;
      error.data = data;
      throw error;
    }
    return data || {};
  }
  function signIn() {
    if (window.QLStorefront && window.QLStorefront.signIn) window.QLStorefront.signIn(quizId, true);
    else location.assign("/login");
  }

  /* ---------------------------- content ---------------------------- */
  function clean(value) {
    let text = String(value == null ? "" : value)
      .replace(/\\r\\n/g, "\n")
      .replace(/\\n(?![a-zA-Z])/g, "\n");
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
  function rich(content) {
    if (window.ExamRichContent && window.ExamRichContent.render)
      return window.ExamRichContent.render(content);
    return esc(typeof content === "string" ? content : "").replace(/\n/g, "<br>");
  }
  function codeBlock(code, language) {
    return rich([{ kind: "code", language: language || "text", value: String(code || "") }]);
  }
  function tableBlock(table) {
    if (!table || typeof table !== "object") return "";
    let headers = Array.isArray(table.headers) ? table.headers : [];
    let rows = Array.isArray(table.rows) ? table.rows.filter(Array.isArray) : [];
    if (!headers.some((h) => String(h == null ? "" : h).trim() !== "")) {
      if (!rows.length) return "";
      headers = rows[0];
      rows = rows.slice(1);
    }
    return rich([
      {
        kind: "table",
        headers: headers.map((h) => String(h == null ? "" : h)),
        rows: rows.map((row) => row.map((cell) => String(cell == null ? "" : cell))),
        caption: typeof table.caption === "string" ? table.caption : "",
      },
    ]);
  }
  function imageUrl(value) {
    const path = String(value || "").trim();
    if (!path || /[\s"'<>\\]/.test(path)) return "";
    let url = "";
    if (/^https:\/\//i.test(path)) url = path;
    else if (/^[a-z][a-z0-9+.-]*:/i.test(path)) return "";
    else if (path.startsWith("/public/")) url = API_ORIGIN + path;
    else if (path.startsWith("/storage/")) url = API_ROOT + path;
    else if (path.startsWith("/question-images/") || path.startsWith("/avatars/"))
      url = API_ROOT + "/storage" + path;
    else if (path.startsWith("/")) url = API_ORIGIN + path;
    else if (path.startsWith("question-images/") || path.startsWith("avatars/"))
      url = API_ROOT + "/storage/" + path;
    else if (path.startsWith("public/")) url = API_ORIGIN + "/" + path;
    else url = API_ROOT + "/" + path;
    try {
      return new URL(url).protocol === "https:" ? url : "";
    } catch (_) {
      return "";
    }
  }
  function stemHtml(q) {
    const image = imageUrl(q.stem_image);
    return (
      rich(clean(q.stem != null ? q.stem : q.question_stem)) +
      (q.stem_code ? codeBlock(q.stem_code, q.stem_code_language) : "") +
      tableBlock(q.stem_table) +
      (image
        ? '<figure class="exam-rich-image"><img src="' +
          esc(image) +
          '" alt="Question figure" loading="lazy" referrerpolicy="no-referrer"></figure>'
        : "")
    );
  }
  function looksLikeCode(text) {
    const t = String(text || "").trim();
    const keyword = /\b(if|else|while|for|return|print|Procedure|End)\s*[({\s]/.test(t);
    return (/[{}]/.test(t) && keyword) || (keyword && /[<>!]=?\s*\w+\s*[({]/.test(t));
  }
  function optionHtml(option) {
    return option.option_type === "code" || looksLikeCode(option.option_text)
      ? codeBlock(option.option_text, option.code_language)
      : rich(clean(option.option_text));
  }

  /* ---------------------------- answers ---------------------------- */
  const questions = () => (st.quiz && st.quiz.questions) || [];
  const answerable = () => questions().filter((q) => q.type !== "comprehension");
  function isAnswered(q) {
    const a = st.answers[q.id];
    if (!a) return false;
    if (CHOICE.includes(q.type)) return Array.isArray(a.o) && a.o.length > 0;
    if (q.type === "numerical") return String(a.n == null ? "" : a.n).trim() !== "";
    return String(a.t == null ? "" : a.t).trim() !== "";
  }
  const answeredCount = () => answerable().filter(isAnswered).length;
  function payload() {
    return answerable().map((q) => {
      const a = st.answers[q.id] || {};
      const number = String(a.n == null ? "" : a.n).trim();
      return {
        question_id: q.id,
        selected_option_ids: CHOICE.includes(q.type) && Array.isArray(a.o) ? a.o.map(Number) : [],
        text_answer: q.type === "short_answer" && String(a.t || "").trim() ? String(a.t) : null,
        numerical_answer:
          q.type === "numerical" && number !== "" && Number.isFinite(Number(number))
            ? Number(number)
            : null,
      };
    });
  }

  /* ----------------------------- timer ----------------------------- */
  const limitSeconds = () => Math.max(0, Number(st.durationMinutes == null ? (st.quiz && st.quiz.time_limit_minutes) || 0 : st.durationMinutes)) * 60;
  function remaining() {
    const limit = limitSeconds();
    if (!limit) return null;
    return Math.max(0, Math.ceil(limit - (Date.now() - st.startedAt) / 1000));
  }
  function clock(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    return [Math.floor(s / 3600), Math.floor((s % 3600) / 60), s % 60]
      .map((n) => String(n).padStart(2, "0"))
      .join(":");
  }
  const timeText = (seconds) => (seconds >= 3600 ? clock(seconds) : clock(seconds).slice(3));
  function startTicker() {
    stopTicker();
    if (!limitSeconds()) return;
    st.ticker = setInterval(tick, 1000);
    tick();
  }
  function stopTicker() {
    clearInterval(st.ticker);
    st.ticker = null;
  }
  function tick() {
    if (st.screen !== "room") return stopTicker();
    const left = remaining();
    const node = $("#ep-countdown");
    if (node) {
      node.textContent = timeText(left);
      const low = left < 300;
      node.style.color = low ? "#ef4444" : "#0f172a";
      const dot = $("#pr-timer-dot");
      if (dot) dot.style.background = low ? "#ef4444" : "#33558b";
    }
    if (left <= 0 && !st.busy) submit(true);
  }

  /* ----------------------------- views ----------------------------- */
  function shell() {
    let root = document.getElementById("ep-app");
    if (!root) {
      root = document.createElement("main");
      root.id = "ep-app";
      document.body.appendChild(root);
    }
    root.innerHTML =
      '<div class="ep-shell"><header class="ep-top"><a class="ep-brand" href="/papers"><img class="ep-mark" src="/assets/quiz-lab-icon.png" alt="" width="36" height="36"><span><b>Quiz LAB</b><small>Paper room</small></span></a><div class="ep-user"><span>' +
      esc(userName()) +
      '</span><a class="ep-link" href="/my-papers">My papers</a><a class="ep-link" href="/dashboard">Dashboard</a></div></header><div id="ep-content"></div></div>';
    root.addEventListener("click", onClick);
    root.addEventListener("change", onChange);
    root.addEventListener("input", onInput);
  }
  function page(inner, narrow) {
    return '<section class="ep-page' + (narrow ? " ep-narrow" : "") + '">' + inner + "</section>";
  }
  function introView() {
    const q = st.quiz;
    const count = answerable().length;
    const marks = answerable().reduce((sum, item) => sum + Number(item.marks || 0), 0);
    const saved = readStore();
    const minutes = Number(q.time_limit_minutes || 0);
    const savedMinutes = saved
      ? Number(saved.durationMinutes == null ? minutes : saved.durationMinutes)
      : null;
    const selectedTime = st.durationMinutes == null
      ? "default"
      : st.durationMinutes === minutes
        ? "default"
        : [0, 15, 30, 45, 60].includes(st.durationMinutes)
          ? String(st.durationMinutes)
          : "custom";
    const timeOption = (value, label) =>
      '<option value="' + value + '"' + (selectedTime === String(value) ? " selected" : "") + ">" + label + "</option>";
    return page(
      '<div class="ep-card"><p class="ep-eyebrow">BEFORE YOU BEGIN</p><h1>' +
        esc(q.title) +
        "</h1>" +
        (q.description ? '<p class="ep-instructions">' + esc(q.description) + "</p>" : "") +
        '<dl class="ep-facts"><div><dt>Course</dt><dd>' +
        esc((q.course && q.course.name) || "—") +
        "</dd></div><div><dt>Questions</dt><dd>" +
        count +
        "</dd></div><div><dt>Total marks</dt><dd>" +
        marks +
        "</dd></div><div><dt>Time</dt><dd>" +
        (minutes ? minutes + " minutes" : "Untimed") +
        "</dd></div></dl>" +
        (saved
          ? '<p class="pr-time-choice"><b>Saved time limit</b><span>' +
            (savedMinutes ? savedMinutes + " minutes" : "Untimed") +
            " · Your original clock continues when you resume.</span></p>"
          : '<label class="pr-time-choice" for="pr-time-select"><b>Set your time limit</b><select id="pr-time-select">' +
            timeOption("default", "Paper default · " + (minutes ? minutes + " min" : "Untimed")) +
            timeOption(0, "Untimed") +
            timeOption(15, "15 minutes") +
            timeOption(30, "30 minutes") +
            timeOption(45, "45 minutes") +
            timeOption(60, "60 minutes") +
            timeOption("custom", "Custom time") +
            '</select><input id="pr-time-custom" type="number" min="1" max="600" placeholder="Custom minutes (1–600)" value="' +
            (selectedTime === "custom" ? String(st.durationMinutes) : "") +
            '"' + (selectedTime === "custom" ? "" : " hidden") + '></label>') +
        "<p>" +
        (minutes
          ? "This paper is self-paced: start whenever you are ready. The timer begins when you start, keeps running if you leave the page, and the paper is submitted automatically when time runs out."
          : "This paper is self-paced and untimed. Start whenever you are ready and submit when you are done.") +
        '</p>' +
        (st.error ? '<div class="ep-alert error" role="alert">' + esc(st.error) + "</div>" : "") +
        '<div class="ep-actions"><a class="ep-btn pr-btn-link" href="/papers">Back to papers</a><button class="ep-btn ep-btn-primary" data-action="start"' +
        (st.busy || !count ? " disabled" : "") +
        ">" +
        (st.busy ? "Starting…" : saved ? "Resume paper" : "Start paper") +
        "</button></div></div>",
      true,
    );
  }
  /* The exam screen. Markup and inline styles follow the exam portal's live exam view. */
  const TYPE_LABEL = {
    mcq: "MCQ SINGLE",
    multi_select: "MCQ MULTI",
    true_false: "TRUE FALSE",
    numerical: "NUMERICAL",
    short_answer: "SHORT ANSWER",
    comprehension: "PASSAGE",
  };
  const ICON_CHECK =
    '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>';
  function optionLabelStyle(checked) {
    return (
      "display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:10px;border:1.5px solid " +
      (checked ? "#33558b" : "#e2e8f0") +
      ";background:" +
      (checked ? "#eef3fa" : "#ffffff") +
      ";cursor:pointer;transition:all 0.15s ease;"
    );
  }
  function inputsHtml(q) {
    const a = st.answers[q.id] || {};
    if (CHOICE.includes(q.type)) {
      const multi = q.type === "multi_select";
      const chosen = (Array.isArray(a.o) ? a.o : []).map(String);
      return (
        '<div style="display:flex;flex-direction:column;gap:10px;">' +
        (q.options || [])
          .map((o) => {
            const checked = chosen.includes(String(o.id));
            return (
              '<label style="' +
              optionLabelStyle(checked) +
              '"><input type="' +
              (multi ? "checkbox" : "radio") +
              '" name="opt-' +
              esc(q.id) +
              '" data-choice="' +
              esc(q.id) +
              '" value="' +
              esc(o.id) +
              '"' +
              (checked ? " checked" : "") +
              ' style="width:16px;height:16px;accent-color:#33558b;flex-shrink:0;" /><span class="pr-option" style="font-size:14px;color:#1e293b;font-weight:500;min-width:0;flex:1;">' +
              optionHtml(o) +
              "</span></label>"
            );
          })
          .join("") +
        "</div>"
      );
    }
    if (q.type === "numerical")
      return (
        '<div><label style="display:block;font-size:12px;font-weight:700;color:#64748b;margin-bottom:6px;">Enter Numerical Answer:</label><input type="text" inputmode="decimal" autocomplete="off" maxlength="40" data-number="' +
        esc(q.id) +
        '" value="' +
        esc(a.n == null ? "" : a.n) +
        '" placeholder="e.g. 42" style="background:#fff;border:1.5px solid #cbd5e1;padding:10px 14px;border-radius:8px;font-size:15px;width:240px;max-width:100%;color:#0f172a;outline:none;" /><p class="pr-hint" data-hint="' +
        esc(q.id) +
        '" role="alert"></p></div>'
      );
    if (q.type === "short_answer")
      return (
        '<div><label style="display:block;font-size:12px;font-weight:700;color:#64748b;margin-bottom:6px;">Enter Short Answer:</label><input type="text" autocomplete="off" maxlength="2000" data-text="' +
        esc(q.id) +
        '" value="' +
        esc(a.t == null ? "" : a.t) +
        '" placeholder="Type your answer here..." style="background:#fff;border:1.5px solid #cbd5e1;padding:10px 14px;border-radius:8px;font-size:14px;width:320px;max-width:100%;color:#0f172a;outline:none;" /></div>'
      );
    return '<p style="font-size:12px;color:#64748b;margin:0;">This passage is provided for the questions that follow.</p>';
  }
  function paletteHtml() {
    return questions()
      .map((q, i) => {
        const status = st.review[q.id]
          ? "ep-q-review"
          : q.type !== "comprehension" && isAnswered(q)
            ? "ep-q-answered"
            : "ep-q-unvisited";
        return (
          '<button type="button" class="ep-q-btn ' +
          status +
          (i === st.current ? " current" : "") +
          '" data-go="' +
          i +
          '" aria-label="Question ' +
          (i + 1) +
          (status === "ep-q-answered" ? ", answered" : status === "ep-q-review" ? ", marked for review" : "") +
          '">' +
          (i + 1) +
          "</button>"
        );
      })
      .join("");
  }
  function legendHtml() {
    const total = answerable().length;
    const answered = answeredCount();
    const review = questions().filter((q) => st.review[q.id]).length;
    const row = (bg, border, text) =>
      '<div style="display:flex;align-items:center;gap:6px;"><span style="width:10px;height:10px;border-radius:3px;background:' +
      bg +
      ";border:1px solid " +
      border +
      ';"></span>' +
      text +
      "</div>";
    return (
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;">' +
      row("#dfe8f5", "#9fb6d8", "Answered (" + answered + ")") +
      row("#ede9fe", "#c4b5fd", "Review (" + review + ")") +
      row("#f1f5f9", "#cbd5e1", "Unanswered (" + (total - answered) + ")") +
      "</div>"
    );
  }
  function roomView() {
    const quiz = st.quiz;
    const list = questions();
    const total = list.length;
    const index = Math.min(st.current, Math.max(0, total - 1));
    const q = list[index] || {};
    const passage = q.type === "comprehension";
    const left = remaining();
    const low = left != null && left < 300;
    return (
      '<div id="ep-root" class="ep-live-exam-root pr-live-root" style="display:flex;flex-direction:column;overflow:hidden;background:#f8fafc;">' +
      '<header class="pr-live-header" style="background:#ffffff;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between;padding:0 clamp(18px, 2vw, 34px);flex-shrink:0;">' +
      '<div style="display:flex;align-items:center;gap:12px;min-width:0;"><img src="/assets/quiz-lab-icon.png" alt="Quiz Lab" style="height:32px;width:32px;border-radius:9px;flex-shrink:0;"><div style="min-width:0;"><h1 style="font-size:clamp(14px, 1.15vw, 21px);font-weight:800;color:#0f172a;margin:0;overflow-wrap:anywhere;">' +
      esc(quiz.title) +
      '</h1><div style="font-size:clamp(11px, 0.9vw, 15px);color:#64748b;">' +
      esc([userName(), quiz.course && quiz.course.name].filter(Boolean).join(" • ")) +
      "</div></div></div>" +
      '<div class="pr-live-tools" style="display:flex;align-items:center;gap:10px;">' +
      '<div class="ep-header-warning">Answered: <b id="pr-answered">' +
      answeredCount() +
      "/" +
      answerable().length +
      "</b></div>" +
      '<div style="display:flex;align-items:center;gap:6px;background:#f1f5f9;padding:6px 12px;border-radius:8px;border:1px solid #cbd5e1;"><span id="pr-timer-dot" style="width:8px;height:8px;border-radius:9999px;background:' +
      (low ? "#ef4444" : "#33558b") +
      ';animation:ep-pulse 2s infinite;"></span><span class="pr-live-time-label" style="font-size:11px;font-weight:700;color:#64748b;">Time:</span><span id="ep-countdown" style="font-size:15px;font-weight:800;color:' +
      (low ? "#ef4444" : "#0f172a") +
      ';font-family:ui-monospace,monospace;">' +
      (left == null ? "Untimed" : timeText(left)) +
      "</span></div>" +
      '<button type="button" id="btn-student-submit" data-action="submit"' +
      (st.busy ? " disabled" : "") +
      ' style="background:#33558b;border:none;color:#fff;padding:7px 18px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:6px;box-shadow:0 1px 3px rgba(51,85,139,0.3);transition:background 0.15s;">' +
      ICON_CHECK +
      (st.busy ? " Submitting…" : " Submit &amp; Exit") +
      "</button></div></header>" +
      '<div class="pr-live-body" style="display:flex;flex:1;overflow:hidden;">' +
      '<aside id="ep-sidebar" class="pr-live-aside" style="width:clamp(280px, 24vw, 380px);background:#ffffff;border-right:2px solid #0f172a;display:flex;flex-direction:column;flex-shrink:0;">' +
      '<div class="pr-live-palette" style="flex:1;overflow-y:auto;padding:16px;"><div class="pr-live-palette-title" style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:12px;">Question Palette</div><div class="ep-q-grid" id="pr-palette">' +
      paletteHtml() +
      "</div></div>" +
      '<div class="pr-live-tools-box" style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#ffffff;"><button type="button" data-calc="toggle" title="Open calculator" style="width:100%;background:#eef3fa;border:1px solid #c7d4e8;color:#24406b;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">Calculator</button></div>' +
      '<div class="pr-live-legend" id="pr-legend" style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#f8fafc;font-size:11px;color:#475569;">' +
      legendHtml() +
      "</div></aside>" +
      '<main class="pr-live-main" id="pr-main" style="flex:1;display:flex;flex-direction:column;overflow-y:auto;padding:clamp(22px, 2vw, 42px) clamp(28px, 3vw, 58px);background:#ffffff;">' +
      '<div id="pr-error" role="alert"' +
      (st.submitError ? "" : " hidden") +
      ' style="margin-bottom:14px;padding:10px 14px;border-radius:8px;border:1px solid #fecaca;background:#fef2f2;color:#b91c1c;font-size:13px;">' +
      esc(st.submitError) +
      "</div>" +
      '<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;border-bottom:1px solid #e2e8f0;padding-bottom:12px;margin-bottom:18px;"><div style="display:flex;align-items:center;gap:10px;"><span style="font-size:17px;font-weight:800;color:#0f172a;">Question ' +
      (index + 1) +
      " of " +
      total +
      '</span><span style="padding:3px 8px;border-radius:6px;background:#e0f2fe;color:#0369a1;font-size:11px;font-weight:700;">' +
      esc(TYPE_LABEL[q.type] || String(q.type || "").toUpperCase()) +
      "</span></div>" +
      (passage
        ? ""
        : '<div style="font-size:12px;font-weight:700;color:#33558b;">+' + Number(q.marks || 0) + " Marks</div>") +
      "</div>" +
      '<div class="pr-live-prompt" style="font-size:15px;color:#0f172a;line-height:1.6;font-weight:500;margin-bottom:14px;">' +
      stemHtml(q) +
      "</div>" +
      '<div style="margin-bottom:28px;" id="pr-q-' +
      esc(q.id) +
      '">' +
      inputsHtml(q) +
      "</div>" +
      '<div class="pr-live-actions" style="margin-top:auto;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;border-top:1px solid #e2e8f0;background:#ffffff;"><div style="display:flex;gap:8px;">' +
      '<button type="button" id="btn-q-prev" data-action="prev"' +
      (index === 0 ? " disabled" : "") +
      ' style="background:#fff;border:1px solid #cbd5e1;color:#475569;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:' +
      (index === 0 ? "not-allowed" : "pointer") +
      ";opacity:" +
      (index === 0 ? 0.4 : 1) +
      ';">← Prev</button>' +
      (passage
        ? ""
        : '<button type="button" id="btn-q-clear" data-action="clear" data-id="' +
          esc(q.id) +
          '" style="background:#fff;border:1px solid #cbd5e1;color:#64748b;padding:9px 14px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">Clear</button>') +
      '</div><div style="display:flex;gap:8px;">' +
      (passage
        ? ""
        : '<button type="button" id="btn-q-review" data-action="review" style="background:#f5f3ff;border:1px solid #c4b5fd;color:#6d28d9;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">' +
          (st.review[q.id] ? 'Marked<span class="pr-wide"> for Review</span>' : 'Review<span class="pr-wide"> &amp; Next</span>') +
          "</button>") +
      '<button type="button" id="btn-q-save-next" data-action="next" style="background:#33558b;color:#fff;border:none;padding:9px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">' +
      (index === total - 1 ? "Save Response" : passage ? "Next →" : "Save &amp; Next →") +
      "</button></div></div></main></div></div>"
    );
  }
  function submitModal() {
    const old = document.getElementById("ep-student-submit-modal");
    if (old) old.remove();
    const modal = document.createElement("div");
    modal.id = "ep-student-submit-modal";
    modal.style.cssText =
      "display:flex;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(15,23,42,0.8);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);z-index:999999;align-items:center;justify-content:center;padding:20px;";
    const review = questions().filter((q) => st.review[q.id]).length;
    modal.innerHTML =
      '<div role="dialog" aria-modal="true" aria-labelledby="pr-submit-title" style="max-width:460px;width:100%;text-align:center;background:#ffffff;border-radius:20px;box-shadow:0 25px 60px -15px rgba(0,0,0,0.3);padding:30px 24px;color:#0f172a;"><img src="/assets/quiz-lab-icon.png" alt="Quiz Lab" style="height:40px;width:40px;border-radius:11px;margin-bottom:12px;"><h2 id="pr-submit-title" style="font-size:20px;font-weight:800;color:#0f172a;margin:0 0 8px 0;">Submit paper</h2><p style="font-size:13.5px;color:#475569;margin:0 0 18px 0;line-height:1.55;">You have recorded answers for <b>' +
      answeredCount() +
      " of " +
      answerable().length +
      "</b> questions" +
      (review ? ", with <b>" + review + "</b> marked for review" : "") +
      '. Once submitted, your answers are final and you will see your result.</p><div style="display:flex;gap:10px;"><button type="button" id="ep-btn-cancel-submit" style="flex:1;background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;padding:11px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">Return to Paper</button><button type="button" id="ep-btn-confirm-submit" style="flex:1.2;background:#33558b;color:#ffffff;border:none;padding:11px;border-radius:8px;font-size:13px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">' +
      ICON_CHECK +
      " Submit</button></div></div>";
    document.body.appendChild(modal);
    const close = () => modal.remove();
    modal.addEventListener("click", (ev) => {
      if (ev.target === modal) close();
    });
    modal.addEventListener("keydown", (ev) => {
      if (ev.key === "Escape") close();
    });
    document.getElementById("ep-btn-cancel-submit").onclick = close;
    document.getElementById("ep-btn-confirm-submit").onclick = () => {
      close();
      submit(false);
    };
    document.getElementById("ep-btn-confirm-submit").focus();
  }
  function go(index) {
    const list = questions();
    if (!list.length) return;
    st.current = Math.min(Math.max(0, index), list.length - 1);
    st.visited[list[st.current].id] = true;
    writeStore();
    render();
    const main = $("#pr-main");
    if (main) main.scrollTop = 0;
  }
  function studentAnswerHtml(a) {
    const type = a.question_type;
    if (CHOICE.includes(type)) return "";
    const value = type === "numerical" ? a.student_numerical_answer : a.student_text_answer;
    return (
      '<p class="ep-muted">Your answer</p><div>' +
      (value == null || String(value).trim() === ""
        ? '<span class="ep-muted">No answer</span>'
        : esc(value)) +
      '</div><p class="ep-muted">Accepted answer</p><div>' +
      (type === "numerical"
        ? esc(a.correct_numerical == null ? "—" : a.correct_numerical)
        : esc((a.correct_short_answers || []).join(" · ") || "—")) +
      "</div>"
    );
  }
  function reviewCard(a, number) {
    if (a.question_type === "comprehension")
      return (
        '<article class="ep-question"><header><span>Context</span><span></span></header><div class="ep-question-prompt">' +
        stemHtml(a) +
        "</div></article>"
      );
    const chosen = (Array.isArray(a.student_selected_option_ids) ? a.student_selected_option_ids : []).map(String);
    const answered =
      chosen.length > 0 ||
      (a.student_text_answer != null && String(a.student_text_answer).trim() !== "") ||
      a.student_numerical_answer != null;
    const state = a.is_correct ? "correct" : answered ? "wrong" : "skipped";
    const label = { correct: "Correct", wrong: "Incorrect", skipped: "Not answered" }[state];
    const options = CHOICE.includes(a.question_type)
      ? (a.options || [])
          .map((o) => {
            const mine = chosen.includes(String(o.id));
            return (
              '<div class="ep-answer pr-review-option' +
              (o.is_correct ? " is-correct" : mine ? " is-wrong" : "") +
              '"><span class="pr-option">' +
              optionHtml(o) +
              '</span><span class="pr-tags">' +
              (mine ? '<span class="pr-tag">Your answer</span>' : "") +
              (o.is_correct ? '<span class="pr-tag ok">Correct answer</span>' : "") +
              "</span></div>"
            );
          })
          .join("")
      : "";
    return (
      '<article class="ep-question pr-review ' +
      state +
      '"><header><span>Question ' +
      number +
      ' · <b class="pr-verdict">' +
      label +
      "</b></span><span>" +
      Number(a.marks_awarded || 0) +
      " / " +
      Number(a.marks || 0) +
      ' marks</span></header><div class="ep-question-prompt">' +
      stemHtml(a) +
      "</div>" +
      options +
      studentAnswerHtml(a) +
      (a.explanation
        ? '<div class="pr-explanation"><p class="ep-muted">Explanation</p>' + rich(clean(a.explanation)) + "</div>"
        : "") +
      "</article>"
    );
  }
  function resultView() {
    const r = st.result || {};
    const attempt = r.attempt || st.summary || {};
    const xp = st.summary && st.summary.xp_award && Number(st.summary.xp_award.xp_gained || 0);
    const answers = Array.isArray(r.answers) ? r.answers : [];
    const scored = answers.filter((a) => a.question_type !== "comprehension");
    const correct = scored.filter((a) => a.is_correct).length;
    let number = 0;
    return (
      '<section class="ep-page"><div class="ep-card ep-result-card"><p class="ep-eyebrow">PAPER SUBMITTED</p><h1>' +
      esc((r.quiz && r.quiz.title) || (st.quiz && st.quiz.title) || "Your result") +
      '</h1><div class="ep-result-score"><b>' +
      Number(attempt.score || 0) +
      "</b><span>/ " +
      Number(attempt.total_marks || 0) +
      " marks · " +
      Math.round(Number(attempt.percentage || 0)) +
      "%</span></div>" +
      (scored.length ? "<p>" + correct + " of " + scored.length + " questions correct.</p>" : "") +
      (xp ? '<div class="ep-alert">+' + xp + " XP earned.</div>" : "") +
      (st.error ? '<div class="ep-alert error" role="alert">' + esc(st.error) + "</div>" : "") +
      '<div class="ep-actions pr-result-actions"><a class="ep-btn pr-btn-link" href="/papers"><span class="pr-wide">Back to </span>Papers</a><a class="ep-btn pr-btn-link" href="/dashboard">Dashboard</a><button class="ep-btn ep-btn-primary" data-action="retake">Attempt again</button></div></div>' +
      (answers.length
        ? '<h2 class="pr-review-title">Answer review</h2><div class="ep-questions">' +
          answers.map((a) => reviewCard(a, a.question_type === "comprehension" ? 0 : ++number)).join("") +
          "</div>"
        : "") +
      "</section>"
    );
  }
  function blockedView() {
    const b = st.blocked;
    return page(
      '<div class="ep-card"><p class="ep-eyebrow">' +
        esc(b.eyebrow) +
        "</p><h1>" +
        esc(b.title) +
        "</h1><p>" +
        esc(b.text) +
        '</p><div class="ep-actions">' +
        (b.retry ? '<button class="ep-btn" data-action="reload">Try again</button>' : "") +
        '<a class="ep-btn ep-btn-primary pr-btn-link" href="' +
        esc(b.href) +
        '">' +
        esc(b.cta) +
        "</a></div></div>",
      true,
    );
  }
  function render() {
    const root = $("#ep-content");
    if (!root) return;
    root.innerHTML =
      st.screen === "intro"
        ? introView()
        : st.screen === "room"
          ? roomView()
          : st.screen === "result"
            ? resultView()
            : st.screen === "blocked"
              ? blockedView()
              : page('<div class="ep-card"><p>Loading paper…</p></div>', true);
    if (window.ExamRichContent && window.ExamRichContent.typeset) window.ExamRichContent.typeset(root);
    const app = document.getElementById("ep-app");
    if (app) app.classList.toggle("pr-live", st.screen === "room");
    if (st.screen !== "room" && window.ExamCalculator) window.ExamCalculator.close();
    document.title = (st.quiz && st.quiz.title ? st.quiz.title + " · " : "") + "Paper room · Quiz LAB";
  }
  function refreshProgress() {
    const counter = $("#pr-answered");
    if (counter) counter.textContent = answeredCount() + "/" + answerable().length;
    const palette = $("#pr-palette");
    if (palette) palette.innerHTML = paletteHtml();
    const legend = $("#pr-legend");
    if (legend) legend.innerHTML = legendHtml();
  }
  function refreshBar() {
    const error = $("#pr-error");
    if (error) {
      error.textContent = st.submitError;
      error.hidden = !st.submitError;
      if (st.submitError) error.scrollIntoView({ block: "nearest" });
    }
    const button = $("#btn-student-submit");
    if (button) {
      button.disabled = st.busy;
      button.innerHTML = ICON_CHECK + (st.busy ? " Submitting…" : " Submit &amp; Exit");
    }
  }

  /* ---------------------------- actions ---------------------------- */
  async function start() {
    if (st.busy) return;
    const savedDraft = readStore();
    if (savedDraft) {
      st.durationMinutes = Number(savedDraft.durationMinutes == null ? (st.quiz && st.quiz.time_limit_minutes) || 0 : savedDraft.durationMinutes);
    } else {
      const select = $("#pr-time-select");
      const chosen = select ? select.value : "default";
      if (chosen === "custom") {
        const custom = Number(($("#pr-time-custom") || {}).value || 0);
        if (!Number.isInteger(custom) || custom < 1 || custom > 600) {
          st.error = "Enter a custom time between 1 and 600 minutes.";
          render();
          return;
        }
        st.durationMinutes = custom;
      } else if (chosen === "default") {
        st.durationMinutes = Number((st.quiz && st.quiz.time_limit_minutes) || 0);
      } else {
        st.durationMinutes = Number(chosen);
      }
    }
    st.busy = true;
    st.error = "";
    render();
    try {
      const data = await request("/quizzes/" + quizId + "/attempts", { method: "POST" });
      const attemptId = data.attempt_id || (data.attempt && data.attempt.id) || data.id;
      if (!attemptId) throw new Error("Could not start this paper. Please try again.");
      const saved = savedDraft;
      st.attemptId = attemptId;
      if (saved && String(saved.attemptId) === String(attemptId)) {
        st.startedAt = Number(saved.startedAt) || Date.now();
        st.answers = saved.answers && typeof saved.answers === "object" ? saved.answers : {};
        st.review = saved.review && typeof saved.review === "object" ? saved.review : {};
        st.visited = saved.visited && typeof saved.visited === "object" ? saved.visited : {};
        st.current = Math.min(Math.max(0, Number(saved.current) || 0), Math.max(0, questions().length - 1));
      } else {
        st.startedAt = Date.now();
        st.answers = {};
        st.review = {};
        st.visited = {};
        st.current = 0;
      }
      if (questions()[st.current]) st.visited[questions()[st.current].id] = true;
      writeStore();
      st.busy = false;
      st.confirming = false;
      st.submitError = "";
      st.screen = "room";
      render();
      window.scrollTo(0, 0);
      startTicker();
    } catch (e) {
      st.busy = false;
      if (e.status === 402) return showPurchase(e);
      st.error = e.message;
      render();
    }
  }
  async function submit(auto) {
    if (st.busy || !st.attemptId) return;
    st.busy = true;
    st.confirming = !auto;
    st.submitError = "";
    refreshBar();
    try {
      st.summary = await request("/attempts/" + st.attemptId + "/submit", {
        method: "POST",
        body: { answers: payload() },
      });
    } catch (e) {
      st.busy = false;
      st.confirming = false;
      if (e.status === 402) return showPurchase(e);
      if (e.status !== 422 || !/already been submitted/i.test(e.message)) {
        st.submitError =
          (auto ? "Time is up, but the paper could not be submitted: " : "Could not submit: ") +
          e.message +
          " Your answers are still here. Press Submit & Exit to retry.";
        if (auto) stopTicker();
        refreshBar();
        return;
      }
    }
    stopTicker();
    const attemptId = st.attemptId;
    clearStore();
    st.busy = false;
    st.confirming = false;
    st.error = "";
    try {
      st.result = await request("/attempts/" + attemptId + "/result");
    } catch (e) {
      st.result = null;
      st.error = "Your paper was submitted, but the answer review could not be loaded: " + e.message;
    }
    st.screen = "result";
    render();
    window.scrollTo(0, 0);
  }
  function showPurchase(e) {
    stopTicker();
    st.blocked = {
      eyebrow: "ACCESS NEEDED",
      title: "This is a paid paper",
      text: (e && e.message) || "Buy or renew this paper to open it.",
      href: "/papers?paper=" + quizId,
      cta: "View paper",
    };
    st.screen = "blocked";
    render();
  }
  function onClick(ev) {
    const jump = ev.target.closest("[data-go]");
    if (jump) return void go(Number(jump.dataset.go));
    const calc = ev.target.closest("[data-calc]");
    if (calc) return void (window.ExamCalculator && window.ExamCalculator.toggle(calc.dataset.calc === "toggle" ? undefined : calc.dataset.calc));
    const target = ev.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    if (action === "start") start();
    else if (action === "reload") location.reload();
    else if (action === "submit") submitModal();
    else if (action === "prev") go(st.current - 1);
    else if (action === "next") go(st.current + 1);
    else if (action === "review") {
      const q = questions()[st.current];
      if (!q) return;
      if (st.review[q.id]) {
        delete st.review[q.id];
        writeStore();
        render();
      } else {
        st.review[q.id] = true;
        go(st.current + 1);
      }
    }
    else if (action === "retake") {
      st.result = null;
      st.summary = null;
      st.attemptId = null;
      st.durationMinutes = null;
      st.answers = {};
      st.review = {};
      st.visited = {};
      st.current = 0;
      st.error = "";
      st.screen = "intro";
      render();
      window.scrollTo(0, 0);
    } else if (action === "clear") {
      const id = target.dataset.id;
      delete st.answers[id];
      const card = document.getElementById("pr-q-" + id);
      if (card) {
        card.querySelectorAll("input[data-choice]").forEach((input) => {
          input.checked = false;
          input.closest("label").style.cssText = optionLabelStyle(false);
        });
        card.querySelectorAll("input[data-text],input[data-number]").forEach((input) => (input.value = ""));
        const hint = card.querySelector("[data-hint]");
        if (hint) hint.textContent = "";
      }
      writeStore();
      refreshProgress();
    }
  }
  function onChange(ev) {
    const input = ev.target;
    if (input.id === "pr-time-select") {
      const custom = $("#pr-time-custom");
      if (custom) custom.hidden = input.value !== "custom";
      return;
    }
    const id = input.dataset && input.dataset.choice;
    if (!id) return;
    const picked = Array.from(
      document.querySelectorAll('input[data-choice="' + CSS.escape(id) + '"]:checked'),
    ).map((node) => Number(node.value));
    if (picked.length) st.answers[id] = { o: picked };
    else delete st.answers[id];
    document.querySelectorAll('input[data-choice="' + CSS.escape(id) + '"]').forEach((node) => {
      node.closest("label").style.cssText = optionLabelStyle(node.checked);
    });
    writeStore();
    refreshProgress();
  }
  function onInput(ev) {
    const input = ev.target;
    if (!input.dataset) return;
    if (input.dataset.text) {
      if (input.value.trim()) st.answers[input.dataset.text] = { t: input.value };
      else delete st.answers[input.dataset.text];
    } else if (input.dataset.number) {
      const id = input.dataset.number;
      const value = input.value.trim();
      if (value) st.answers[id] = { n: value };
      else delete st.answers[id];
      const hint = document.querySelector('[data-hint="' + CSS.escape(id) + '"]');
      if (hint)
        hint.textContent =
          value && !Number.isFinite(Number(value)) ? "Enter a number, for example 12 or 0.75." : "";
    } else return;
    writeStore();
    refreshProgress();
  }

  async function boot() {
    const reactRoot = document.getElementById("root");
    if (reactRoot) reactRoot.style.display = "none";
    if (!token()) return signIn();
    shell();
    render();
    try {
      const data = await request("/quizzes/" + quizId);
      st.quiz = data.quiz || data;
      if (!Array.isArray(st.quiz.questions)) st.quiz.questions = [];
      st.screen = "intro";
      render();
      // A paper already in progress in this browser opens straight back into the room.
      if (readStore()) start();
    } catch (e) {
      if (e.status === 402) return showPurchase(e);
      st.blocked = {
        eyebrow: "PAPER UNAVAILABLE",
        title: e.status === 404 ? "This paper could not be found" : "Could not open this paper",
        text:
          e.status === 404
            ? "It may have been removed or is not published yet."
            : e.message || "Check your connection and try again.",
        href: "/papers",
        cta: "Back to papers",
        retry: e.status !== 404,
      };
      st.screen = "blocked";
      render();
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
