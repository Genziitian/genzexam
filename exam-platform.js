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
    system: null,
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
    mgrTab: "monitor",
    candidateSearch: "",
    isTabWarningModalOpen: false,
    hasUserSwitchedAway: false,
    outsideSince: null,
    tabWarningTimerId: null,
    onboardingStep: 1,
    attendanceTime: null,
    photoDataUrl: null,
    activeSection: "sec-questions",
    webcamStream: null,
  };
  function I(name, size = 16, color = "currentColor", extraStyle = "") {
    const s = `width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:middle;flex-shrink:0;${extraStyle}"`;
    switch (name) {
      case "shield":
        return `<svg ${s}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`;
      case "cap":
        return `<svg ${s}><path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/></svg>`;
      case "camera":
        return `<svg ${s}><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>`;
      case "lock":
        return `<svg ${s}><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`;
      case "unlock":
        return `<svg ${s}><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>`;
      case "alert":
        return `<svg ${s}><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`;
      case "check":
        return `<svg ${s}><polyline points="20 6 9 17 4 12"/></svg>`;
      case "clock":
        return `<svg ${s}><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;
      case "pause":
        return `<svg ${s}><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`;
      case "play":
        return `<svg ${s}><polygon points="5 3 19 12 5 21 5 3"/></svg>`;
      case "square":
        return `<svg ${s}><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/></svg>`;
      case "download":
        return `<svg ${s}><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`;
      case "broadcast":
        return `<svg ${s}><circle cx="12" cy="12" r="2"/><path d="M16.24 7.76a6 6 0 0 1 0 8.49m-8.48-.01a6 6 0 0 1 0-8.49m11.31-2.82a10 10 0 0 1 0 14.14m-14.14 0a10 10 0 0 1 0-14.14"/></svg>`;
      case "users":
        return `<svg ${s}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`;
      case "barChart":
        return `<svg ${s}><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>`;
      case "door":
        return `<svg ${s}><path d="M18 20V6a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v14"/><path d="M2 20h20"/><circle cx="14" cy="12" r="1"/></svg>`;
      case "message":
        return `<svg ${s}><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`;
      case "fileText":
        return `<svg ${s}><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>`;
      case "refresh":
        return `<svg ${s}><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>`;
      case "settings":
        return `<svg ${s}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`;
      case "x":
        return `<svg ${s}><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`;
      case "volumeX":
        return `<svg ${s}><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>`;
      case "wifi":
        return `<svg ${s}><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>`;
      case "calculator":
        return `<svg ${s}><rect x="4" y="2" width="16" height="20" rx="2"/><line x1="8" y1="6" x2="16" y2="6"/><line x1="16" y1="14" x2="16" y2="18"/><path d="M16 10h.01M12 10h.01M8 10h.01M12 14h.01M8 14h.01M12 18h.01M8 18h.01"/></svg>`;
      case "slash":
        return `<svg ${s}><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>`;
      default:
        return "";
    }
  }
  function showCocModal() {
    let modal = document.getElementById("ep-coc-modal");
    if (modal) modal.remove();
    modal = document.createElement("div");
    modal.id = "ep-coc-modal";
    modal.className = "ep-modal-backdrop";
    modal.style.display = "flex";
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:760px;text-align:left;max-height:88vh;overflow-y:auto;padding:28px 24px;">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:16px;width:100%;">
          <div style="display:flex;align-items:center;gap:10px;">
            <img src="/assets/quiz-lab-icon.png" alt="Quiz Lab" style="height:30px;width:30px;border-radius:6px;object-fit:contain;">
            ${I("shield", 22, "#059669")}
            <h2 style="font-size:20px;font-weight:800;color:#0f172a;margin:0;">Candidate Code of Conduct (COC)</h2>
          </div>
          <button id="ep-coc-close" style="background:#f8fafc;border:1px solid #cbd5e1;color:#334155;border-radius:8px;padding:6px 10px;cursor:pointer;font-weight:800;display:flex;align-items:center;">
            ${I("x", 14, "#334155")}
          </button>
        </div>

        <h3 style="font-size:15px;font-weight:800;color:#1e3a8a;margin:0 0 10px 0;">
          Online Remote Proctored Exams
        </h3>
        <p style="font-size:13px;color:#334155;line-height:1.65;margin-bottom:16px;">
          This exam is conducted online from the examinee's place of residence and proctored remotely. The following guidelines must be followed by all examinees:
        </p>
        <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(260px, 1fr));gap:12px;margin-bottom:20px;width:100%;">
          ${[
            ["Personal details", "No examinee shall share personal details with proctors, including but not limited to phone number or address, during or after the exam."],
            ["Clean desk", "The table or desk where the examinee takes this exam shall not have any items kept that may have sensitive information, including but not limited to phone numbers and address."],
            ["No assistance", "No examinee shall aid, or attempt to aid, another candidate by discussing answers via email, text, chat, call, or any other method."],
            ["Confidential exam", "No examinee will disclose any details of what happened during the exam or examination trials to anyone outside."],
            ["Ask inside exam", "If an examinee wishes to ask a question during the exam, they should post the query in the exam room chat / doubts window and the proctor will clarify."],
            ["Violation action", "If any examinee is found to have violated the Code of Conduct for Online Examinations, or to have acted improperly, they will be liable to disciplinary procedures (withholding results or suspension)."]
          ]
            .map(
              ([title, body], idx) => `
                <div style="border:1px solid #e2e8f0;background:#f8fafc;border-radius:12px;padding:12px 14px;">
                  <div style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:800;color:#0f172a;margin-bottom:6px;">
                    <span style="width:22px;height:22px;border-radius:9999px;background:#dcfce7;color:#047857;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:900;">${idx + 1}</span>
                    ${title}
                  </div>
                  <div style="font-size:12px;line-height:1.55;color:#475569;">${body}</div>
                </div>
              `
            )
            .join("")}
        </div>
        <div style="text-align:right;width:100%;">
          <button id="ep-coc-ok" class="ep-btn ep-btn-primary" style="padding:9px 22px;font-size:13px;font-weight:700;">I Understand</button>
        </div>
      </div>
    `;
    document.body.appendChild(modal);
    const close = () => modal.remove();
    document.getElementById("ep-coc-close").onclick = close;
    document.getElementById("ep-coc-ok").onclick = close;
    modal.addEventListener("click", (e) => {
      if (e.target === modal) close();
    });
  }
  function startWebcam() {
    const video = document.getElementById("ep-cam-stream");
    const canvas = document.getElementById("ep-cam-canvas");
    if (!video || !canvas) return;
    if (app.webcamStream) return;
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices.getUserMedia({ video: { width: 320, height: 240 } })
        .then((stream) => {
          app.webcamStream = stream;
          video.srcObject = stream;
        })
        .catch(() => {
          simulateCanvasCamera(canvas, video);
        });
    } else {
      simulateCanvasCamera(canvas, video);
    }
  }
  function simulateCanvasCamera(cvs, vid) {
    const ctx = cvs.getContext("2d");
    ctx.fillStyle = "#1e293b";
    ctx.fillRect(0, 0, 320, 240);
    ctx.fillStyle = "#38bdf8";
    ctx.beginPath();
    ctx.arc(160, 95, 45, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(160, 200, 70, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 13px Inter, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Verified Student Face", 160, 160);
    const dataUrl = cvs.toDataURL("image/jpeg");
    const snapshotImg = document.getElementById("ep-cam-snapshot");
    if (snapshotImg) snapshotImg.src = dataUrl;
    const tag = document.getElementById("ep-cam-fallback-tag");
    if (tag) tag.style.display = "block";
  }
  function stopWebcam() {
    if (app.webcamStream) {
      try {
        app.webcamStream.getTracks().forEach((t) => t.stop());
      } catch (_) {}
      app.webcamStream = null;
    }
  }
  function formatOutsideTime(s) {
    s = Math.max(0, Math.floor(s || 0));
    return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  }
  function showTabSwitchWarningModal(warningCount, maxAllowed, outsideSeconds = 1) {
    app.isTabWarningModalOpen = true;
    let modal = document.getElementById("ep-tab-warning-modal");
    if (!modal) {
      modal = document.createElement("div");
      modal.id = "ep-tab-warning-modal";
      modal.className = "ep-modal-backdrop";
      document.body.appendChild(modal);
    }
    const liveStart = Date.now() - (outsideSeconds * 1000);
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="border:1.5px solid #fca5a5;">
        <div class="ep-shield-badge">
          ${I("alert", 34, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#b91c1c;">
          Security Infraction Detected!
        </h2>
        <p class="ep-onboarding-text">
          Exiting the exam screen, changing windows, leaving fullscreen, or opening developer tools is strictly prohibited and logged to the proctoring server.
        </p>
        <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;padding:12px 16px;margin-bottom:14px;display:flex;align-items:center;justify-content:center;gap:10px;color:#991b1b;font-weight:800;font-size:15px;width:100%;">
          ${I("alert", 18, "#dc2626")}
          Violation ${warningCount} of ${maxAllowed}
        </div>
        <div style="background:#fff7ed;border:1px solid #fed7aa;border-radius:10px;padding:10px 14px;margin-bottom:20px;color:#9a3412;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;gap:8px;width:100%;">
          ${I("clock", 15, "#ea580c")}
          Outside duration: <span id="ep-tab-away-time">${formatOutsideTime(outsideSeconds)}</span>
        </div>
        <button id="ep-btn-dismiss-warning" class="ep-modal-btn" style="background:#dc2626;box-shadow:0 4px 14px rgba(220,38,38,0.35);">
          I Understand &amp; Resume Exam (Return to Fullscreen)
        </button>
      </div>
    `;
    modal.style.display = "flex";
    if (app.tabWarningTimerId) clearInterval(app.tabWarningTimerId);
    app.tabWarningTimerId = setInterval(() => {
      const timeEl = document.getElementById("ep-tab-away-time");
      const elapsed = Math.max(1, Math.round((Date.now() - liveStart) / 1000));
      if (timeEl) timeEl.textContent = formatOutsideTime(elapsed);
    }, 1000);

    const btnDismiss = document.getElementById("ep-btn-dismiss-warning");
    if (btnDismiss) {
      btnDismiss.onclick = async () => {
        if (app.tabWarningTimerId) clearInterval(app.tabWarningTimerId);
        app.tabWarningTimerId = null;
        modal.remove();
        app.isTabWarningModalOpen = false;
        app.hasUserSwitchedAway = false;
        await fullscreen();
      };
    }
  }
  function renderLockoutScreen(e, sess) {
    return `<div id="ep-root" style="display:flex;align-items:center;justify-content:center;min-height:85vh;padding:24px;background:#f8fafc;">
      <div class="ep-onboarding-card" style="max-width:500px;border:1.5px solid #fecaca;padding:36px 32px;">
        <div class="ep-shield-badge" style="background:#fee2e2;">
          ${I("lock", 34, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#0f172a;font-size:22px;">
          Examination Window Locked
        </h2>
        <p class="ep-onboarding-text" style="color:#475569;font-size:13.5px;margin-bottom:18px;">
          Security policy locked your session because the window was exited or the security infraction threshold was reached. An official re-entry request has been queued with the exam invigilator.
        </p>
        <div style="background:#fef3c7;border:1px solid #fde68a;border-radius:10px;padding:12px 16px;color:#92400e;font-size:13px;font-weight:700;margin-bottom:20px;width:100%;display:flex;align-items:center;justify-content:center;gap:8px;">
          ${I("clock", 16, "#92400e")} Re-entry request pending manager approval...
        </div>
        <div style="display:flex;gap:10px;justify-content:center;margin-bottom:16px;width:100%;">
          <button type="button" class="ep-btn ep-btn-primary" data-action="refresh-state" style="padding:10px 18px;font-size:13px;font-weight:700;">
            ${I("refresh", 13, "#fff")} Check Approval Status
          </button>
          <button type="button" class="ep-btn ep-btn-quiet" data-action="messages" style="padding:10px 16px;font-size:13px;">
            ${I("message", 13, "currentColor")} Contact Manager
          </button>
        </div>
        <div style="font-size:12px;color:#64748b;line-height:1.5;">
          This screen automatically checks every few seconds and will restore your exam session immediately once approved by the supervisor.
        </div>
      </div>
    </div>`;
  }
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
    root.innerHTML = `<div class="ep-shell"><header class="ep-top"><a class="ep-brand" href="/exams"><img class="ep-mark" src="/assets/quiz-lab-icon.png" alt="" width="36" height="36"><span><b>Quiz LAB</b><small>Secure exam room</small></span></a><div class="ep-user"><button type="button" class="ep-btn ep-btn-quiet" data-action="open-coc" style="font-weight:700;cursor:pointer;padding:4px 10px;border-radius:6px;border:1px solid #cbd5e1;background:rgba(255,255,255,0.08);color:inherit;display:inline-flex;align-items:center;gap:6px;">${I("shield", 13, "#10b981")} COC</button><span class="ep-user-name">${esc(app.user?.name || app.user?.email || "")}</span><a class="ep-link" href="/dashboard">Back to app</a><button class="ep-btn ep-btn-quiet" data-action="logout">Sign out</button></div></header><div id="ep-content"></div><div id="ep-toast" role="status" aria-live="polite"></div></div>`;
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
      if (!quiet) {
        app.error = "";
        app.system = null;
      }
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
  /* Managers can check and update the database from here when the exam API fails. */
  function systemPanel() {
    if (!isManager() || (!app.error && !app.system)) return "";
    const r = app.system;
    if (!r)
      return '<div class="ep-card ep-system"><h2>Exams could not be loaded</h2><p class="ep-muted">This usually means the server database has not been updated for this release. Check it, then apply the update if one is pending.</p><div class="ep-actions"><button class="ep-btn ep-btn-primary" data-action="system-check">Check database</button></div></div>';
    if (r.up_to_date)
      return '<div class="ep-card ep-system"><h2>The database is up to date</h2><p class="ep-muted">Nothing is pending, so the error has another cause. Press Refresh; if it persists, the server log (storage/logs/laravel.log) has the details.</p></div>';
    const lines = [
      r.error ? `Database check failed: ${r.error}` : "",
      r.pending?.length ? `${r.pending.length} pending update${r.pending.length === 1 ? "" : "s"}: ${r.pending.join(", ")}` : "",
      r.missing_tables?.length ? `Missing tables: ${r.missing_tables.join(", ")}` : "",
      r.missing_columns?.length ? `Missing columns: ${r.missing_columns.join(", ")}` : "",
    ].filter(Boolean);
    return `<div class="ep-card ep-system"><h2>The database needs an update</h2>${lines.map((l) => `<p class="ep-muted">${esc(l)}</p>`).join("")}<div class="ep-actions"><button class="ep-btn ep-btn-primary" data-action="system-migrate" ${r.database ? "" : "disabled"}>Apply database update</button><span class="ep-muted">Adds the missing tables and columns. Existing data is kept.</span></div></div>`;
  }
  function listView() {
    const preview = studentPreview();
    const manager = isManager() && !preview;
    const list = preview ? app.exams.filter((e) => e.status && e.status !== "draft") : app.exams;
    return `<section class="ep-page"><div class="ep-heading"><div><p class="ep-eyebrow">${manager ? "EXAM MANAGEMENT" : "ONLINE EXAMS"}</p><h1>${manager ? "Online proctoring" : "Your exams"}</h1></div>${manager ? '<button class="ep-btn ep-btn-primary" data-action="new">Create exam</button>' : '<button class="ep-btn" data-action="refresh-list">Refresh</button>'}</div>${app.error ? `<div class="ep-alert error">${esc(app.error)}</div>` : ""}${app.notice ? `<div class="ep-alert">${esc(app.notice)}</div>` : ""}${systemPanel()}${preview ? '<div class="ep-alert">Student preview. This is what enrolled students see for your published exams. You are signed in as a manager, so exams cannot be taken from here. <a class="ep-link" href="/exams">Go to exam management</a></div>' : ""}${manager ? `<div class="ep-card"><div class="ep-card-head"><h2>Exams</h2><button class="ep-btn ep-btn-quiet" data-action="refresh-list">Refresh</button></div>${list.length ? `<div class="ep-table-wrap"><table><thead><tr><th>Exam</th><th>Status</th><th>Schedule</th><th>Questions</th><th></th></tr></thead><tbody>${list.map((e) => `<tr><td><b>${esc(e.title)}</b><small>${esc(e.subject || "—")}</small></td><td><span class="ep-status ${esc(e.closed ? "ended" : e.status)}">${esc(e.closed ? "closed" : e.status || "draft")}</span></td><td>${esc(formatDate(e.scheduled_at))}${e.closes_at ? `<small>Ends ${esc(formatDate(e.closes_at))}</small>` : ""}</td><td>${Number(e.question_count ?? e.questions_count ?? e.questions?.length ?? 0)}</td><td><button class="ep-btn ep-btn-small" data-action="open" data-id="${esc(e.id)}" ${(e.closed && !manager) || preview ? "disabled" : ""}>${manager ? "Manage" : e.closed ? "Closed" : preview ? "Preview" : "Open"}</button></td></tr>`).join("")}</tbody></table></div>` : `<div class="ep-empty"><div class="ep-empty-icon">${manager ? "＋" : "◷"}</div><h3>${manager ? "No exams yet" : "No exams available"}</h3><p>${manager ? "Create a draft exam to begin setting up questions and enrollment." : preview ? "Students see exams here once you publish them and enrol their email." : "Ask your exam manager to enroll your account."}</p></div>`}${app.nextPage ? '<div class="ep-actions"><button class="ep-btn" data-action="more-exams">Load more exams</button></div>' : ""}</div>` : `${studentExams(list, preview)}${app.nextPage ? '<div class="ep-actions"><button class="ep-btn" data-action="more-exams">Load more exams</button></div>' : ""}`}</section>`;
  }
  /* The student's exam list: one card per exam, with the next thing they can do. */
  const STUDENT_STATUS = {
    published: ["Not started yet", "published"],
    live: ["Live now", "live"],
    paused: ["Paused by the manager", "paused"],
    ended: ["Ended", "ended"],
    archived: ["Ended", "ended"],
  };
  function examDay(v) {
    const d = v ? new Date(v) : null;
    return !d || Number.isNaN(d.valueOf())
      ? null
      : {
          day: d.getDate(),
          month: d.toLocaleDateString("en-IN", { month: "short" }),
          text: d.toLocaleString("en-IN", { weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }),
        };
  }
  function studentExams(list, preview) {
    if (!list.length)
      return `<div class="ep-card"><div class="ep-empty"><div class="ep-empty-icon">◷</div><h3>No exams yet</h3><p>${preview ? "Students see exams here once you publish them and enrol their email." : "An exam appears here when your exam manager enrols your account."}</p></div></div>`;
    return `<div class="ep-exam-list">${list
      .map((e) => {
        const start = examDay(e.scheduled_at);
        const end = examDay(e.closes_at);
        const [label, tone] = e.closed ? ["Closed", "ended"] : STUDENT_STATUS[e.status] || [e.status || "Draft", "draft"];
        const live = !e.closed && e.status === "live";
        const questions = Number(e.question_count ?? e.questions_count ?? e.questions?.length ?? 0);
        const facts = [
          start ? `Starts ${start.text}` : "Start time not set",
          end ? `Ends ${end.text}` : "",
          Number(e.duration_minutes) ? `${Number(e.duration_minutes)} min` : "",
          `${questions} question${questions === 1 ? "" : "s"}`,
        ].filter(Boolean);
        const action = preview ? "Preview" : e.closed ? "Closed" : live ? "Enter exam" : "View details";
        return `<article class="ep-card ep-exam${live ? " is-live" : ""}"><div class="ep-exam-date" aria-hidden="true">${start ? `<b>${start.day}</b><span>${esc(start.month)}</span>` : "<b>—</b><span>TBA</span>"}</div><div class="ep-exam-main"><span class="ep-status ${tone}">${esc(label)}</span><h2>${esc(e.title)}</h2>${e.subject ? `<p class="ep-exam-subject">${esc(e.subject)}</p>` : ""}<p class="ep-exam-facts">${facts.map((f) => `<span>${esc(f)}</span>`).join("")}</p></div><button class="ep-btn${live ? " ep-btn-primary" : ""}" data-action="open" data-id="${esc(e.id)}" ${e.closed || preview ? "disabled" : ""}>${action}</button></article>`;
      })
      .join("")}</div>`;
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
    if (!manager) return studentDetail(e, state);
    return renderManagerPortal(e, state);
  }
  function renderManagerPortal(e, state) {
    const sessions = Array.isArray(state.sessions)
      ? state.sessions
      : Object.values(state.sessions || {});
    const enrolledCount = Number(
      e.enrollment_count ||
        (Array.isArray(e.enrollments) ? e.enrollments.length : 0) ||
        sessions.length ||
        0,
    );
    const activeSessions = sessions.filter((s) => s.status === "in_exam");
    const lockedSessions = sessions.filter((s) => s.status === "locked");
    const activeCount = activeSessions.length;
    const lockedCount = lockedSessions.length;
    const totalQuestions = Number(e.questions?.length || e.question_count || 0);
    const totalAnswered = sessions.reduce(
      (sum, s) => sum + Number(s.answered_count || 0),
      0,
    );
    const avgProgress =
      sessions.length && totalQuestions
        ? Math.min(
            100,
            Math.round(
              (totalAnswered / (sessions.length * totalQuestions)) * 100,
            ),
          )
        : 0;

    const currentTab = app.mgrTab || "monitor";

    return `
      <section class="saas-container">
        <!-- Top Executive Action Bar -->
        <div class="saas-header">
          <div>
            <div class="saas-breadcrumb">
              <a href="/exams" data-action="back" style="color:#9ca3af;text-decoration:none;">Assessments</a>
              <span style="color:#4b5563;">/</span>
              <span>Quiz LAB</span>
              <span style="color:#4b5563;">/</span>
              <span class="active">${esc(e.title)}</span>
            </div>
            <div class="saas-title">
              ${esc(e.title)}
              <span class="saas-status-pill ${esc(e.status || "draft")}">
                <span class="saas-pulse-dot"></span>
                ${esc(e.status || "draft")}
              </span>
              <span style="font-size:11px;padding:3px 8px;border-radius:6px;background:${e.type === "final" ? "rgba(244,63,94,0.15)" : "rgba(56,189,248,0.15)"};color:${e.type === "final" ? "#fb7185" : "#38bdf8"};border:1px solid ${e.type === "final" ? "rgba(244,63,94,0.3)" : "rgba(56,189,248,0.3)"};">
                ${e.type === "final" ? "FINAL TEST" : esc(e.subject || "GENERAL TEST").toUpperCase()}
              </span>
            </div>
          </div>

          <!-- Quick Action Toolbar -->
          <div class="saas-control-group">
            ${
              e.status === "draft"
                ? `<button class="saas-btn" data-action="edit">
                     ${I("settings", 13, "#9ca3af")} Edit Draft
                   </button>`
                : ""
            }

            ${
              e.status === "published"
                ? `<button class="saas-btn saas-btn-primary" data-action="start">
                     ${I("play", 13, "#34d399")} Start Exam
                   </button>
                   <button class="saas-btn" data-action="edit-enrollments">
                     ${I("users", 13, "#9ca3af")} Edit Enrollment
                   </button>
                   <button class="saas-btn" data-action="edit">
                     ${I("settings", 13, "#9ca3af")} Edit Draft
                   </button>`
                : ""
            }

            ${
              e.status === "live"
                ? `<button class="saas-btn saas-btn-warning" data-action="pause">
                     ${I("pause", 13, "#fbbf24")} Pause
                   </button>`
                : e.status === "paused"
                  ? `<button class="saas-btn saas-btn-primary" data-action="resume">
                       ${I("play", 13, "#34d399")} Resume
                     </button>`
                  : ""
            }

            ${
              ["live", "paused"].includes(e.status)
                ? `<div class="saas-extend-dock">
                     <span class="saas-extend-label">Extend:</span>
                     <button class="saas-extend-btn" data-action="ext-5">+5m</button>
                     <button class="saas-extend-btn" data-action="ext-10">+10m</button>
                     <button class="saas-extend-btn" data-action="ext-15">+15m</button>
                   </div>
                   <button class="saas-btn saas-btn-danger" data-action="end">
                     ${I("square", 13, "#fb7185")} End Exam
                   </button>`
                : ""
            }

            ${
              e.status === "ended" && !e.results_published
                ? `<button class="saas-btn saas-btn-primary" data-action="publish-results">
                     ${I("broadcast", 13, "currentColor")} Publish Results
                   </button>`
                : ""
            }

            ${
              e.results_published
                ? `<button class="saas-btn" data-action="export" style="background:#042f2e;color:#2dd4bf;border-color:#0d9488;">
                     ${I("download", 13, "#2dd4bf")} Export Marks (CSV)
                   </button>`
                : ""
            }

            ${
              e.status === "ended"
                ? `<button class="saas-btn" data-action="archive">
                     ${I("square", 13, "#9ca3af")} Archive
                   </button>`
                : ""
            }

            <button class="saas-btn" data-action="messages" title="Doubts and announcements">
              ${I("message", 13, "#9ca3af")} Doubts &amp; Messages
            </button>
            <button class="saas-btn" data-action="copy-link" title="Copy candidate entrance link">
              ${I("fileText", 13, "#9ca3af")} Candidate Link
            </button>
            <button class="saas-btn" data-action="refresh-state" title="Refresh state now">
              ${I("refresh", 13, "#9ca3af")} Refresh
            </button>
          </div>
        </div>

        ${app.error ? `<div class="ep-alert error" style="margin-bottom:20px;">${esc(app.error)}</div>` : ""}

        <!-- 4 Live KPI Cards -->
        <div class="saas-kpi-grid">
          <div class="saas-kpi-card">
            <div class="saas-kpi-title">
              <span>Active Test Takers</span>
              <span style="color:#34d399;font-size:11px;">LIVE</span>
            </div>
            <div class="saas-kpi-value-row">
              <span class="saas-kpi-value">${activeCount}</span>
              <span style="color:#6b7280;font-size:13px;font-weight:600;">/ ${enrolledCount || sessions.length} in session</span>
            </div>
            <div class="saas-kpi-subtext">
              <span style="color:#10b981;font-weight:700;">100%</span> telemetry uptime
            </div>
          </div>

          <div class="saas-kpi-card">
            <div class="saas-kpi-title">
              <span>Total Enrolled</span>
              <span style="color:#6b7280;font-size:11px;">WHITELIST</span>
            </div>
            <div class="saas-kpi-value-row">
              <span class="saas-kpi-value">${enrolledCount || sessions.length}</span>
              <span style="color:#6b7280;font-size:13px;font-weight:600;">candidates</span>
            </div>
            <div class="saas-kpi-subtext">
              Duration: <b>${Number(e.duration_minutes || 0)} min</b>
            </div>
          </div>

          <div class="saas-kpi-card">
            <div class="saas-kpi-title">
              <span>Cohort Progress</span>
              <span style="color:#6b7280;font-size:11px;">COMPLETION</span>
            </div>
            <div class="saas-kpi-value-row">
              <span class="saas-kpi-value">${avgProgress}%</span>
              <span style="color:#6b7280;font-size:13px;font-weight:600;">avg pace</span>
            </div>
            <div style="width:100%;height:4px;background:#1f1f1f;border-radius:9999px;overflow:hidden;margin-top:8px;">
              <div style="height:100%;background:#10b981;width:${avgProgress}%;"></div>
            </div>
          </div>

          <div class="saas-kpi-card" style="${lockedCount > 0 ? "border-color:#f59e0b;background:#1c170d;" : ""}">
            <div class="saas-kpi-title">
              <span>Re-entry Approval Queue</span>
              <span style="color:${lockedCount > 0 ? "#f59e0b" : "#6b7280"};font-size:11px;">
                ${lockedCount > 0 ? "ATTENTION" : "NORMAL"}
              </span>
            </div>
            <div class="saas-kpi-value-row">
              <span class="saas-kpi-value" style="color:${lockedCount > 0 ? "#fbbf24" : "#f9fafb"};">
                ${lockedCount}
              </span>
              <span style="color:#6b7280;font-size:13px;font-weight:600;">pending review</span>
            </div>
            <div class="saas-kpi-subtext">
              ${lockedCount > 0 ? `<b style="color:#fbbf24;">Candidates waiting</b>` : "No locked candidates"}
            </div>
          </div>
        </div>

        <!-- Cockpit Navigation Tabs -->
        <div class="saas-tab-bar">
          <button class="saas-tab-btn ${currentTab === "monitor" ? "active" : ""}" data-action="mgr-tab" data-tab="monitor">
            ${I("barChart", 14)} Live Monitor <span class="saas-tab-badge">${sessions.length}</span>
          </button>
          <button class="saas-tab-btn ${currentTab === "leave_log" ? "active" : ""}" data-action="mgr-tab" data-tab="leave_log">
            ${I("clock", 14)} Leave Log &amp; Audit
          </button>
          <button class="saas-tab-btn ${currentTab === "reentry" ? "active" : ""}" data-action="mgr-tab" data-tab="reentry">
            ${I("door", 14)} Re-entry Approval Queue
            ${lockedCount > 0 ? `<span class="saas-tab-badge" style="background:#78350f;color:#fbbf24;">${lockedCount}</span>` : ""}
          </button>
          <button class="saas-tab-btn ${currentTab === "builder" ? "active" : ""}" data-action="mgr-tab" data-tab="builder">
            ${I("fileText", 14)} Exam Builder &amp; Questions <span class="saas-tab-badge">${totalQuestions}</span>
          </button>
          <button class="saas-tab-btn ${currentTab === "whitelist" ? "active" : ""}" data-action="mgr-tab" data-tab="whitelist">
            ${I("users", 14)} Whitelist &amp; Enrollment <span class="saas-tab-badge">${enrolledCount}</span>
          </button>
        </div>

        <!-- Tab Content -->
        ${renderMgrTabContent(currentTab, e, state, sessions, lockedSessions)}
      </section>
    `;
  }
  function renderMgrTabContent(tab, e, state, sessions, lockedSessions) {
    const totalQuestions = Number(e.questions?.length || e.question_count || 0);
    const maxWarnings = Number(e.max_warnings || 3);

    if (tab === "monitor") {
      const q = (app.candidateSearch || "").toLowerCase();
      const filtered = q
        ? sessions.filter(
            (s) =>
              (s.name || "").toLowerCase().includes(q) ||
              (s.email || "").toLowerCase().includes(q),
          )
        : sessions;

      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div class="saas-search-box">
              ${I("users", 14, "#6b7280")}
              <input type="text" id="ep-candidate-search" placeholder="Search candidate by name or email…" value="${esc(app.candidateSearch || "")}" />
            </div>
            <div style="font-size:12px;color:#9ca3af;">
              Showing <b>${filtered.length}</b> of ${sessions.length} candidates
            </div>
          </div>
          <div style="overflow-x:auto;">
            <table class="saas-table">
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Status</th>
                  <th>Warnings</th>
                  <th>Answered</th>
                  <th>Last Activity</th>
                  <th style="text-align:right;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${
                  filtered.length
                    ? filtered
                        .map((s) => {
                          const dotClass =
                            s.status === "in_exam"
                              ? "active"
                              : s.status === "locked"
                                ? "locked"
                                : s.status === "submitted"
                                  ? "submitted"
                                  : "not_started";
                          const statusBadge =
                            s.status === "in_exam"
                              ? '<span class="saas-badge-success">LIVE IN EXAM</span>'
                              : s.status === "locked"
                                ? '<span class="saas-badge-danger">LOCKED OUT</span>'
                                : s.status === "submitted"
                                  ? '<span class="saas-badge-muted">SUBMITTED</span>'
                                  : '<span class="saas-badge-muted">NOT STARTED</span>';
                          const initials = (s.name || s.email || "S")
                            .split(" ")
                            .map((w) => w[0])
                            .slice(0, 2)
                            .join("")
                            .toUpperCase();
                          return `
                            <tr>
                              <td>
                                <div class="saas-candidate-cell">
                                  <div class="saas-avatar">
                                    ${initials}
                                    <div class="saas-avatar-dot ${dotClass}"></div>
                                  </div>
                                  <div>
                                    <div style="font-weight:700;color:#f9fafb;">${esc(s.name || s.email || `Candidate #${s.user_id}`)}</div>
                                    <div style="font-size:11px;color:#6b7280;">${esc(s.email || "")}</div>
                                  </div>
                                </div>
                              </td>
                              <td>${statusBadge}</td>
                              <td>
                                <span style="font-weight:700;color:${Number(s.warnings) > 0 ? "#fb7185" : "#34d399"};">
                                  ${Number(s.warnings || 0)}
                                </span>
                                <span style="color:#6b7280;font-size:11px;">/ ${maxWarnings}</span>
                              </td>
                              <td>
                                <span style="font-weight:700;color:#f9fafb;">
                                  ${Number(s.answered_count || 0)}
                                </span>
                                <span style="color:#6b7280;font-size:11px;">/ ${totalQuestions}</span>
                              </td>
                              <td style="font-size:12px;color:#9ca3af;">
                                ${esc(formatDate(s.updated_at))}
                              </td>
                              <td style="text-align:right;">
                                ${
                                  s.status === "locked"
                                    ? `<button class="saas-btn saas-btn-warning" data-action="unlock" data-user="${esc(s.user_id)}" style="padding:5px 11px;font-size:11px;">
                                         ${I("unlock", 12)} Approve Re-entry
                                       </button>`
                                    : s.status === "in_exam"
                                      ? `<button class="saas-btn saas-btn-danger" data-action="lock" data-user="${esc(s.user_id)}" style="padding:5px 11px;font-size:11px;">
                                           ${I("lock", 12)} Lock Window
                                         </button>`
                                      : '<span style="color:#4b5563;font-size:11px;">—</span>'
                                }
                              </td>
                            </tr>
                          `;
                        })
                        .join("")
                    : `<tr><td colspan="6" style="text-align:center;padding:32px;color:#6b7280;">No candidates matching filter.</td></tr>`
                }
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    if (tab === "reentry") {
      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div style="font-weight:700;color:#f9fafb;display:flex;align-items:center;gap:8px;">
              ${I("door", 16, "#fbbf24")}
              Candidates Locked &amp; Awaiting Supervisor Re-entry Approval
            </div>
            <div style="font-size:12px;color:#9ca3af;">
              ${lockedSessions.length} waiting
            </div>
          </div>
          <div style="overflow-x:auto;">
            <table class="saas-table">
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Warnings Triggered</th>
                  <th>Last Recorded Activity</th>
                  <th style="text-align:right;">Supervisor Decision</th>
                </tr>
              </thead>
              <tbody>
                ${
                  lockedSessions.length
                    ? lockedSessions
                        .map(
                          (s) => `
                            <tr>
                              <td>
                                <div style="font-weight:700;color:#f9fafb;">${esc(s.name || s.email || `Candidate #${s.user_id}`)}</div>
                                <div style="font-size:11px;color:#6b7280;">${esc(s.email || "")}</div>
                              </td>
                              <td>
                                <span class="saas-badge-danger">
                                  ${Number(s.warnings || 0)} infractions (${maxWarnings} max)
                                </span>
                              </td>
                              <td style="font-size:12px;color:#9ca3af;">
                                ${esc(formatDate(s.updated_at))}
                              </td>
                              <td style="text-align:right;">
                                <button class="saas-btn saas-btn-warning" data-action="unlock" data-user="${esc(s.user_id)}" style="font-weight:700;">
                                  ${I("unlock", 13)} Approve Re-entry (Grant +1 Warning)
                                </button>
                              </td>
                            </tr>
                          `,
                        )
                        .join("")
                    : `<tr><td colspan="4" style="text-align:center;padding:48px 24px;color:#6b7280;">
                         <div style="margin-bottom:8px;">${I("check", 28, "#10b981")}</div>
                         <div style="font-weight:700;color:#d1d5db;margin-bottom:4px;">No Locked Candidates</div>
                         <div>All candidates are adhering to exam window security rules.</div>
                       </td></tr>`
                }
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    if (tab === "leave_log") {
      const audits = app.auditEvents || [];
      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div style="font-weight:700;color:#f9fafb;display:flex;align-items:center;gap:8px;">
              ${I("clock", 16, "#38bdf8")}
              Candidate Telemetry &amp; Security Infraction Log
            </div>
            <button class="saas-btn" data-action="audit" style="font-size:11px;padding:4px 10px;">
              ${I("refresh", 12)} Refresh Audit Logs
            </button>
          </div>
          <div style="overflow-x:auto;">
            <table class="saas-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Actor / Student</th>
                  <th>Event Description</th>
                  <th>Details</th>
                </tr>
              </thead>
              <tbody>
                ${
                  audits.length
                    ? audits
                        .map(
                          (a) => `
                            <tr>
                              <td style="font-family:ui-monospace,monospace;font-size:11px;color:#9ca3af;">
                                ${esc(formatDate(a.created_at))}
                              </td>
                              <td>
                                <div style="font-weight:600;color:#f9fafb;">${esc(a.actor?.name || a.actor?.email || "System / Telemetry")}</div>
                                ${a.actor?.email ? `<small style="color:#6b7280;">${esc(a.actor.email)}</small>` : ""}
                              </td>
                              <td>
                                <span class="saas-badge-${String(a.event).includes("event") || String(a.event).includes("lock") ? "danger" : "muted"}">
                                  ${esc(a.event)}
                                </span>
                              </td>
                              <td style="font-size:12px;color:#d1d5db;">
                                ${esc(a.details ? JSON.stringify(a.details) : "—")}
                              </td>
                            </tr>
                          `,
                        )
                        .join("")
                    : `<tr><td colspan="4" style="text-align:center;padding:48px 24px;color:#6b7280;">
                         <div>No audit events loaded yet. Press <b>Refresh Audit Logs</b> to fetch server records.</div>
                       </td></tr>`
                }
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    if (tab === "builder") {
      return `
        <div>
          <div style="margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;">
            <div style="font-size:14px;font-weight:700;color:#f9fafb;">Questions Bank (${e.questions?.length || 0})</div>
            ${e.status === "draft" ? '<button class="saas-btn saas-btn-primary" data-action="edit-json">Edit Imported JSON</button>' : ""}
          </div>
          ${managerQuestions(e.questions || [])}
        </div>
      `;
    }

    if (tab === "whitelist") {
      const enrollments = Array.isArray(e.enrollments) ? e.enrollments : [];
      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div style="font-weight:700;color:#f9fafb;display:flex;align-items:center;gap:8px;">
              ${I("users", 16, "#34d399")}
              Enrolled Candidates Whitelist (${enrollments.length})
            </div>
            <button class="saas-btn saas-btn-primary" data-action="edit-enrollments">
              ${I("settings", 13)} Edit Candidate Whitelist
            </button>
          </div>
          <div style="padding:20px;">
            ${
              enrollments.length
                ? `<div style="display:grid;grid-template-columns:repeat(auto-fill, minmax(280px, 1fr));gap:10px;">
                    ${enrollments
                      .map(
                        (en) => `
                          <div style="background:#141414;border:1px solid #222;border-radius:8px;padding:10px 14px;font-size:13px;display:flex;align-items:center;gap:10px;">
                            ${I("check", 14, "#10b981")}
                            <span style="color:#f9fafb;font-family:ui-monospace,monospace;">${esc(en.email || en)}</span>
                          </div>
                        `,
                      )
                      .join("")}
                  </div>`
                : '<p style="color:#9ca3af;">No candidate emails enrolled yet. Click <b>Edit Candidate Whitelist</b> to add student emails.</p>'
            }
          </div>
        </div>
      `;
    }

    return "";
  }
  /* What a student sees for one exam: where it stands, the next step, then the facts. */
  function studentDetail(e, state) {
    const sess = state.session || {};
    const start = examDay(e.scheduled_at);
    const end = examDay(e.closes_at);
    const [label, tone] = e.closed ? ["Closed", "ended"] : STUDENT_STATUS[e.status] || [e.status || "Draft", "draft"];
    const questions = Number(e.questions?.length || e.question_count || 0);
    const warnings = Number(e.max_warnings || 3);
    const score = sess.score != null && e.results_published ? `${Number(sess.score)} / ${Number(sess.total_marks || 0)}` : "";
    const join = (text) => `<button class="ep-btn ep-btn-primary" data-action="join">${text}</button>`;
    const check = '<button class="ep-btn" data-action="refresh-state">Check again</button>';
    let next;
    if (sess.status === "submitted")
      next = ["done", "You have submitted this exam", score ? `Your score is ${score}.` : "Your answers are recorded. Your score appears here once results are published.", score ? "" : check];
    else if (e.status === "ended" || e.status === "archived" || e.closed)
      next = ["", "This exam has ended", score ? `Your score is ${score}.` : sess.status ? "Your score appears here once results are published." : "You did not join this exam.", ""];
    else if (sess.status === "locked")
      next = ["warn", "Your session is locked", "You reached the warning limit. Wait for the exam manager to review and unlock your session.", check];
    else if (e.status === "live")
      next = ["live", sess.status === "in_exam" ? "Your exam is in progress" : "The exam is live", sess.status === "in_exam" ? "Go back in to continue. The timer has kept running." : "Read the rules, tick the box to agree, and the exam opens. The timer is already running for everyone.", join(sess.status === "in_exam" ? "Return to exam" : "Read rules and join")];
    else if (e.status === "paused")
      next = ["warn", "The exam is paused", "The exam manager has paused it. Your answers are saved. You can continue when it resumes.", check];
    else
      next = ["", "This exam has not started yet", `The Join button appears here once your exam manager starts the exam${start ? `, planned for ${start.text}` : ""}. Keep this page open, or press Check again.`, check];
    const fact = (name, value) => `<div><dt>${name}</dt><dd>${esc(value)}</dd></div>`;
    return `<section class="ep-page ep-student-detail"><div class="ep-back"><button class="ep-btn ep-btn-quiet" data-action="back">← Exams</button></div><div class="ep-heading"><div><p class="ep-eyebrow">ONLINE EXAM</p><h1>${esc(e.title)}</h1>${e.subject ? `<p>${esc(e.subject)}</p>` : ""}</div><span class="ep-status ${tone}">${esc(label)}</span></div>${app.error ? `<div class="ep-alert error">${esc(app.error)}</div>` : ""}<div class="ep-card ep-next ${next[0]}"><div><h2>${next[1]}</h2><p>${esc(next[2])}</p></div>${next[3] ? `<div class="ep-actions">${next[3]}</div>` : ""}</div><dl class="ep-facts ep-facts-row">${fact("Starts", start ? start.text : "Not set")}${fact("Ends", end ? end.text : "When time runs out")}${fact("Duration", `${Number(e.duration_minutes || 0)} minutes`)}${fact("Questions", questions)}</dl><div class="ep-student-cols"><div class="ep-card"><h2>Instructions</h2><p class="ep-instructions">${contentHtml(e.instructions || "No additional instructions.")}</p></div><div class="ep-card"><h2>How joining works</h2><ol class="ep-steps"><li>Your exam manager starts the exam. This page then shows <b>Read rules and join</b>.</li><li>Read the rules and tick the box to agree. The exam opens in full screen.</li><li>One timer runs for everyone, so joining late does not add time.</li><li>Leaving full screen or switching tabs counts as a warning. ${warnings} warning${warnings === 1 ? "" : "s"} lock your session.</li></ol></div></div></section>`;
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
    const step = app.onboardingStep || 1;

    let content = "";
    if (step === 1) {
      content = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge" style="background:#e0f2fe;">
            ${I("shield", 36, "#0284c7")}
          </div>
          <h2 class="ep-onboarding-title">Exam Environment Check</h2>
          <p class="ep-onboarding-text">
            Please confirm your testing workspace meets GenZ IITian academic integrity standards:
          </p>
          <div class="ep-checklist-box">
            <div class="ep-checklist-item">
              ${I("lock", 16, "#059669")}
              <div><b>Locked &amp; Private Room:</b> Ensure you are alone with no other persons present.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("volumeX", 16, "#059669")}
              <div><b>Zero Noise:</b> No background conversation, audio devices, or music.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("wifi", 16, "#059669")}
              <div><b>Stable Network:</b> Ensure unlimited high-speed data or uninterrupted Wi-Fi.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("shield", 16, "#059669")}
              <div><b>Zero Cheating Tolerance:</b> No secondary devices, paper notes, or browser extensions.</div>
            </div>
          </div>
          <button type="button" class="ep-modal-btn" data-action="onboard-step-2" style="background:#059669;box-shadow:0 4px 14px rgba(5,150,105,0.3);">
            Proceed to Attendance →
          </button>
          <div class="ep-modal-stepper">
            <span class="ep-stepper-dot active"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
          </div>
        </div>
      `;
    } else if (step === 2) {
      content = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge" style="background:#e2e8f0;">
            <svg width="40" height="40" viewBox="0 0 24 24" fill="#334155" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" fill="#334155"/>
              <path d="M8 12.3L10.7 15L16.3 9.4" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h2 class="ep-onboarding-title">Record my Attendance</h2>
          <p class="ep-onboarding-text" style="font-size:13.5px;color:#334155;line-height:1.65;margin-bottom:24px;">
            By marking your attendance, you confirm your presence for the exam. Please note that once your attendance is recorded, any exit from the exam session will be registered and could affect your ability to continue. Make sure you're ready before proceeding. If you face any technical issues, reach out to support immediately
          </p>
          <button type="button" class="ep-modal-btn" data-action="onboard-step-3" style="background:#475569;">
            Confirm Attendance
          </button>
          <div class="ep-modal-stepper">
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot active"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
          </div>
        </div>
      `;
    } else if (step === 3) {
      content = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge" style="background:#e0f2fe;">
            ${I("camera", 36, "#0284c7")}
          </div>
          <h2 class="ep-onboarding-title">Live Identity Capture</h2>
          <p class="ep-onboarding-text" style="margin-bottom:14px;">
            Position your face inside the frame. Live camera verification will be logged.
          </p>
          <div class="ep-cam-viewfinder">
            <video id="ep-cam-stream" class="ep-cam-video" autoplay playsinline muted></video>
            <canvas id="ep-cam-canvas" width="320" height="240" style="display:none;"></canvas>
            <img id="ep-cam-snapshot" class="ep-cam-preview-img" style="display:${app.photoDataUrl ? "block" : "none"};" ${app.photoDataUrl ? `src="${app.photoDataUrl}"` : ""} />
            <div id="ep-cam-fallback-tag" style="display:none;position:absolute;bottom:8px;left:8px;font-size:10px;background:rgba(0,0,0,0.6);color:#fff;padding:2px 6px;border-radius:4px;">
              Live Viewfinder
            </div>
          </div>
          <div id="ep-cam-action-bar" style="width:100%;display:${app.photoDataUrl ? "none" : "block"};">
            <button type="button" id="ep-btn-take-photo" class="ep-modal-btn" data-action="take-selfie" style="background:#059669;display:flex;align-items:center;justify-content:center;gap:8px;">
              ${I("camera", 16, "#ffffff")} Capture Photo
            </button>
          </div>
          <div id="ep-cam-confirm-bar" style="display:${app.photoDataUrl ? "flex" : "none"};width:100%;gap:10px;">
            <button type="button" id="ep-btn-retake-photo" class="ep-modal-btn" data-action="retake-selfie" style="background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;flex:1;display:flex;align-items:center;justify-content:center;gap:6px;">
              ${I("refresh", 14, "#334155")} Retake
            </button>
            <button type="button" id="ep-btn-confirm-photo" class="ep-modal-btn" data-action="onboard-step-4" style="background:#059669;flex:1;display:flex;align-items:center;justify-content:center;gap:6px;">
              ${I("check", 14, "#ffffff")} Confirm Photo
            </button>
          </div>
          <div class="ep-modal-stepper">
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot active"></span>
            <span class="ep-stepper-dot"></span>
          </div>
        </div>
      `;
    } else {
      content = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge" style="background:#fef3c7;">
            ${I("fileText", 36, "#d97706")}
          </div>
          <h2 class="ep-onboarding-title" style="margin-bottom:6px;">
            Exam Protocol &amp; Final Agreement
          </h2>
          <div class="ep-checklist-box" style="font-size:12.5px;">
            <div class="ep-checklist-item">
              ${I("slash", 16, "#dc2626")}
              <div><b>No Window Leaving:</b> You are NOT permitted to leave or minimize this window. Any exit locks access and requires manager review.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("slash", 16, "#dc2626")}
              <div><b>No Tab Switching:</b> You are NOT permitted to open any other tab. Doing so triggers infraction warnings.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("clock", 16, "#059669")}
              <div><b>Auto-Submission:</b> Your answers will automatically submit when the exam timer ends.</div>
            </div>
            <div class="ep-checklist-item">
              ${I("lock", 16, "#475569")}
              <div><b>Integrity Guard:</b> Copy/paste, double-clicking, and text selections are locked.</div>
            </div>
          </div>
          <label style="display:flex;align-items:center;gap:10px;font-size:13px;font-weight:600;color:#334155;cursor:pointer;margin-bottom:20px;text-align:left;width:100%;">
            <input type="checkbox" id="ep-cb-agree" style="width:17px;height:17px;accent-color:#059669;cursor:pointer;" />
            <span>I understand and agree to all examination rules.</span>
          </label>
          <button type="button" id="ep-btn-final-enter" class="ep-modal-btn" data-action="join-confirm" disabled style="background:#94a3b8;color:#ffffff;cursor:not-allowed;box-shadow:none;">
            I Agree &amp; Start Exam
          </button>
          <div class="ep-modal-stepper">
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot active"></span>
          </div>
        </div>
      `;
    }

    return `<div id="ep-root" style="display:flex;align-items:center;justify-content:center;min-height:85vh;padding:24px;">${content}</div>`;
  }
  /* The exam screen: header with timer and Submit, question palette on the left,
     one question at a time. Layout follows the exam portal's live exam view. */
  const ROOM_TYPE = {
    mcq_single: "MCQ SINGLE",
    mcq_multi: "MCQ MULTI",
    true_false: "TRUE FALSE",
    numerical: "NUMERICAL",
    short_answer: "SHORT ANSWER",
    comprehension: "PASSAGE",
  };
  const roomKey = () => `ep_room:${app.exam?.id || ""}`;
  function roomMemory() {
    if (app.roomFor === app.exam?.id) return;
    app.roomFor = app.exam?.id;
    app.roomIndex = 0;
    app.review = {};
    try {
      const saved = JSON.parse(sessionStorage.getItem(roomKey()) || "{}");
      app.roomIndex = Number(saved.index) || 0;
      app.review = saved.review && typeof saved.review === "object" ? saved.review : {};
    } catch (_) {}
  }
  function rememberRoom() {
    try {
      sessionStorage.setItem(roomKey(), JSON.stringify({ index: app.roomIndex, review: app.review }));
    } catch (_) {}
  }
  function roomAnswered(q) {
    const v = app.draftAnswers[q.id];
    return q.type !== "comprehension" && !(v === undefined || v === null || v === "" || (Array.isArray(v) && !v.length));
  }
  function roomLabelStyle(checked) {
    return `display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:10px;border:1.5px solid ${checked ? "#059669" : "#e2e8f0"};background:${checked ? "#f0fdf4" : "#ffffff"};cursor:pointer;transition:all 0.15s ease;`;
  }
  function roomInputs(q, locked) {
    const val = app.draftAnswers[q.id];
    const off = locked ? "disabled" : "";
    if (["mcq_single", "true_false"].includes(q.type))
      return `<div style="display:flex;flex-direction:column;gap:10px;">${(q.options || (q.type === "true_false" ? ["True", "False"] : []))
        .map((o, j) => {
          const ans = q.type === "true_false" ? j === 0 : j;
          const checked = val != null && String(val) === String(ans);
          return `<label style="${roomLabelStyle(checked)}"><input type="radio" name="answer-${esc(q.id)}" data-answer="${esc(q.id)}" value="${q.type === "true_false" ? String(ans) : j}" ${checked ? "checked" : ""} ${off} style="width:16px;height:16px;accent-color:#059669;flex-shrink:0;" /><span style="font-size:14px;color:#1e293b;font-weight:500;min-width:0;flex:1;">${contentHtml(o)}</span></label>`;
        })
        .join("")}</div>`;
    if (q.type === "mcq_multi")
      return `<div style="display:flex;flex-direction:column;gap:10px;">${(q.options || [])
        .map((o, j) => {
          const checked = Array.isArray(val) && val.map(String).includes(String(j));
          return `<label style="${roomLabelStyle(checked)}"><input type="checkbox" data-answer-multi="${esc(q.id)}" value="${j}" ${checked ? "checked" : ""} ${off} style="width:16px;height:16px;accent-color:#059669;flex-shrink:0;" /><span style="font-size:14px;color:#1e293b;font-weight:500;min-width:0;flex:1;">${contentHtml(o)}</span></label>`;
        })
        .join("")}</div>`;
    if (q.type === "comprehension")
      return '<p style="font-size:12px;color:#64748b;margin:0;">This passage is provided for the questions that follow.</p>';
    const numeric = q.type === "numerical";
    return `<div><label style="display:block;font-size:12px;font-weight:700;color:#64748b;margin-bottom:6px;">${numeric ? "Enter Numerical Answer:" : "Enter Short Answer:"}</label><input type="text" ${numeric ? 'inputmode="decimal"' : ""} autocomplete="off" maxlength="2000" data-answer-text="${esc(q.id)}" value="${esc(val ?? "")}" placeholder="${numeric ? "e.g. 42" : "Type your answer here..."}" ${off} style="background:#fff;border:1.5px solid #cbd5e1;padding:10px 14px;border-radius:8px;font-size:${numeric ? 15 : 14}px;width:${numeric ? 240 : 320}px;max-width:100%;color:#0f172a;outline:none;" /></div>`;
  }
  function roomPalette() {
    return (app.exam?.questions || [])
      .map((q, i) => {
        const status = app.review[q.id] ? "ep-q-review" : roomAnswered(q) ? "ep-q-answered" : "ep-q-unvisited";
        const isCurrent = i === app.roomIndex && app.activeSection !== "sec-coc";
        return `<button type="button" class="ep-q-btn ${status} ${isCurrent ? "current" : ""}" data-room-go="${i}" aria-label="Question ${i + 1}${status === "ep-q-answered" ? ", answered" : status === "ep-q-review" ? ", marked for review" : ""}">${i + 1}</button>`;
      })
      .join("");
  }
  function roomLegend() {
    const qs = (app.exam?.questions || []).filter((q) => q.type !== "comprehension");
    const answered = qs.filter(roomAnswered).length;
    const review = (app.exam?.questions || []).filter((q) => app.review[q.id]).length;
    const row = (bg, border, text) =>
      `<div style="display:flex;align-items:center;gap:6px;"><span style="width:10px;height:10px;border-radius:3px;background:${bg};border:1px solid ${border};"></span>${text}</div>`;
    return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;">${row("#dcfce7", "#86efac", `Answered (${answered})`)}${row("#ede9fe", "#c4b5fd", `Review (${review})`)}${row("#f1f5f9", "#cbd5e1", `Unanswered (${qs.length - answered})`)}</div>`;
  }
  /* After an answer changes: refresh the palette and option highlights without re-rendering. */
  function refreshRoom() {
    const palette = $("#ep-room-palette");
    if (!palette) return;
    palette.innerHTML = roomPalette();
    const legend = $("#ep-room-legend");
    if (legend) legend.innerHTML = roomLegend();
    document.querySelectorAll("#ep-room-main [data-answer], #ep-room-main [data-answer-multi]").forEach((input) => {
      const label = input.closest("label");
      if (label) label.style.cssText = roomLabelStyle(input.checked);
    });
  }
  function roomGo(index) {
    const total = (app.exam?.questions || []).length;
    if (!total) return;
    app.activeSection = "sec-questions";
    app.roomIndex = Math.min(Math.max(0, index), total - 1);
    rememberRoom();
    render();
    const main = $("#ep-room-main");
    if (main) main.scrollTop = 0;
  }
  function examRoom() {
    const e = app.exam || {},
      s = app.state || {},
      sess = s.session || {};
    if (sess.status === "locked") return renderLockoutScreen(e, sess);
    roomMemory();
    const list = e.questions || [];
    const total = list.length;
    app.roomIndex = Math.min(Math.max(0, app.roomIndex || 0), Math.max(0, total - 1));
    const index = app.roomIndex;
    const q = list[index] || {};
    const passage = q.type === "comprehension";
    const locked = e.status !== "live" || ["locked", "submitted"].includes(sess.status);
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
    const low = secs != null && secs < 300;
    const warnings = Number(sess.warnings || 0);
    const check =
      '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>';
    const canSubmit = e.status === "live" && sess.status === "in_exam";

    const isCocActive = app.activeSection === "sec-coc";
    const sections = [
      { id: "sec-coc", title: "Code of Conduct (COC)", isCoc: true },
      ...(Array.isArray(e.sections) && e.sections.length
        ? e.sections
        : [{ id: "sec-questions", title: e.subject ? `${e.subject} Questions` : "Exam Questions", count: total }])
    ];

    return `<div id="ep-root" class="ep-live-exam-root pr-live-root" style="display:flex;flex-direction:column;overflow:hidden;background:#f8fafc;">
<header class="pr-live-header" style="background:#ffffff;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between;padding:0 clamp(18px, 2vw, 34px);flex-shrink:0;">
<div style="display:flex;align-items:center;gap:12px;min-width:0;"><img src="/assets/quiz-lab-icon.png" alt="Quiz Lab" style="height:32px;width:32px;border-radius:9px;flex-shrink:0;"><div style="min-width:0;"><h1 style="font-size:clamp(14px, 1.15vw, 21px);font-weight:800;color:#0f172a;margin:0;overflow-wrap:anywhere;">${esc(e.title)}</h1><div style="font-size:clamp(11px, 0.9vw, 15px);color:#64748b;">${esc(app.user?.name || "")}${app.user?.email ? ` (${esc(app.user.email)})` : ""}</div></div></div>
<div class="pr-live-tools" style="display:flex;align-items:center;gap:10px;">
<span class="ep-status ${esc(e.status)}">${esc(e.status)}</span>
<div id="ep-warning-chip" class="ep-header-warning ${warnings > 0 ? "warning-active" : ""}">Warnings: <b>${warnings}</b></div>
<div style="display:flex;align-items:center;gap:6px;background:#f1f5f9;padding:6px 12px;border-radius:8px;border:1px solid #cbd5e1;"><span style="width:8px;height:8px;border-radius:9999px;background:${low ? "#ef4444" : "#059669"};animation:ep-pulse 2s infinite;"></span><span style="font-size:11px;font-weight:700;color:#64748b;">Time:</span><span id="ep-countdown" style="font-size:15px;font-weight:800;color:${low ? "#ef4444" : "#0f172a"};font-family:ui-monospace,monospace;">${secs == null ? "—" : formatClock(secs)}</span></div>
<button type="button" class="ep-btn ep-btn-quiet" data-action="fullscreen">Fullscreen</button>
<button type="button" id="btn-student-submit" data-action="submit-exam" ${canSubmit ? "" : "disabled"} style="background:#059669;border:none;color:#fff;padding:7px 18px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:6px;box-shadow:0 1px 3px rgba(5,150,105,0.3);">${check} Submit &amp; Exit</button>
</div></header>
<div class="pr-live-body" style="display:flex;flex:1;overflow:hidden;">
<aside id="ep-sidebar" class="pr-live-aside" style="width:clamp(280px, 24vw, 380px);background:#ffffff;border-right:2px solid #0f172a;display:flex;flex-direction:column;flex-shrink:0;">

  <!-- Sections (before Question Palette) -->
  <div class="pr-live-sections" style="padding:14px 16px;border-bottom:1px solid #e2e8f0;background:#f8fafc;">
    <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:8px;display:flex;align-items:center;justify-content:space-between;">
      <span>Sections</span>
      <span style="font-size:10px;color:#94a3b8;">${sections.length} sections</span>
    </div>
    <div style="display:flex;flex-direction:column;gap:6px;">
      ${sections.map((sec) => {
        const isCoc = sec.id === "sec-coc";
        const isActive = isCoc ? isCocActive : !isCocActive && (app.activeSection === sec.id || (!app.activeSection && sec.id === "sec-questions"));
        const secQCount = isCoc ? null : sec.questions ? sec.questions.length : total;
        return `
          <button type="button" class="ep-sec-tab-btn" data-sec-id="${esc(sec.id)}" style="display:flex;align-items:center;justify-content:space-between;padding:8px 12px;border-radius:8px;border:1.5px solid ${isActive ? "#059669" : "#e2e8f0"};background:${isActive ? "#f0fdf4" : "#ffffff"};color:${isActive ? "#065f46" : "#334155"};font-weight:${isActive ? "800" : "600"};font-size:12.5px;cursor:pointer;text-align:left;transition:all 0.15s ease;">
            <span style="display:flex;align-items:center;gap:7px;">
              ${isCoc ? I("shield", 14, isActive ? "#059669" : "#64748b") : I("fileText", 13, isActive ? "#059669" : "#94a3b8")}
              ${esc(sec.title)}
            </span>
            ${isCoc ? '<span style="font-size:10px;font-weight:800;background:#dbeafe;color:#1e40af;padding:2px 6px;border-radius:4px;">RULES</span>' : `<span style="font-size:11px;color:#64748b;font-weight:700;">(${secQCount})</span>`}
          </button>
        `;
      }).join("")}
    </div>
  </div>

  <!-- Question Palette -->
  <div class="pr-live-palette" style="flex:1;overflow-y:auto;padding:16px;">
    <div class="pr-live-palette-title" style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:12px;">Question Palette</div>
    <div class="ep-q-grid" id="ep-room-palette">${roomPalette()}</div>
  </div>

  <!-- Tools (Merged calculator & doubts in same row, save button removed) -->
  <div class="pr-live-tools-box" style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#ffffff;">
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
      <button type="button" data-calc="toggle" title="Open Calculator" style="background:#f0fdf4;border:1.5px solid #86efac;color:#047857;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:6px;">
        ${I("calculator", 14, "#047857")} Calculator
      </button>
      <button type="button" data-action="messages" title="Doubts and messages" style="background:#0f172a;border:1px solid #334155;color:#fff;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:6px;">
        ${I("message", 14, "#fff")} Doubts &amp; Messages
      </button>
    </div>
  </div>

  <!-- Legend -->
  <div class="pr-live-legend" id="ep-room-legend" style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#f8fafc;font-size:11px;color:#475569;">${roomLegend()}</div>
</aside>

<main class="pr-live-main" id="ep-room-main" style="flex:1;display:flex;flex-direction:column;overflow-y:auto;padding:clamp(22px, 2vw, 42px) clamp(28px, 3vw, 58px);background:#ffffff;">
  ${e.status === "paused" ? '<div class="ep-alert">The manager has paused this exam. Answers remain saved. You can continue when it resumes.</div>' : ""}
  ${isCocActive ? `
    <div class="pr-live-coc-view" style="max-width:880px;padding:10px 0;">
      <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px;padding-bottom:14px;border-bottom:1px solid #e2e8f0;">
        <img src="/assets/quiz-lab-icon.png" alt="Quiz Lab" style="height:32px;width:32px;border-radius:8px;object-fit:contain;">
        <div>
          <h2 style="font-size:18px;font-weight:800;color:#0f172a;margin:0;">Candidate Code of Conduct &amp; Remote Proctoring Rules</h2>
          <div style="font-size:12px;color:#64748b;">Quiz LAB Academic Integrity &amp; Infraction Policy</div>
        </div>
      </div>

      <h3 style="font-size:15px;font-weight:800;color:#1e3a8a;margin:0 0 10px 0;">
        Online Remote Proctored Exams
      </h3>
      <p style="font-size:13.5px;color:#334155;line-height:1.65;margin-bottom:20px;">
        This exam is conducted online from the examinee's place of residence and proctored remotely by the Quiz Lab team. The following guidelines must be followed by all examinees at all times during the examination:
      </p>

      <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(260px, 1fr));gap:14px;margin-bottom:24px;">
        ${[
          ["1. Personal details", "No examinee shall share personal details with proctors, including but not limited to phone number or address, during or after the exam."],
          ["2. Clean desk", "The table or desk where the examinee takes this exam shall not have any items kept that may have sensitive information, including but not limited to phone numbers and address."],
          ["3. No assistance", "No examinee shall aid, or attempt to aid, another candidate by discussing answers via email, text, chat, call, or any other method."],
          ["4. Confidential exam", "No examinee will disclose any details of what happened during the exam or examination trials to anyone outside."],
          ["5. Ask inside exam", "If an examinee wishes to ask a question during the exam, they should post the query in the exam room chat / doubts window and the proctor will clarify the issue."],
          ["6. Violation action", "If any examinee is found to have violated the Code of Conduct for Online Examinations, or to have acted improperly, they will be liable to disciplinary procedures. This can include withholding exam results, suspension, or termination from the program."]
        ]
          .map(
            ([title, body]) => `
              <div style="border:1.5px solid #e2e8f0;background:#f8fafc;border-radius:12px;padding:14px 16px;">
                <div style="font-size:13px;font-weight:800;color:#0f172a;margin-bottom:6px;">${title}</div>
                <div style="font-size:12.5px;line-height:1.55;color:#475569;">${body}</div>
              </div>
            `
          )
          .join("")}
      </div>

      <div style="padding-top:18px;border-top:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;">
        <div style="font-size:12px;color:#059669;font-weight:700;display:flex;align-items:center;gap:6px;">
          ${I("check", 14, "#059669")} You agreed to follow this Code of Conduct upon entering the exam.
        </div>
        <button type="button" data-action="coc-back-to-questions" class="ep-btn ep-btn-primary" style="background:#059669;color:#fff;border:none;padding:10px 22px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:8px;">
          Back to Exam Questions →
        </button>
      </div>
    </div>
  ` : `
    <article class="ep-question" data-question-id="${esc(q.id)}">
    <div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;border-bottom:1px solid #e2e8f0;padding-bottom:12px;margin-bottom:18px;"><div style="display:flex;align-items:center;gap:10px;"><span style="font-size:17px;font-weight:800;color:#0f172a;">Question ${index + 1} of ${total}</span><span style="padding:3px 8px;border-radius:6px;background:#e0f2fe;color:#0369a1;font-size:11px;font-weight:700;">${esc(ROOM_TYPE[q.type] || String(q.type || "").toUpperCase())}</span></div>${passage ? "" : `<div style="font-size:12px;font-weight:700;color:#059669;">+${Number(q.marks || 0)} Marks${Number(q.negative) ? ` | -${Number(q.negative)} Negative` : ""}</div>`}</div>
    <div class="pr-live-prompt" style="font-size:15px;color:#0f172a;line-height:1.6;font-weight:500;margin-bottom:14px;">${contentHtml(q.prompt)}</div>
    <div style="margin-bottom:28px;">${roomInputs(q, locked)}</div>
    </article>
    <div style="display:none;" aria-hidden="true">${list.map((item, i) => i === index ? "" : `<div class="ep-question" data-question-id="${esc(item.id)}">${contentHtml(item.prompt)}</div>`).join("")}</div>
    <div class="pr-live-actions" style="margin-top:auto;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap;border-top:1px solid #e2e8f0;padding-top:18px;"><div style="display:flex;gap:8px;"><button type="button" data-action="room-prev" ${index === 0 ? "disabled" : ""} style="background:#fff;border:1px solid #cbd5e1;color:#475569;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">← Prev</button>${passage ? "" : `<button type="button" data-action="clear-answer" data-id="${esc(q.id)}" ${locked ? "disabled" : ""} style="background:#fff;border:1px solid #cbd5e1;color:#64748b;padding:9px 14px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">Clear</button>`}</div><div style="display:flex;gap:8px;">${passage ? "" : `<button type="button" data-action="room-review" style="background:#f5f3ff;border:1px solid #c4b5fd;color:#6d28d9;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">${app.review[q.id] ? "Marked for Review" : "Review &amp; Next"}</button>`}<button type="button" data-action="room-next" style="background:#059669;color:#fff;border:none;padding:9px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">${index === total - 1 ? "Save Response" : passage ? "Next →" : "Save &amp; Next →"}</button></div></div>
  `}
</main></div></div>`;
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
    document.getElementById("ep-app")?.classList.toggle("pr-live", app.screen === "room");
    if (app.screen !== "room") window.ExamCalculator?.close();
    if (app.screen === "rules" && app.onboardingStep === 3) {
      setTimeout(startWebcam, 50);
    } else {
      stopWebcam();
    }
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
    refreshRoom();
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
            const maxAllowed = Number(app.exam?.max_warnings || 3);
            const warnings = Number(d.session?.warnings || 0);
            if (d.session?.status === "locked" || warnings >= maxAllowed) {
              document.getElementById("ep-tab-warning-modal")?.remove();
              app.isTabWarningModalOpen = false;
            } else if (!app.isTabWarningModalOpen && app.screen === "room") {
              const outsideSecs = app.lastAwaySeconds || 1;
              showTabSwitchWarningModal(warnings, maxAllowed, outsideSecs);
            }
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
    const jump = ev.target.closest("[data-room-go]");
    if (jump) return void roomGo(Number(jump.dataset.roomGo));
    const secBtn = ev.target.closest("[data-sec-id]");
    if (secBtn) {
      app.activeSection = secBtn.dataset.secId;
      render();
      return;
    }
    const calc = ev.target.closest("[data-calc]");
    if (calc) {
      const mode = calc.dataset.calc;
      window.ExamCalculator?.toggle(mode === "toggle" ? undefined : mode);
      return;
    }
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
      if (action === "room-prev") return void roomGo(app.roomIndex - 1);
      if (action === "room-next") {
        if (app.dirty && app.exam?.status === "live") saveAnswers().catch(() => {});
        return void roomGo(app.roomIndex + 1);
      }
      if (action === "room-review") {
        const q = (app.exam?.questions || [])[app.roomIndex];
        if (!q) return;
        if (app.review[q.id]) {
          delete app.review[q.id];
          rememberRoom();
          render();
        } else {
          app.review[q.id] = true;
          roomGo(app.roomIndex + 1);
        }
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
      if (action === "system-check") {
        app.system = await request("/manager/system/status");
        render();
        return;
      }
      if (action === "system-migrate") {
        const result = await request("/manager/system/migrate", { method: "POST" });
        app.system = result;
        app.error = "";
        try {
          await loadList();
          if (result.up_to_date) app.system = null;
        } catch (e) {
          app.error = e.message;
        }
        render();
        flash(result.up_to_date ? "Database updated. Exams are ready." : "The update ran, but some items are still pending.", !result.up_to_date);
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
      if (action === "extend" || action === "ext-5") {
        await act("extend", { minutes: 5 });
        await loadState();
        flash("Exam time extended by 5 minutes.");
        return;
      }
      if (action === "ext-10") {
        await act("extend", { minutes: 10 });
        await loadState();
        flash("Exam time extended by 10 minutes.");
        return;
      }
      if (action === "ext-15") {
        await act("extend", { minutes: 15 });
        await loadState();
        flash("Exam time extended by 15 minutes.");
        return;
      }
      if (action === "mgr-tab") {
        app.mgrTab = b.dataset.tab;
        if (b.dataset.tab === "leave_log" && !app.auditEvents) {
          try {
            const d = await request(
              `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/audit`,
            );
            app.auditEvents = d.audit || [];
            app.auditBefore = d.next_before || null;
          } catch (_) {}
        }
        render();
        return;
      }
      if (action === "audit") {
        try {
          const d = await request(
            `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/audit`,
          );
          app.auditEvents = d.audit || [];
          app.auditBefore = d.next_before || null;
          app.mgrTab = "leave_log";
          render();
          flash("Audit logs updated.");
        } catch (e) {
          flash(e.message, true);
        }
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
        flash(
          action === "unlock"
            ? "Candidate re-entry approved. Allowed back into exam."
            : "Candidate session locked.",
        );
        return;
      }
      if (action === "refresh-state") {
        await loadState();
        flash("State updated.");
        return;
      }
      if (action === "join") {
        app.onboardingStep = 1;
        app.screen = "rules";
        render();
        return;
      }
      if (action === "onboard-step-2") {
        app.onboardingStep = 2;
        render();
        return;
      }
      if (action === "onboard-step-3") {
        app.attendanceTime = new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
        app.onboardingStep = 3;
        render();
        return;
      }
      if (action === "take-selfie") {
        const video = document.getElementById("ep-cam-stream");
        const canvas = document.getElementById("ep-cam-canvas");
        const snapshotImg = document.getElementById("ep-cam-snapshot");
        const actionBar = document.getElementById("ep-cam-action-bar");
        const confirmBar = document.getElementById("ep-cam-confirm-bar");
        if (canvas) {
          const ctx = canvas.getContext("2d");
          if (video && video.videoWidth > 0) {
            ctx.drawImage(video, 0, 0, 320, 240);
          } else {
            simulateCanvasCamera(canvas, video);
          }
          app.photoDataUrl = canvas.toDataURL("image/jpeg");
          if (snapshotImg) {
            snapshotImg.src = app.photoDataUrl;
            snapshotImg.style.display = "block";
          }
          if (video) video.style.display = "none";
          if (actionBar) actionBar.style.display = "none";
          if (confirmBar) confirmBar.style.display = "flex";
        }
        return;
      }
      if (action === "retake-selfie") {
        app.photoDataUrl = null;
        const video = document.getElementById("ep-cam-stream");
        const snapshotImg = document.getElementById("ep-cam-snapshot");
        const actionBar = document.getElementById("ep-cam-action-bar");
        const confirmBar = document.getElementById("ep-cam-confirm-bar");
        if (video) video.style.display = "block";
        if (snapshotImg) snapshotImg.style.display = "none";
        if (actionBar) actionBar.style.display = "block";
        if (confirmBar) confirmBar.style.display = "none";
        return;
      }
      if (action === "onboard-step-4") {
        stopWebcam();
        app.onboardingStep = 4;
        render();
        return;
      }
      if (action === "join-confirm") {
        await fullscreen();
        const cb = $("#ep-cb-agree") || $("#ep-rules-check");
        if (cb && !cb.checked)
          throw new Error("Please accept the exam rules before continuing.");
        await request(
          `/exam-platform/exams/${encodeURIComponent(app.exam.id)}/join`,
          { method: "POST", body: { acceptedRules: true, attendanceRecordedAt: app.attendanceTime } },
        );
        await loadState();
        app.draftAnswers = { ...(app.state.session?.answers || {}) };
        app.activeSection = "sec-questions";
        app.screen = "room";
        render();
        startPolling();
        return;
      }
      if (action === "open-coc") {
        showCocModal();
        return;
      }
      if (action === "coc-back-to-questions") {
        app.activeSection = "sec-questions";
        render();
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
  function handleTabLeave(reason = "window_blur") {
    if (
      app.screen !== "room" ||
      app.exam?.status !== "live" ||
      app.state?.session?.status !== "in_exam"
    )
      return;
    if (app.hasUserSwitchedAway || app.isTabWarningModalOpen) return;
    app.hasUserSwitchedAway = true;
    app.outsideSince = Date.now();
  }
  async function handleTabReturn(reason = "window_focus") {
    if (
      app.screen !== "room" ||
      app.exam?.status !== "live" ||
      app.state?.session?.status !== "in_exam"
    )
      return;
    if (!app.hasUserSwitchedAway || app.isTabWarningModalOpen) return;
    app.hasUserSwitchedAway = false;
    const outsideSecs = app.outsideSince
      ? Math.max(1, Math.round((Date.now() - app.outsideSince) / 1000))
      : 1;
    app.outsideSince = null;
    app.lastAwaySeconds = outsideSecs;

    const eventType = !document.fullscreenElement
      ? "fullscreen_exit"
      : document.visibilityState === "hidden"
        ? "visibility_hidden"
        : "blur";

    await event(eventType);
  }
  function onBlur() {
    handleTabLeave("window_blur");
  }
  function onFocus() {
    handleTabReturn("window_focus");
  }
  function onVisibility() {
    if (document.visibilityState === "hidden") {
      handleTabLeave("visibility_hidden");
    } else {
      handleTabReturn("visibility_visible");
    }
  }
  function onFullscreen() {
    if (!document.fullscreenElement) {
      handleTabLeave("fullscreen_exit");
      handleTabReturn("fullscreen_exit");
    }
  }
  function onInput(ev) {
    const t = ev.target;
    if (t.matches("#ep-candidate-search")) {
      app.candidateSearch = t.value;
      const root = $("#ep-content");
      if (root) render();
    }
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
    if (t.matches("#ep-cb-agree")) {
      const btn = document.getElementById("ep-btn-final-enter");
      if (btn) {
        btn.disabled = !t.checked;
        btn.style.background = t.checked ? "#059669" : "#94a3b8";
        btn.style.cursor = t.checked ? "pointer" : "not-allowed";
        btn.style.boxShadow = t.checked ? "0 4px 14px rgba(5,150,105,0.3)" : "none";
      }
      return;
    }
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
  window.addEventListener("focus", onFocus);
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
