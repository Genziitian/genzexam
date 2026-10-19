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
    showReview: false,
    reviewIndex: 0,
    practice: false,
    key: null,
    keyLoading: false,
    revealed: {},
    explained: {},
    pt: { left: 0, endsAt: 0, running: false, finished: false },
    ptTicker: null,
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
    let text = String(value == null ? "" : value);
    if (/```|!\[[^\n]*?\]\(/.test(text)) return text.trim();
    text = text.replace(/\\r\\n/g, "\n").replace(/\\n(?![a-zA-Z])/g, "\n");
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
    else if (path.startsWith("/assets/"))
      url = (typeof location !== "undefined" && location.origin ? location.origin : "https://quiz.genziitian.in") + path;
    else if (path.startsWith("/public/")) url = API_ORIGIN + path;
    else if (path.startsWith("/storage/")) url = API_ROOT + path;
    else if (path.startsWith("/question-images/") || path.startsWith("/avatars/"))
      url = API_ROOT + "/storage" + path;
    else if (path.startsWith("/")) url = API_ORIGIN + path;
    else if (path.startsWith("assets/"))
      url = (typeof location !== "undefined" && location.origin ? location.origin : "https://quiz.genziitian.in") + "/" + path;
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
  function extractProcedureSteps(rawText) {
    const text = String(rawText || "");
    const matches = Array.from(text.matchAll(/\b(Step\s*\d+\s*[:.-])\s*/gi));
    if (matches.length < 2 || !/^step\s*1\b/i.test(matches[0][1].trim())) {
      return null;
    }
    const intro = text.slice(0, matches[0].index).trim();
    const steps = [];
    let outro = "";
    for (let i = 0; i < matches.length; i++) {
      const m = matches[i];
      const stepNumMatch = m[1].match(/\d+/);
      const stepNum = stepNumMatch ? stepNumMatch[0] : String(i + 1);
      const header = "Step " + stepNum + ":";
      if (i + 1 < matches.length) {
        const nextM = matches[i + 1];
        const body = text.slice(m.index + m[0].length, nextM.index).trim();
        steps.push(header + " " + body);
      } else {
        const fullLast = text.slice(m.index + m[0].length).trim();
        const outroM = fullLast.match(/(?:(?<=\brepeat from step \d)|(?<=\brepeat from step \d\.)|(?<=\bstop the iteration)|(?<=\.))\s+(The value of\b.*|What will\b.*|It is a\b.*)/i);
        if (outroM && outroM.index != null) {
          const body = fullLast.slice(0, outroM.index).trim();
          outro = fullLast.slice(outroM.index).trim();
          steps.push(header + " " + body);
        } else {
          steps.push(header + " " + fullLast);
        }
      }
    }
    return {
      intro: intro,
      code: steps.join("\n"),
      outro: outro
    };
  }
  function stemHtml(q) {
    const image = imageUrl(q.stem_image);
    let stemText = q.stem != null ? q.stem : q.question_stem;
    let code = q.stem_code;
    let lang = q.stem_code_language || "pseudocode";
    let outro = "";

    if (!code && stemText && !/```|!\[[^\n]*?\]\(/.test(stemText)) {
      const parsed = extractProcedureSteps(clean(stemText));
      if (parsed) {
        stemText = parsed.intro;
        code = parsed.code;
        outro = parsed.outro;
      }
    }

    return (
      rich(clean(stemText)) +
      (code ? codeBlock(code, lang) : "") +
      (outro ? rich(clean(outro)) : "") +
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
    if (/```|!\[[^\n]*?\]\(/.test(t)) return false;
    if (/\$|\\\(|\\\[|\$\$|\\[a-zA-Z]+/.test(t)) return false;
    if (/\bfor\s+(?:all|each)\b/i.test(t)) return false;
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
      if (dot) dot.style.background = low ? "#ef4444" : "#3a3fd8";
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
      '<div class="ep-shell"><header class="ep-top"><a class="ep-brand" href="/my-papers"><img class="ep-mark" src="/assets/quiz-lab-icon.png" alt="" width="36" height="36"><span><b>Quiz LAB</b><small>Paper room</small></span></a><div class="ep-user"><span>' +
      esc(userName()) +
      '</span><a class="ep-link" href="/my-papers">Back</a></div></header><div id="ep-content"></div></div>';
    root.addEventListener("click", onClick);
    root.addEventListener("change", onChange);
    root.addEventListener("input", onInput);
    root.addEventListener("keydown", function (ev) {
      if (ev.key === "Enter" && ev.target && ev.target.id === "pt-min") { ev.preventDefault(); ptStart(); }
    });
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
    const timeOption = (value, label, extraClass) =>
      '<label class="pr-time-opt' + (extraClass ? " " + extraClass : "") + '"><input type="radio" name="pr-time" value="' + value + '"' + (selectedTime === String(value) ? " checked" : "") + "><span>" + label + "</span></label>";
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
          : '<div class="pr-time-choice"><b>Set your time limit</b><input type="hidden" id="pr-time-select" value="' + esc(selectedTime) + '"><div class="pr-time-opts" role="radiogroup" aria-label="Time limit">' +
            timeOption("default", "Default · " + (minutes ? minutes + " min" : "Untimed"), "pr-time-opt-default") +
            (minutes ? timeOption(0, "Untimed") : "") +
            timeOption(15, "15 min") +
            timeOption(30, "30 min") +
            timeOption(45, "45 min") +
            timeOption(60, "60 min") +
            timeOption("custom", "Custom") +
            '</div><input id="pr-time-custom" type="number" min="1" max="600" placeholder="Custom minutes (1–600)" value="' +
            (selectedTime === "custom" ? String(st.durationMinutes) : "") +
            '"' + (selectedTime === "custom" ? "" : " hidden") + '></div>') +
        "<p>" +
        (minutes
          ? "This paper is self-paced: start whenever you are ready. The timer begins when you start, keeps running if you leave the page, and the paper is submitted automatically when time runs out."
          : "This paper is self-paced and untimed. Start whenever you are ready and submit when you are done.") +
        '</p>' +
        (st.error ? '<div class="ep-alert error" role="alert">' + esc(st.error) + "</div>" : "") +
        '<div class="ep-actions"><a class="ep-btn pr-btn-link" data-back href="' + esc(backHref()) + '">Back</a><button class="ep-btn ep-btn-primary" data-action="start"' +
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
      (checked ? "#3a3fd8" : "#e2e8f0") +
      ";background:" +
      (checked ? "#f1f2ff" : "#ffffff") +
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
              ' style="width:16px;height:16px;accent-color:#3a3fd8;flex-shrink:0;" /><span class="pr-option" style="font-size:14px;color:#1e293b;font-weight:500;min-width:0;flex:1;">' +
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
      row("#dcdeff", "#a9acf0", "Answered (" + answered + ")") +
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
      (quiz.can_share === false || quiz.is_personal ? '' : '<button type="button" class="ql-share-btn ql-share-icon" data-ql-share="' + esc(String(quiz.id || (location.pathname.match(/\d+/) || [""])[0])) + '" data-ql-share-title="' + esc(quiz.title || "") + '" aria-label="Share link to this paper" title="Share link"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></svg><span>Share</span></button>') +
      '<div style="display:flex;align-items:center;gap:6px;background:#f1f5f9;padding:6px 12px;border-radius:8px;border:1px solid #cbd5e1;"><span id="pr-timer-dot" style="width:8px;height:8px;border-radius:9999px;background:' +
      (low ? "#ef4444" : "#3a3fd8") +
      ';animation:ep-pulse 2s infinite;"></span><span class="pr-live-time-label" style="font-size:11px;font-weight:700;color:#64748b;">Time:</span><span id="ep-countdown" style="font-size:15px;font-weight:800;color:' +
      (low ? "#ef4444" : "#0f172a") +
      ';font-family:ui-monospace,monospace;">' +
      (left == null ? "Untimed" : timeText(left)) +
      "</span></div>" +
      '<button type="button" id="btn-student-submit" data-action="submit"' +
      (st.busy ? " disabled" : "") +
      ' style="background:#3a3fd8;border:none;color:#fff;padding:7px 18px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:6px;box-shadow:0 1px 3px rgba(58, 63, 216,0.3);transition:background 0.15s;">' +
      ICON_CHECK +
      (st.busy ? " Submitting…" : " Submit &amp; Exit") +
      "</button></div></header>" +
      '<div class="pr-live-body" style="display:flex;flex:1;overflow:hidden;">' +
      '<aside id="ep-sidebar" class="pr-live-aside" style="width:clamp(280px, 24vw, 380px);background:#ffffff;border-right:2px solid #0f172a;display:flex;flex-direction:column;flex-shrink:0;">' +
      '<div class="pr-live-palette" style="flex:1;overflow-y:auto;padding:16px;"><div class="pr-live-palette-title" style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:12px;">Question Palette</div><div class="ep-q-grid" id="pr-palette">' +
      paletteHtml() +
      "</div></div>" +
      '<div class="pr-live-tools-box" style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#ffffff;"><div id="pr-practice-box">' +
      practiceBoxHtml() +
      '</div><button type="button" data-calc="toggle" title="Open calculator" style="width:100%;background:#f1f2ff;border:1px solid #c9ccf5;color:#2a2fa8;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">Calculator</button></div>' +
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
      '<div style="display:flex;align-items:center;gap:10px;">' +
      '<button type="button" class="pr-report-btn" data-report="' + esc(String(q.id)) + '" data-report-no="' + (index + 1) + '" title="Report a problem with this question"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 22V4a1 1 0 011-1h12l-2 4 2 4H5"/></svg>Report</button>' +
      (passage
        ? ""
        : '<div style="font-size:12px;font-weight:700;color:#3a3fd8;">+' + Number(q.marks || 0) + " Marks</div>") +
      "</div>" +
      "</div>" +
      '<div class="pr-live-prompt" style="font-size:15px;color:#0f172a;line-height:1.6;font-weight:500;margin-bottom:14px;">' +
      stemHtml(q) +
      "</div>" +
      '<div style="margin-bottom:28px;" id="pr-q-' +
      esc(q.id) +
      '">' +
      inputsHtml(q) +
      "</div>" +
      '<div id="pr-explain-slot">' + explainHtml(q) + "</div>" +
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
      (passage || !st.practice
        ? ""
        : '<button type="button" id="btn-q-reveal" class="pr-reveal-btn" data-action="reveal" data-id="' + esc(q.id) + '">' + (st.revealed[q.id] ? "Hide answer" : "Reveal answer") + "</button>") +
      '</div><div style="display:flex;gap:8px;">' +
      (passage
        ? ""
        : '<button type="button" id="btn-q-review" data-action="review" style="background:#f5f3ff;border:1px solid #c4b5fd;color:#6d28d9;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">' +
          (st.review[q.id] ? 'Marked<span class="pr-wide"> for Review</span>' : 'Review<span class="pr-wide"> &amp; Next</span>') +
          "</button>") +
      '<button type="button" id="btn-q-save-next" data-action="next" style="background:#3a3fd8;color:#fff;border:none;padding:9px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">' +
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
      '. Once submitted, your answers are final and you will see your result.</p><div style="display:flex;gap:10px;"><button type="button" id="ep-btn-cancel-submit" style="flex:1;background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;padding:11px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">Return to Paper</button><button type="button" id="ep-btn-confirm-submit" style="flex:1.2;background:#3a3fd8;color:#ffffff;border:none;padding:11px;border-radius:8px;font-size:13px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">' +
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
    let num = 0;
    const qNums = answers.map((a) => (a.question_type === "comprehension" ? 0 : ++num));
    const idx = Math.min(Math.max(0, st.reviewIndex || 0), Math.max(0, answers.length - 1));
    const currentAnswer = answers[idx];
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
      '<div class="ep-actions pr-result-actions">' +
      '<a class="ep-btn pr-btn-link" data-back href="' + esc(backHref()) + '">Back</a>' +
      (answers.length
        ? '<button type="button" class="ep-btn" data-action="toggle-review">' +
          (st.showReview ? "Hide review" : "Review answers") +
          "</button>"
        : "") +
      '<button class="ep-btn ep-btn-primary" data-action="retake">Attempt again</button>' +
      "</div></div>" +
      (st.showReview && answers.length && currentAnswer
        ? '<div id="pr-review-section" class="pr-review-wrap">' +
          '<div class="pr-review-toolbar">' +
          '<h2 class="pr-review-title">Answer review</h2>' +
          '<span class="pr-review-counter">' +
          (currentAnswer.question_type === "comprehension"
            ? "Context passage"
            : "Question " + (qNums[idx] || idx + 1) + " of " + (scored.length || answers.length)) +
          "</span>" +
          "</div>" +
          (answers.length > 1
            ? '<div class="pr-review-strip">' +
              answers
                .map((a, i) => {
                  const chosen = (
                    Array.isArray(a.student_selected_option_ids)
                      ? a.student_selected_option_ids
                      : []
                  ).map(String);
                  const answered =
                    chosen.length > 0 ||
                    (a.student_text_answer != null &&
                      String(a.student_text_answer).trim() !== "") ||
                    a.student_numerical_answer != null;
                  const state =
                    a.question_type === "comprehension"
                      ? "ctx"
                      : a.is_correct
                        ? "correct"
                        : answered
                          ? "wrong"
                          : "skipped";
                  const label = a.question_type === "comprehension" ? "P" : qNums[i];
                  return (
                    '<button type="button" class="pr-review-tab' +
                    (i === idx ? " active" : "") +
                    " " +
                    state +
                    '" data-review-go="' +
                    i +
                    '" aria-label="' +
                    (a.question_type === "comprehension" ? "Passage" : "Question " + label) +
                    '">' +
                    label +
                    "</button>"
                  );
                })
                .join("") +
              "</div>"
            : "") +
          '<div class="ep-questions">' +
          reviewCard(currentAnswer, qNums[idx]) +
          "</div>" +
          '<div class="pr-review-nav">' +
          '<button type="button" class="ep-btn" data-action="review-prev"' +
          (idx === 0 ? " disabled" : "") +
          ">← Previous</button>" +
          '<button type="button" class="ep-btn ep-btn-primary" data-action="review-next"' +
          (idx === answers.length - 1 ? " disabled" : "") +
          ">Next →</button>" +
          "</div>" +
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
    if (st.practice && isMobileView()) { st.practice = false; stopPt(); }
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
    if (st.screen === "result" && st.showReview) {
      const activeTab = root.querySelector(".pr-review-tab.active");
      if (activeTab && typeof activeTab.scrollIntoView === "function") {
        activeTab.scrollIntoView({ block: "nearest", inline: "nearest" });
      }
    }
    const app = document.getElementById("ep-app");
    if (app) app.classList.toggle("pr-live", st.screen === "room");
    if (st.screen !== "room") stopPt();
    applyPractice();
    if (st.practice) ptPaint();
    if (st.screen !== "room" && window.ExamCalculator) window.ExamCalculator.close();
    document.title = (st.quiz && st.quiz.title ? st.quiz.title + " · " : "") + "Paper room · Quiz LAB";
  }
  // Back goes to the page the student came from; otherwise to the subject (or My papers).
  function backHref() {
    const slug = st.quiz && st.quiz.course && st.quiz.course.slug;
    return slug ? "/practice/" + encodeURIComponent(slug) : "/my-papers";
  }
  document.addEventListener("click", function (ev) {
    const link = ev.target.closest && ev.target.closest("a[data-back]");
    if (!link || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.button) return;
    let same = false;
    try { same = !!document.referrer && new URL(document.referrer).origin === location.origin && !/\/paper\/\d+/.test(document.referrer); } catch (_) {}
    if (same && history.length > 1) { ev.preventDefault(); history.back(); }
  });
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
      armBackTrap();
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
    st.showReview = false;
    st.reviewIndex = 0;
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
  const REPORT_REASONS = [
    ["wrong_question", "This question is wrong"],
    ["wrong_answer", "The correct answer is wrong"],
    ["wrong_format", "The format is wrong"],
    ["typo", "Typo or unclear wording"],
    ["missing_info", "Image, table or data is missing"],
    ["options_wrong", "Options are wrong or missing"],
    ["other", "Something else is wrong"],
  ];
  function reportModal(questionId, number) {
    const old = document.getElementById("pr-report-modal");
    if (old) old.remove();
    const modal = document.createElement("div");
    modal.id = "pr-report-modal";
    modal.innerHTML =
      '<form class="pr-report-card" role="dialog" aria-modal="true" aria-labelledby="pr-report-title">' +
      '<h2 id="pr-report-title">Report question ' + Number(number) + "</h2>" +
      "<p>What is wrong? Pick all that apply.</p>" +
      '<div class="pr-report-reasons">' +
      REPORT_REASONS.map((r) => '<label><input type="checkbox" name="reason" value="' + r[0] + '"><span>' + esc(r[1]) + "</span></label>").join("") +
      "</div>" +
      '<label class="pr-report-comment">Tell us more <small>(optional)</small><textarea name="comment" maxlength="1000" rows="3" placeholder="e.g. The answer should be 4, not 5"></textarea></label>' +
      '<p class="pr-report-error" role="alert" hidden></p>' +
      '<div class="pr-report-actions"><button type="button" data-close>Cancel</button><button type="submit" class="primary">Submit report</button></div>' +
      "</form>";
    document.body.appendChild(modal);
    const form = modal.querySelector("form");
    const err = modal.querySelector(".pr-report-error");
    const close = () => modal.remove();
    modal.addEventListener("click", (e) => { if (e.target === modal || e.target.closest("[data-close]")) close(); });
    modal.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const reasons = Array.from(form.querySelectorAll('input[name="reason"]:checked')).map((i) => i.value);
      if (!reasons.length) { err.textContent = "Pick at least one problem."; err.hidden = false; return; }
      const btn = form.querySelector("button.primary");
      btn.disabled = true; btn.textContent = "Sending…"; err.hidden = true;
      try {
        await request("/question-reports", { method: "POST", body: { question_id: Number(questionId), question_number: Number(number), reasons, comment: form.comment.value.trim() || null } });
        form.innerHTML = '<h2>Thanks, report sent</h2><p>Our team will check question ' + Number(number) + ' and fix it if needed.</p><div class="pr-report-actions"><button type="button" class="primary" data-close>Back to the paper</button></div>';
      } catch (ex) {
        err.textContent = ex.message || "Could not send the report. Try again."; err.hidden = false;
        btn.disabled = false; btn.textContent = "Submit report";
      }
    });
    const first = form.querySelector("input");
    if (first) first.focus();
  }
  function onClick(ev) {
    const rep = ev.target.closest("[data-report]");
    if (rep) return void reportModal(rep.dataset.report, rep.dataset.reportNo);
    const jump = ev.target.closest("[data-go]");
    if (jump) return void go(Number(jump.dataset.go));
    const rJump = ev.target.closest("[data-review-go]");
    if (rJump) {
      st.reviewIndex = Number(rJump.dataset.reviewGo);
      render();
      const reviewEl = document.getElementById("pr-review-section");
      if (reviewEl) reviewEl.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }
    const calc = ev.target.closest("[data-calc]");
    if (calc) return void (window.ExamCalculator && window.ExamCalculator.toggle(calc.dataset.calc === "toggle" ? undefined : calc.dataset.calc));
    const target = ev.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    if (action === "practice-toggle") togglePractice();
    else if (action === "pt-start") ptStart();
    else if (action === "pt-add") ptAdd(Number(target.dataset.min));
    else if (action === "pt-pause") ptPause();
    else if (action === "pt-reset") ptReset();
    else if (action === "reveal") revealAnswer(target.dataset.id);
    else if (action === "explain") toggleExplain(target.dataset.id);
    else if (action === "start") start();
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
      st.showReview = false;
      st.reviewIndex = 0;
      st.screen = "intro";
      render();
      window.scrollTo(0, 0);
    } else if (action === "toggle-review") {
      st.showReview = !st.showReview;
      st.reviewIndex = 0;
      render();
      if (st.showReview) {
        const reviewEl = document.getElementById("pr-review-section");
        if (reviewEl) reviewEl.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    } else if (action === "review-prev") {
      if (st.reviewIndex > 0) {
        st.reviewIndex--;
        render();
        const reviewEl = document.getElementById("pr-review-section");
        if (reviewEl) reviewEl.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    } else if (action === "review-next") {
      const answers = (st.result && Array.isArray(st.result.answers)) ? st.result.answers : [];
      if (st.reviewIndex < answers.length - 1) {
        st.reviewIndex++;
        render();
        const reviewEl = document.getElementById("pr-review-section");
        if (reviewEl) reviewEl.scrollIntoView({ behavior: "smooth", block: "start" });
      }
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
    if (input.name === "pr-time") {
      const hiddenSel = $("#pr-time-select");
      if (hiddenSel) hiddenSel.value = input.value;
      const custom = $("#pr-time-custom");
      if (custom && input.value === "custom") setTimeout(() => custom.focus(), 0);
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

  /* ---------------------------- practice mode ----------------------------
   * Practice mode adds a self-set countdown dial, a "Reveal answer" button and (when the question has one)
   * an explanation. The answer key is fetched once from /quizzes/:id/practice-answers. */
  // Practice mode is desktop-only: hidden on phones, in the app's web view and at narrow widths.
  const isMobileView = () => window.matchMedia("(max-width: 820px)").matches || /Android|iPhone|iPod|Mobile|; wv\)/i.test(navigator.userAgent);
  const leavePracticeIfMobile = function () {
    if (st.practice && isMobileView()) { st.practice = false; stopPt(); writeStore(); render(); }
  };
  window.addEventListener("resize", leavePracticeIfMobile);
  window.matchMedia("(max-width: 820px)").addEventListener("change", leavePracticeIfMobile);
  const PT_MAX = 120 * 60;
  const pad2 = (n) => String(n).padStart(2, "0");
  function ptLeft() {
    return st.pt.running ? Math.max(0, Math.ceil((st.pt.endsAt - Date.now()) / 1000)) : st.pt.left;
  }
  function ptText(left) {
    return pad2(Math.floor(left / 3600)) + ":" + pad2(Math.floor((left % 3600) / 60)) + ":" + pad2(left % 60);
  }
  function ptPaint() {
    const left = ptLeft();
    const part = (id, v) => { const n = document.getElementById(id); if (n) n.textContent = pad2(v); };
    part("pt-d-m", Math.floor(left / 60)); // minutes go up to 120, so no hour box
    part("pt-d-s", left % 60);
    const d = document.getElementById("pt-digital");
    if (d) d.classList.toggle("up", st.pt.finished);
    const note = document.getElementById("pt-note");
    if (note) note.textContent = st.pt.finished ? "Time is up" : st.pt.running ? "Counting down" : st.pt.left > 0 ? "Paused" : "Set a time to begin";
  }
  function practiceBoxHtml() {
    if (!st.practice) return isMobileView() ? "" : '<button type="button" class="pr-mode-btn" data-action="practice-toggle">Go to practice mode</button>';
    // Minutes field until a time is set; then the +5/+10/+15 buttons and pause/reset take its place.
    const set = st.pt.running || st.pt.left > 0;
    const seg = (id, label) => '<div class="pr-seg"><span id="' + id + '">00</span><small>' + label + "</small></div>";
    return (
      '<div class="pr-pt-card">' +
      '<div class="pr-digital" id="pt-digital">' + seg("pt-d-m", "MIN") + "<i>:</i>" + seg("pt-d-s", "SEC") + "</div>" +
      '<div class="pr-pt-note" id="pt-note"></div>' +
      (set
        ? '<div class="pr-pt-chips"><button type="button" class="pr-pt-btn" data-action="pt-add" data-min="5">+5 min</button><button type="button" class="pr-pt-btn" data-action="pt-add" data-min="10">+10 min</button><button type="button" class="pr-pt-btn" data-action="pt-add" data-min="15">+15 min</button></div>' +
          '<div class="pr-pt-row"><button type="button" class="pr-pt-btn" data-action="pt-pause" style="flex:1">' + (st.pt.running ? "Pause" : "Resume") + '</button><button type="button" class="pr-pt-btn" data-action="pt-reset" style="flex:1">Reset</button></div>'
        : '<div class="pr-pt-row"><input type="number" id="pt-min" min="1" max="120" inputmode="numeric" placeholder="Minutes (1-120)" aria-label="Minutes, up to 120"><button type="button" class="pr-pt-btn primary" data-action="pt-start">Start</button></div>') +
      '</div><button type="button" class="pr-mode-btn on" data-action="practice-toggle">Exit practice mode</button>'
    );
  }
  function refreshPractice() {
    const box = document.getElementById("pr-practice-box");
    if (box) box.innerHTML = practiceBoxHtml();
    ptPaint();
  }
  function startPt() {
    stopPt();
    st.ptTicker = setInterval(function () {
      if (st.screen !== "room") return stopPt();
      if (st.pt.running && ptLeft() <= 0) { st.pt.running = false; st.pt.left = 0; st.pt.finished = true; refreshPractice(); }
      ptPaint();
    }, 1000);
  }
  function stopPt() { clearInterval(st.ptTicker); st.ptTicker = null; }
  function ptSet(seconds) {
    st.pt.left = Math.min(PT_MAX, Math.max(0, seconds));
    st.pt.endsAt = Date.now() + st.pt.left * 1000;
    st.pt.running = st.pt.left > 0;
    st.pt.finished = false;
    refreshPractice();
  }
  function ptStart() {
    const input = document.getElementById("pt-min");
    const minutes = Math.floor(Number(input && input.value));
    if (!minutes || minutes < 1) { if (input) input.focus(); return; }
    ptSet(Math.min(120, minutes) * 60);
    if (input) input.value = "";
  }
  function ptAdd(minutes) { ptSet(Math.min(PT_MAX, ptLeft() + minutes * 60)); }
  function ptPause() {
    if (st.pt.running) { st.pt.left = ptLeft(); st.pt.running = false; }
    else if (st.pt.left > 0) { st.pt.endsAt = Date.now() + st.pt.left * 1000; st.pt.running = true; }
    refreshPractice();
  }
  function ptReset() { st.pt = { left: 0, endsAt: 0, running: false, finished: false }; refreshPractice(); }
  async function loadKey() {
    if (st.key || st.keyLoading) return;
    st.keyLoading = true;
    try {
      const data = await request("/quizzes/" + quizId + "/practice-answers");
      st.key = data && data.answers && !Array.isArray(data.answers) ? data.answers : {};
    } catch (e) {
      st.submitError = "Could not load answers: " + (e.message || "try again");
      const err = $("#pr-error");
      if (err) { err.textContent = st.submitError; err.hidden = false; }
    }
    st.keyLoading = false;
  }
  async function togglePractice() {
    st.practice = !st.practice;
    if (st.practice) { startPt(); await loadKey(); } else stopPt();
    render();
    if (st.practice) ptPaint();
  }
  async function revealAnswer(id) {
    await loadKey();
    if (!st.key || !st.key[id]) return;
    st.revealed[id] = !st.revealed[id];
    if (!st.revealed[id]) st.explained[id] = false;
    const q0 = questions()[st.current];
    if (q0 && String(q0.id) === String(id)) syncExplain(q0);
    const btn = document.getElementById("btn-q-reveal");
    if (btn) btn.textContent = st.revealed[id] ? "Hide answer" : "Reveal answer";
    applyPractice();
  }
  function explainHtml(q) {
    if (!st.practice || !st.key || !st.revealed[q.id]) return "";
    const k = st.key[q.id];
    const text = k && clean(k.explanation);
    if (!text) return "";
    const open = !!st.explained[q.id];
    return (
      '<div class="pr-explain"><button type="button" class="pr-explain-btn" data-action="explain" data-id="' + esc(q.id) + '">' + (open ? "Hide explanation" : "See explanation") + "</button>" +
      (open ? '<div class="pr-explain-box">' + rich(text) + "</div>" : "") +
      "</div>"
    );
  }
  function toggleExplain(id) {
    st.explained[id] = !st.explained[id];
    const q = questions()[st.current];
    if (q) syncExplain(q);
  }
  // The explanation area is re-drawn on its own so the page does not jump.
  function syncExplain(q) {
    const slot = document.getElementById("pr-explain-slot");
    if (!slot) return;
    slot.innerHTML = explainHtml(q);
    if (window.ExamRichContent && window.ExamRichContent.typeset) window.ExamRichContent.typeset(slot);
  }
  // Marks the correct option(s) green, or shows the numeric / short answer, for the question on screen.
  function applyPractice() {
    if (st.screen !== "room" || !st.practice || !st.key) return;
    const q = questions()[st.current];
    const k = q && st.key[q.id];
    const box = q && document.getElementById("pr-q-" + q.id);
    if (!k || !box) return;
    box.querySelectorAll(".pr-key").forEach((n) => n.remove());
    box.querySelectorAll(".pr-correct").forEach((n) => n.classList.remove("pr-correct"));
    if (!st.revealed[q.id]) return;
    if (CHOICE.includes(q.type)) {
      const correct = (k.correct_option_ids || []).map(String);
      box.querySelectorAll("input[data-choice]").forEach((input) => {
        if (correct.includes(input.value)) input.closest("label").classList.add("pr-correct");
      });
    } else if (q.type === "numerical" && k.numerical_answer != null && k.numerical_answer !== "") {
      const tol = Number(k.numerical_tolerance || 0);
      box.insertAdjacentHTML("beforeend", '<div class="pr-key">Correct answer: ' + esc(String(k.numerical_answer)) + (tol ? " (accepted within ±" + esc(String(tol)) + ")" : "") + "</div>");
    } else if (q.type === "short_answer" && (k.short_answers || []).length) {
      box.insertAdjacentHTML("beforeend", '<div class="pr-key">Correct answer: ' + k.short_answers.map((a) => esc(String(a))).join(" / ") + "</div>");
    }
  }

  /* ---------------- leaving the room with the Back button ----------------
   * While a paper is being attempted, Back asks whether to save and exit or keep solving.
   * An extra history entry is pushed so the first Back press only opens the question. */
  let trapOn = false, leaving = false;
  function armBackTrap() {
    if (trapOn) return;
    trapOn = true;
    history.pushState({ prRoom: 1 }, "");
  }
  window.addEventListener("popstate", function () {
    if (!trapOn || leaving) return;
    if (st.screen !== "room") { trapOn = false; history.back(); return; }
    history.pushState({ prRoom: 1 }, "");
    leaveModal();
  });
  function leaveRoom() {
    leaving = true;
    stopTicker();
    writeStore();
    history.go(-2);
    setTimeout(function () { location.href = backHref(); }, 600);
  }
  function leaveModal() {
    if (document.getElementById("pr-leave-modal")) return;
    const modal = document.createElement("div");
    modal.id = "pr-leave-modal";
    modal.style.cssText = "display:flex;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(15,23,42,0.8);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);z-index:999999;align-items:center;justify-content:center;padding:20px;";
    modal.innerHTML =
      '<div role="dialog" aria-modal="true" aria-labelledby="pr-leave-title" style="max-width:460px;width:100%;text-align:center;background:#ffffff;border-radius:20px;box-shadow:0 25px 60px -15px rgba(0,0,0,0.3);padding:30px 24px;color:#0f172a;">' +
      '<h2 id="pr-leave-title" style="font-size:20px;font-weight:800;margin:0 0 8px 0;">Leave this paper?</h2>' +
      '<p style="font-size:13.5px;color:#475569;margin:0 0 18px 0;line-height:1.55;">You have answered <b>' + answeredCount() + " of " + answerable().length + '</b> questions. Save and exit keeps your answers on this device so you can continue later.</p>' +
      '<div style="display:flex;flex-direction:column;gap:10px;">' +
      '<button type="button" id="pr-leave-save" style="background:#3a3fd8;color:#ffffff;border:none;padding:12px;border-radius:8px;font-size:13px;font-weight:800;cursor:pointer;">Save and exit</button>' +
      '<button type="button" id="pr-leave-stay" style="background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;padding:11px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">Keep solving</button>' +
      "</div></div>";
    document.body.appendChild(modal);
    const close = () => modal.remove();
    modal.addEventListener("click", (ev) => { if (ev.target === modal) close(); });
    modal.addEventListener("keydown", (ev) => { if (ev.key === "Escape") close(); });
    document.getElementById("pr-leave-stay").onclick = close;
    document.getElementById("pr-leave-save").onclick = () => { close(); leaveRoom(); };
    document.getElementById("pr-leave-stay").focus();
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
        cta: "Back",
        retry: e.status !== 404,
      };
      st.screen = "blocked";
      render();
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
