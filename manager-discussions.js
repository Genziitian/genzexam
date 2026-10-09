/*
 * Manager discussions: browse every thread, reply as the manager, and remove
 * threads or replies. Uses the same discussion API as the student app; the
 * server only lets managers delete other people's posts.
 */
(function () {
  "use strict";

  const API = (
    (window.QLStorefront && window.QLStorefront.apiBase) ||
    "https://labapi.genziitian.in/public/api"
  ).replace(/\/+$/, "");
  const $ = (id) => document.getElementById(id);
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
      (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
    );
  const st = { threads: [], selected: null, thread: null, loadingList: false, armed: "", searchTimer: null, toastTimer: null };

  function token() {
    try {
      return localStorage.getItem("lab_token") || "";
    } catch (_) {
      return "";
    }
  }
  async function api(path, method, body) {
    const response = await fetchWithTimeout(API + path, {
      method: method || "GET",
      headers: {
        Accept: "application/json",
        ...(body ? { "Content-Type": "application/json" } : {}),
        Authorization: "Bearer " + token(),
      },
      body: body ? JSON.stringify(body) : undefined,
    }, 25000);
    let data = null;
    try {
      data = await response.json();
    } catch (_) {}
    if (response.status === 401) {
      location.assign("/login");
      throw new Error("Your session expired. Sign in again.");
    }
    if (!response.ok) {
      const errors = data && data.errors ? Object.values(data.errors).flat().join(" ") : "";
      const error = new Error(
        errors || (data && (data.message || (typeof data.error === "string" && data.error))) || "Request failed (" + response.status + ")",
      );
      error.status = response.status;
      throw error;
    }
    return data == null ? {} : data;
  }
  function toast(text, error) {
    const node = $("toast");
    node.textContent = text;
    node.className = "show" + (error ? " error" : "");
    clearTimeout(st.toastTimer);
    st.toastTimer = setTimeout(() => (node.className = ""), 4500);
  }
  function ago(value) {
    if (!value) return "";
    const seconds = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 1000));
    if (seconds < 60) return "just now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return minutes + "m ago";
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h ago";
    const days = Math.floor(hours / 24);
    if (days < 30) return days + "d ago";
    return new Date(value).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
  }
  function roleTag(author) {
    if (!author) return "";
    if (author.role === "manager") return '<span class="tag manager">Manager</span>';
    if (author.role === "admin" || author.is_admin) return '<span class="tag teacher">Teacher</span>';
    return "";
  }
  function authorHtml(author) {
    const name = (author && author.name) || "Unknown";
    return (
      '<span class="author"><span class="avatar" aria-hidden="true">' +
      esc(name.trim().charAt(0).toUpperCase() || "?") +
      "</span><b>" +
      esc(name) +
      "</b>" +
      roleTag(author) +
      (author && author.is_anonymous ? '<span class="tag quiet">Posted anonymously</span>' : "") +
      "</span>"
    );
  }
  function bodyHtml(text) {
    return String(text == null ? "" : text)
      .split(/```([\s\S]*?)```/g)
      .map((part, index) =>
        index % 2 === 1
          ? "<pre><code>" + esc(part.replace(/^\w*\n/, "")) + "</code></pre>"
          : part.trim()
            ? '<p class="text">' + esc(part.trim()) + "</p>"
            : "",
      )
      .join("");
  }

  /* ------------------------------ list ----------------------------- */
  function listHtml() {
    if (st.loadingList && !st.threads.length) return '<div class="empty">Loading discussions…</div>';
    if (!st.threads.length) return '<div class="empty">No discussions match these filters.</div>';
    return st.threads
      .map(
        (t) =>
          '<button type="button" class="thread' +
          (String(t.id) === String(st.selected) ? " current" : "") +
          '" data-open="' +
          esc(t.id) +
          '"' +
          (String(t.id) === String(st.selected) ? ' aria-current="true"' : "") +
          '><span class="thread-top">' +
          (t.is_solved ? '<span class="tag solved">Solved</span>' : '<span class="tag open">Open</span>') +
          (t.course ? '<span class="tag quiet">' + esc(t.course.name) + "</span>" : "") +
          '<span class="when">' +
          esc(ago(t.created_at)) +
          '</span></span><strong>' +
          esc(t.title) +
          '</strong><span class="preview">' +
          esc(t.body_preview || "") +
          '</span><span class="thread-meta">' +
          esc((t.author && t.author.name) || "Unknown") +
          " · " +
          Number(t.reply_count || 0) +
          (Number(t.reply_count) === 1 ? " reply" : " replies") +
          " · " +
          Number(t.vote_count || 0) +
          " votes · " +
          Number(t.view_count || 0) +
          " views</span></button>",
      )
      .join("");
  }
  function renderList() {
    $("thread-list").innerHTML = listHtml();
    $("thread-count").textContent = st.threads.length
      ? st.threads.length + (st.threads.length === 50 ? " most recent" : "") + (st.threads.length === 1 ? " thread" : " threads")
      : "";
  }
  async function loadList() {
    const params = new URLSearchParams();
    const sort = $("sort").value;
    const search = $("search").value.trim();
    const course = $("course").value;
    if (sort) params.set("sort", sort);
    if (search) params.set("search", search);
    if (course) params.set("course_id", course);
    st.loadingList = true;
    renderList();
    try {
      const data = await api("/discussions?" + params.toString());
      st.threads = Array.isArray(data) ? data : data.discussions || [];
    } catch (e) {
      st.threads = [];
      toast(e.message, true);
    }
    st.loadingList = false;
    renderList();
  }

  /* ----------------------------- thread ---------------------------- */
  function replyHtml(r) {
    const armed = st.armed === "reply:" + r.id;
    return (
      '<article class="reply' +
      (r.is_accepted ? " accepted" : r.is_endorsed ? " endorsed" : "") +
      (r.author && r.author.role === "manager" ? " by-manager" : "") +
      '"><header>' +
      authorHtml(r.author) +
      '<span class="when">' +
      esc(ago(r.created_at)) +
      "</span>" +
      (r.is_accepted ? '<span class="tag solved">Accepted answer</span>' : "") +
      (r.is_endorsed ? '<span class="tag endorsed">Endorsed</span>' : "") +
      "</header>" +
      bodyHtml(r.body) +
      '<footer><span class="muted">' +
      Number(r.vote_count || 0) +
      ' votes</span><span class="actions"><button type="button" class="quiet" data-endorse="' +
      esc(r.id) +
      '">' +
      (r.is_endorsed ? "Remove endorsement" : "Endorse") +
      '</button><button type="button" class="danger' +
      (armed ? " armed" : "") +
      '" data-delete-reply="' +
      esc(r.id) +
      '">' +
      (armed ? "Confirm delete" : "Delete reply") +
      "</button></span></footer></article>"
    );
  }
  function threadHtml() {
    const t = st.thread;
    if (!st.selected) return '<div class="empty tall">Select a discussion to read it, reply, or remove it.</div>';
    if (!t) return '<div class="empty tall">Loading discussion…</div>';
    const armed = st.armed === "thread";
    const replies = t.replies || [];
    return (
      '<button type="button" class="back quiet" data-back>← All discussions</button><article class="post"><div class="thread-top">' +
      (t.is_solved ? '<span class="tag solved">Solved</span>' : '<span class="tag open">Open</span>') +
      (t.course ? '<span class="tag quiet">' + esc(t.course.name) + "</span>" : "") +
      (t.subject_label ? '<span class="tag quiet">' + esc(t.subject_label) + "</span>" : "") +
      (t.linked_quiz ? '<span class="tag quiet">Paper: ' + esc(t.linked_quiz.title) + "</span>" : "") +
      "</div><h2>" +
      esc(t.title) +
      "</h2><header>" +
      authorHtml(t.author) +
      '<span class="when">' +
      esc(ago(t.created_at)) +
      "</span></header>" +
      bodyHtml(t.body) +
      '<footer><span class="muted">' +
      Number(t.vote_count || 0) +
      " votes · " +
      Number(t.view_count || 0) +
      ' views</span><span class="actions"><button type="button" class="danger' +
      (armed ? " armed" : "") +
      '" data-delete-thread>' +
      (armed ? "Confirm: delete thread and all replies" : "Delete thread") +
      "</button></span></footer></article><h3>" +
      replies.length +
      (replies.length === 1 ? " reply" : " replies") +
      "</h3>" +
      (replies.length ? replies.map(replyHtml).join("") : '<div class="empty">No replies yet.</div>') +
      '<form id="reply-form" class="composer"><label for="reply-body">Reply as manager <span class="tag manager">Manager</span></label><textarea id="reply-body" rows="4" maxlength="5000" required placeholder="Write a reply. Students see it with the Manager tag."></textarea><div class="composer-foot"><span class="muted" id="reply-status" role="status"></span><button class="primary" id="reply-send">Post reply</button></div></form>'
    );
  }
  function renderThread(keepDraft) {
    const draft = keepDraft && $("reply-body") ? $("reply-body").value : "";
    $("thread-view").innerHTML = threadHtml();
    if (draft && $("reply-body")) $("reply-body").value = draft;
    document.body.classList.toggle("reading", !!st.selected);
  }
  async function openThread(id) {
    st.selected = id;
    st.thread = null;
    st.armed = "";
    renderList();
    renderThread(false);
    try {
      st.thread = await api("/discussions/" + encodeURIComponent(id));
    } catch (e) {
      st.selected = null;
      toast(e.status === 404 ? "This discussion no longer exists." : e.message, true);
      if (e.status === 404) loadList();
    }
    renderList();
    renderThread(false);
  }
  async function refreshThread() {
    if (!st.selected) return;
    try {
      st.thread = await api("/discussions/" + encodeURIComponent(st.selected));
      renderThread(true);
    } catch (e) {
      toast(e.message, true);
    }
  }
  function arm(key) {
    st.armed = st.armed === key ? "" : key;
    renderThread(true);
    return st.armed === "";
  }
  async function act(button, work) {
    if (button.disabled) return;
    button.disabled = true;
    try {
      await work();
    } catch (e) {
      toast(e.message, true);
      button.disabled = false;
    }
  }

  /* ----------------------------- events ---------------------------- */
  document.addEventListener("click", (ev) => {
    const target = ev.target.closest("button");
    if (!target) return;
    if (target.dataset.open) return void openThread(target.dataset.open);
    if ("back" in target.dataset) {
      st.selected = null;
      st.thread = null;
      st.armed = "";
      renderList();
      return renderThread(false);
    }
    if ("deleteThread" in target.dataset) {
      if (st.armed !== "thread") return void arm("thread");
      return void act(target, async () => {
        await api("/discussions/" + encodeURIComponent(st.selected), "DELETE");
        st.threads = st.threads.filter((t) => String(t.id) !== String(st.selected));
        st.selected = null;
        st.thread = null;
        st.armed = "";
        renderList();
        renderThread(false);
        toast("Thread deleted.");
      });
    }
    if (target.dataset.deleteReply) {
      const id = target.dataset.deleteReply;
      if (st.armed !== "reply:" + id) return void arm("reply:" + id);
      return void act(target, async () => {
        await api("/discussions/replies/" + encodeURIComponent(id), "DELETE");
        st.armed = "";
        toast("Reply deleted.");
        await refreshThread();
        loadList();
      });
    }
    if (target.dataset.endorse)
      return void act(target, async () => {
        await api("/discussions/replies/" + encodeURIComponent(target.dataset.endorse) + "/endorse", "POST");
        await refreshThread();
      });
    if (target.id === "refresh") {
      loadList();
      refreshThread();
    }
  });
  document.addEventListener("submit", (ev) => {
    if (ev.target.id !== "reply-form") return;
    ev.preventDefault();
    const body = $("reply-body").value.trim();
    const status = $("reply-status");
    if (!body) return;
    act($("reply-send"), async () => {
      status.textContent = "Posting…";
      try {
        await api("/discussions/" + encodeURIComponent(st.selected) + "/replies", "POST", { body: body });
      } catch (e) {
        status.textContent = "";
        throw e;
      }
      $("reply-body").value = "";
      toast("Reply posted.");
      await refreshThread();
      loadList();
    });
  });
  $("sort").addEventListener("change", loadList);
  $("course").addEventListener("change", loadList);
  $("search").addEventListener("input", () => {
    clearTimeout(st.searchTimer);
    st.searchTimer = setTimeout(loadList, 350);
  });

  async function boot() {
    const gate = $("gate");
    if (!token()) return location.assign("/login");
    try {
      const me = await api("/auth/me");
      const user = me.user || me;
      if (!user || user.role !== "manager") {
        gate.textContent = "Only manager accounts can moderate discussions.";
        gate.classList.add("error");
        return;
      }
      $("me").textContent = user.name || user.email || "";
    } catch (e) {
      gate.textContent = "Could not verify your account: " + e.message;
      gate.classList.add("error");
      return;
    }
    gate.hidden = true;
    $("workspace").hidden = false;
    renderThread(false);
    api("/manager/courses")
      .then((rows) => {
        const courses = Array.isArray(rows) ? rows : rows.courses || [];
        $("course").insertAdjacentHTML(
          "beforeend",
          courses.map((c) => '<option value="' + esc(c.id) + '">' + esc(c.name) + "</option>").join(""),
        );
      })
      .catch(() => {});
    await loadList();
  }
  boot();
})();
