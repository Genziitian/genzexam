/*
 * Self-paced paper room.
 *
 * Papers open here in the same layout as the online exam room, but nothing is
 * proctored: no fullscreen, no focus tracking, no shared clock and no manager.
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
    answers: {},
    confirming: false,
    busy: false,
    submitError: "",
    summary: null,
    result: null,
    ticker: null,
  };

  const $ = (s, root = document) => root.querySelector(s);
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
        JSON.stringify({ attemptId: st.attemptId, startedAt: st.startedAt, answers: st.answers }),
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
    const response = await fetch(API + url, {
      signal: AbortSignal.timeout(25000),
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        Authorization: "Bearer " + token(),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
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
    if (window.QLStorefront && window.QLStorefront.signIn) window.QLStorefront.signIn(quizId);
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
  const limitSeconds = () => Math.max(0, Number((st.quiz && st.quiz.time_limit_minutes) || 0)) * 60;
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
      node.textContent = clock(left);
      node.classList.toggle("pr-low", left <= 60);
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
      '<div class="ep-shell"><header class="ep-top"><a class="ep-brand" href="/papers"><span class="ep-mark">QL</span><span><b>Quiz LAB</b><small>Paper room</small></span></a><div class="ep-user"><span>' +
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
        "</dd></div></dl><p>" +
        (minutes
          ? "This paper is self-paced: start whenever you are ready. The timer begins when you start, keeps running if you leave the page, and the paper is submitted automatically when time runs out."
          : "This paper is self-paced and untimed. Start whenever you are ready and submit when you are done.") +
        '</p><div class="ep-alert">This is a practice attempt. Nothing is monitored. Your answers are kept in this browser until you submit.</div>' +
        (st.error ? '<div class="ep-alert error" role="alert">' + esc(st.error) + "</div>" : "") +
        '<div class="ep-actions"><a class="ep-btn pr-btn-link" href="/papers">Back to papers</a><button class="ep-btn ep-btn-primary" data-action="start"' +
        (st.busy || !count ? " disabled" : "") +
        ">" +
        (st.busy ? "Starting…" : saved ? "Resume paper" : "Start paper") +
        "</button></div></div>",
      true,
    );
  }
  function questionCard(q, number) {
    const a = st.answers[q.id] || {};
    let input = "";
    if (CHOICE.includes(q.type)) {
      const multi = q.type === "multi_select";
      const chosen = (Array.isArray(a.o) ? a.o : []).map(String);
      input = (q.options || [])
        .map(
          (o) =>
            '<label class="ep-answer"><input type="' +
            (multi ? "checkbox" : "radio") +
            '" name="answer-' +
            esc(q.id) +
            '" data-choice="' +
            esc(q.id) +
            '" value="' +
            esc(o.id) +
            '"' +
            (chosen.includes(String(o.id)) ? " checked" : "") +
            ' /><span class="pr-option">' +
            optionHtml(o) +
            "</span></label>",
        )
        .join("");
      if (multi) input = '<p class="ep-muted">Select all that apply.</p>' + input;
    } else if (q.type === "comprehension") {
      input = '<p class="ep-muted">This passage is provided for the questions that follow.</p>';
    } else if (q.type === "numerical") {
      input =
        '<label class="ep-answer ep-answer-text"><span>Your answer (a number)</span><input class="pr-number" type="text" inputmode="decimal" autocomplete="off" maxlength="40" data-number="' +
        esc(q.id) +
        '" value="' +
        esc(a.n == null ? "" : a.n) +
        '" /></label><p class="pr-hint" data-hint="' +
        esc(q.id) +
        '" role="alert"></p>';
    } else {
      input =
        '<label class="ep-answer ep-answer-text"><span>Your response</span><textarea rows="2" maxlength="2000" data-text="' +
        esc(q.id) +
        '">' +
        esc(a.t == null ? "" : a.t) +
        "</textarea></label>";
    }
    const context = q.type === "comprehension";
    return (
      '<article class="ep-question" id="pr-q-' +
      esc(q.id) +
      '"><header><span>' +
      (context ? "Context" : "Question " + number) +
      "</span><span>" +
      (context ? "" : Number(q.marks || 0) + " marks") +
      '</span></header><div class="ep-question-prompt">' +
      stemHtml(q) +
      "</div>" +
      input +
      (context
        ? ""
        : '<button class="ep-btn ep-btn-quiet" data-action="clear" data-id="' +
          esc(q.id) +
          '">Clear answer</button>') +
      "</article>"
    );
  }
  function navHtml() {
    let number = 0;
    return answerable()
      .map((q) => {
        number += 1;
        return (
          '<a class="pr-nav-item' +
          (isAnswered(q) ? " done" : "") +
          '" href="#pr-q-' +
          esc(q.id) +
          '" data-nav="' +
          esc(q.id) +
          '" aria-label="Question ' +
          number +
          (isAnswered(q) ? ", answered" : ", not answered") +
          '">' +
          number +
          "</a>"
        );
      })
      .join("");
  }
  function barHtml() {
    const total = answerable().length;
    const left = total - answeredCount();
    if (st.confirming)
      return (
        '<span class="ep-save-state" role="alert">' +
        (left
          ? left + " question" + (left === 1 ? " is" : "s are") + " unanswered. "
          : "All questions answered. ") +
        'Submit now? You cannot change answers afterwards.</span><span class="pr-bar-actions"><button class="ep-btn" data-action="cancel-submit"' +
        (st.busy ? " disabled" : "") +
        '>Keep working</button><button class="ep-btn ep-btn-primary" data-action="confirm-submit"' +
        (st.busy ? " disabled" : "") +
        ">" +
        (st.busy ? "Submitting…" : "Submit now") +
        "</button></span>"
      );
    return (
      '<span class="ep-save-state' +
      (st.submitError ? " pr-error" : "") +
      '" id="ep-save-state">' +
      esc(st.submitError || "Answers are kept in this browser until you submit") +
      '</span><button class="ep-btn ep-btn-primary" data-action="submit"' +
      (st.busy ? " disabled" : "") +
      ">Submit paper</button>"
    );
  }
  function roomView() {
    const q = st.quiz;
    let number = 0;
    const left = remaining();
    return (
      '<section class="ep-room"><header class="ep-room-head"><div><p class="ep-eyebrow">PAPER IN PROGRESS</p><h1>' +
      esc(q.title) +
      '</h1></div><div class="ep-room-meta"><span id="pr-answered">Answered ' +
      answeredCount() +
      "/" +
      answerable().length +
      '</span><strong id="ep-countdown">' +
      (left == null ? "Untimed" : clock(left)) +
      '</strong></div></header><nav class="pr-nav" id="pr-nav" aria-label="Questions">' +
      navHtml() +
      '</nav><div class="ep-questions">' +
      questions()
        .map((item) => questionCard(item, item.type === "comprehension" ? 0 : ++number))
        .join("") +
      '</div><div class="ep-submit-bar" id="pr-bar">' +
      barHtml() +
      "</div></section>"
    );
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
      '<div class="ep-actions"><a class="ep-btn pr-btn-link" href="/papers">Back to papers</a><a class="ep-btn pr-btn-link" href="/dashboard">Dashboard</a><button class="ep-btn ep-btn-primary" data-action="retake">Attempt again</button></div></div>' +
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
    document.title = (st.quiz && st.quiz.title ? st.quiz.title + " · " : "") + "Paper room · Quiz LAB";
  }
  function refreshProgress() {
    const counter = $("#pr-answered");
    if (counter) counter.textContent = "Answered " + answeredCount() + "/" + answerable().length;
    const nav = $("#pr-nav");
    if (nav) nav.innerHTML = navHtml();
  }
  function refreshBar() {
    const bar = $("#pr-bar");
    if (bar) bar.innerHTML = barHtml();
  }

  /* ---------------------------- actions ---------------------------- */
  async function start() {
    if (st.busy) return;
    st.busy = true;
    st.error = "";
    render();
    try {
      const data = await request("/quizzes/" + quizId + "/attempts", { method: "POST" });
      const attemptId = data.attempt_id || (data.attempt && data.attempt.id) || data.id;
      if (!attemptId) throw new Error("Could not start this paper. Please try again.");
      const saved = readStore();
      st.attemptId = attemptId;
      if (saved && String(saved.attemptId) === String(attemptId)) {
        st.startedAt = Number(saved.startedAt) || Date.now();
        st.answers = saved.answers && typeof saved.answers === "object" ? saved.answers : {};
      } else {
        st.startedAt = Date.now();
        st.answers = {};
      }
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
          " Your answers are still here. Press Submit paper to retry.";
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
      title: "This paper is not in your library",
      text: (e && e.message) || "Buy or renew this paper to open it.",
      href: "/papers?paper=" + quizId,
      cta: "View paper",
    };
    st.screen = "blocked";
    render();
  }
  function onClick(ev) {
    const target = ev.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    if (action === "start") start();
    else if (action === "reload") location.reload();
    else if (action === "submit") {
      st.confirming = true;
      st.submitError = "";
      refreshBar();
    } else if (action === "cancel-submit") {
      st.confirming = false;
      refreshBar();
    } else if (action === "confirm-submit") submit(false);
    else if (action === "retake") {
      st.result = null;
      st.summary = null;
      st.attemptId = null;
      st.answers = {};
      st.error = "";
      st.screen = "intro";
      render();
      window.scrollTo(0, 0);
    } else if (action === "clear") {
      const id = target.dataset.id;
      delete st.answers[id];
      const card = document.getElementById("pr-q-" + id);
      if (card) {
        card.querySelectorAll("input[data-choice]").forEach((input) => (input.checked = false));
        card.querySelectorAll("textarea,input[data-number]").forEach((input) => (input.value = ""));
        const hint = card.querySelector("[data-hint]");
        if (hint) hint.textContent = "";
      }
      writeStore();
      refreshProgress();
    }
  }
  function onChange(ev) {
    const input = ev.target;
    const id = input.dataset && input.dataset.choice;
    if (!id) return;
    const picked = Array.from(
      document.querySelectorAll('input[data-choice="' + CSS.escape(id) + '"]:checked'),
    ).map((node) => Number(node.value));
    if (picked.length) st.answers[id] = { o: picked };
    else delete st.answers[id];
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
