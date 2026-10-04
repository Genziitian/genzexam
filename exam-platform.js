// Exam Platform - Academic Focus & Obsidian Proctor B2B SaaS Engine
// Zero DB Localhost Engine - Client-Side Synchronized via localStorage
(function () {
  const STORAGE_KEY = "ep_exam_state_v1";

  // Clean Vector Icon Generator (Enterprise B2B SaaS Style - No Emojis)
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
      case "checkCircle":
        return `<svg ${s}><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>`;
      case "wifi":
        return `<svg ${s}><path d="M5 12.55a11 11 0 0 1 14.08 0M1.42 9a16 16 0 0 1 21.16 0M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01"/></svg>`;
      case "volumeX":
        return `<svg ${s}><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>`;
      case "fileText":
        return `<svg ${s}><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>`;
      case "clock":
        return `<svg ${s}><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;
      case "logOut":
        return `<svg ${s}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>`;
      case "message":
        return `<svg ${s}><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`;
      case "broadcast":
        return `<svg ${s}><circle cx="12" cy="12" r="2"/><path d="M16.24 7.76a6 6 0 0 1 0 8.49m-8.48-.01a6 6 0 0 1 0-8.49m11.31-2.82a10 10 0 0 1 0 14.14m-14.14 0a10 10 0 0 1 0-14.14"/></svg>`;
      case "download":
        return `<svg ${s}><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`;
      case "pause":
        return `<svg ${s}><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`;
      case "play":
        return `<svg ${s}><polygon points="5 3 19 12 5 21 5 3"/></svg>`;
      case "square":
        return `<svg ${s}><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/></svg>`;
      case "settings":
        return `<svg ${s}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`;
      case "users":
        return `<svg ${s}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`;
      case "book":
        return `<svg ${s}><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>`;
      case "zap":
        return `<svg ${s}><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`;
      case "slash":
        return `<svg ${s}><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>`;
      case "door":
        return `<svg ${s}><path d="M18 20V6a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v14"/><path d="M2 20h20"/><circle cx="14" cy="12" r="1"/></svg>`;
      case "code":
        return `<svg ${s}><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>`;
      case "barChart":
        return `<svg ${s}><line x1="12" y1="20" x2="12" y2="10"/><line x1="18" y1="20" x2="18" y2="4"/><line x1="6" y1="20" x2="6" y2="16"/></svg>`;
      case "refresh":
        return `<svg ${s}><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>`;
      case "calculator":
        return `<svg ${s}><rect x="4" y="2" width="16" height="20" rx="2"/><line x1="8" y1="6" x2="16" y2="6"/><line x1="16" y1="14" x2="16" y2="18"/><path d="M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M8 18h.01M12 18h.01"/></svg>`;
      case "search":
        return `<svg ${s}><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>`;
      case "x":
        return `<svg ${s}><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`;
      case "menu":
        return `<svg ${s}><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>`;
      case "command":
        return `<svg ${s}><path d="M18 3a3 3 0 0 0-3 3v12a3 3 0 0 0 3 3 3 3 0 0 0 3-3 3 3 0 0 0-3-3H6a3 3 0 0 0-3 3 3 3 0 0 0 3 3 3 3 0 0 0 3-3V6a3 3 0 0 0-3-3 3 3 0 0 0-3 3 3 3 0 0 0 3 3h12a3 3 0 0 0 3-3 3 3 0 0 0-3-3z"/></svg>`;
      default:
        return "";
    }
  }

  function getExamDeviceInfo() {
    const ua = navigator.userAgent || "";
    const isPhone =
      /Android.+Mobile|iPhone|iPod|Windows Phone|BlackBerry|IEMobile|Opera Mini/i.test(ua) ||
      (navigator.maxTouchPoints > 1 && Math.min(window.screen.width || 0, window.screen.height || 0) <= 480);
    const platform = navigator.userAgentData?.platform || navigator.platform || "Unknown";
    return {
      isPhone,
      platform,
      width: window.innerWidth,
      height: window.innerHeight,
      touch: navigator.maxTouchPoints || 0
    };
  }

  function showLaptopOnlyModal() {
    const info = getExamDeviceInfo();
    const oldModal = document.getElementById("ep-device-block-modal");
    if (oldModal) oldModal.remove();
    const modal = document.createElement("div");
    modal.id = "ep-device-block-modal";
    modal.className = "ep-modal-backdrop";
    modal.style.display = "flex";
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:480px;text-align:center;">
        <div class="ep-shield-badge" style="background:#fee2e2;">
          ${I("slash", 36, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#0f172a;">Laptop Required</h2>
        <p class="ep-onboarding-text">
          This platform is designed for laptop only. Please use a laptop to join the exam.
        </p>
        <div style="width:100%;background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:12px;text-align:left;font-size:12px;color:#475569;margin-bottom:20px;">
          <div><b>Detected device:</b> ${info.platform}</div>
          <div><b>Screen:</b> ${info.width} × ${info.height}</div>
          <div><b>Touch points:</b> ${info.touch}</div>
        </div>
        <button id="ep-device-block-close" class="ep-modal-btn" style="background:#0f172a;">
          I Understand
        </button>
      </div>
    `;
    document.body.appendChild(modal);
    document.getElementById("ep-device-block-close").onclick = () => modal.remove();
  }

  const defaultState = {
    activeView: "login", // 'login' | 'exam_platform'
    studentActiveTab: "scheduled_exams", // 'courses' | 'scheduled_exams' | 'results'
    activeOnboardingModal: null, // null | 1 | 2 | 3 | 4
    currentUser: {
      id: "manager",
      name: "Exam Manager",
      email: "manager@iitm.ac.in",
      role: "manager"
    },
    exam: {
      id: "iitm-python-endterm",
      title: "GenZ IITian — Python & Computational Thinking Endterm",
      subject: "Python Programming & Data Structures",
      type: "final", // 'final' | 'general'
      status: "live", // 'live' | 'paused' | 'ended'
      resultsPublished: false,
      durationMinutes: 60,
      extendedMinutes: 0,
      startedAt: Date.now() - 15 * 60 * 1000,
      instructions: "No outside aids permitted. Exiting the exam window requires manager approval to re-enter.",
      chatEnabled: true,
      allowedEmails: [
        "student@iitm.ac.in",
        "tushar@iitm.ac.in",
        ...Array.from({ length: 50 }, (_, i) => `student${i + 1}@iitm.ac.in`)
      ],
      sections: [
        { id: "sec-coc", title: "Code of Conduct (COC)", isCoc: true },
        { id: "sec-a", title: "Section A: Core Concepts", marksEach: 2, negativeEach: 0.5 },
        { id: "sec-b", title: "Section B: Algorithmic Logic & Output", marksEach: 3, negativeEach: 1.0 }
      ],
      questions: [
        {
          id: "q1",
          sectionId: "sec-a",
          type: "mcq_single",
          marks: 2,
          negative: 0.5,
          prompt: "What is the output of the following Python slice operation on a list?",
          code: "x = [1, 2, 3, 4, 5]\nprint(x[::-1])",
          options: ["[1, 2, 3, 4, 5]", "[5, 4, 3, 2, 1]", "(5, 4, 3, 2, 1)", "SyntaxError"],
          correct: 1,
          explanation: "Slice x[::-1] steps backward through list x from end to start, reversing it to [5, 4, 3, 2, 1]."
        },
        {
          id: "q2",
          sectionId: "sec-a",
          type: "mcq_multi",
          marks: 2,
          negative: 0.5,
          prompt: "Which of the following statements correctly create a Python dictionary? (Select all that apply)",
          code: null,
          options: [
            "d = {'roll': 101, 'name': 'Aditi'}",
            "d = dict(roll=101, name='Aditi')",
            "d = { ('id', 1): 'admin' }",
            "d = { ['id']: 'admin' }"
          ],
          correct: [0, 1, 2],
          explanation: "Tuples are immutable and hashable, so ('id', 1) is a valid dict key. Lists are mutable and cannot be dict keys."
        },
        {
          id: "q3",
          sectionId: "sec-a",
          type: "true_false",
          marks: 2,
          negative: 0.5,
          prompt: "In Python, a standard dictionary preserves insertion order of keys starting from Python 3.7+.",
          code: null,
          options: ["True", "False"],
          correct: 0,
          explanation: "Starting in Python 3.7, dict insertion order is an official part of the Python language specification."
        },
        {
          id: "q4",
          sectionId: "sec-a",
          type: "numerical",
          marks: 2,
          negative: 0,
          prompt: "What is the returned integer value of the following set length expression?",
          code: "len(set([10, 20, 20, 30, 10, 40, 50]))",
          correct: 5,
          explanation: "Unique values in [10, 20, 20, 30, 10, 40, 50] are {10, 20, 30, 40, 50}, which has 5 elements."
        },
        {
          id: "q5",
          sectionId: "sec-b",
          type: "mcq_single",
          marks: 3,
          negative: 1.0,
          prompt: "What is the worst-case time complexity of searching in a balanced Binary Search Tree (AVL tree) of N nodes?",
          code: null,
          options: ["O(1)", "O(log N)", "O(N)", "O(N log N)"],
          correct: 1,
          explanation: "Balanced BSTs (AVL / Red-Black) maintain height of O(log N), so search is guaranteed O(log N) in worst case."
        },
        {
          id: "q6",
          sectionId: "sec-b",
          type: "short_answer",
          marks: 3,
          negative: 0,
          prompt: "What keyword is used in Python inside an inner function to modify a variable defined in the enclosing (non-global) scope?",
          code: null,
          correct: "nonlocal",
          explanation: "The 'nonlocal' keyword binds an inner function variable to its closest enclosing non-global scope."
        },
        {
          id: "q7",
          sectionId: "sec-b",
          type: "mcq_single",
          marks: 3,
          negative: 1.0,
          prompt: "What will be printed when running this generator function?",
          code: "def gen():\n    yield 1\n    yield 2\n\ng = gen()\nnext(g)\nprint(next(g))",
          options: ["1", "2", "StopIteration", "None"],
          correct: 1,
          explanation: "First next(g) yields 1. Second next(g) yields 2 and print() outputs 2."
        },
        {
          id: "q8",
          sectionId: "sec-b",
          type: "numerical",
          marks: 3,
          negative: 0,
          prompt: "Calculate the exact output value of the arithmetic precedence expression:",
          code: "res = 2 ** 3 * 2 + 10 // 3\nprint(res)",
          correct: 19,
          explanation: "2**3 = 8; 8*2 = 16; 10//3 = 3; 16 + 3 = 19."
        }
      ]
    },
    reentryRequests: [],
    studentSessions: {
      "student@iitm.ac.in": {
        email: "student@iitm.ac.in",
        name: "Student Demo",
        studentId: "22F3001840",
        status: "not_started",
        onboardingStep: 0,
        attendanceRecordedAt: null,
        attendanceTimestamp: null,
        photoDataUrl: null,
        warnings: 0,
        warningLogs: [],
        outsideExamSeconds: 0,
        outsideSince: null,
        outsideReason: null,
        cocAgreedAt: null,
        cocAgreedAtFormatted: null,
        currentQuestionIndex: 0,
        currentSectionId: "sec-a",
        answers: {},
        reviewFlags: [],
        startedAt: null,
        lastActive: Date.now()
      }
    },
    chatMessages: [
      {
        id: "msg-1",
        senderName: "Exam Manager",
        role: "manager",
        text: "Welcome students. Ensure your internet connection is stable. Leaving the window triggers re-entry lock.",
        timestamp: Date.now() - 14 * 60 * 1000,
        isAnnouncement: true
      }
    ]
  };

  function getState() {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (data) {
        const parsed = JSON.parse(data);
        if (!parsed.studentActiveTab) parsed.studentActiveTab = "scheduled_exams";
        if (!parsed.exam.type) parsed.exam.type = "final";
        if (parsed.exam.resultsPublished === undefined) parsed.exam.resultsPublished = false;
        parsed.chatMessages = (parsed.chatMessages || []).map((m, idx) => ({ ...m, id: m.id || `msg-old-${idx}` }));
        if (parsed.exam && parsed.exam.sections && !parsed.exam.sections.some((s) => s.id === "sec-coc")) {
          parsed.exam.sections.unshift({ id: "sec-coc", title: "Code of Conduct (COC)", isCoc: true });
        }
        return parsed;
      }
    } catch (e) {
      console.error(e);
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(defaultState));
    return defaultState;
  }

  function saveState(state) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    window.dispatchEvent(new Event("ep_state_changed"));
  }

  window.addEventListener("storage", (e) => {
    if (e.key === STORAGE_KEY) render();
  });
  window.addEventListener("ep_state_changed", () => render());

  // ==========================================
  // TOP PERSISTENT WORKSPACE BAR
  // ==========================================
  function renderRoleSwitcher(state) {
    let el = document.getElementById("ep-role-switcher");
    if (!el) {
      el = document.createElement("div");
      el.id = "ep-role-switcher";
      document.body.prepend(el);
      document.body.classList.add("with-ep-switcher");
    }

    const isManager = state.currentUser.role === "manager";
    const inPlatform = state.activeView === "exam_platform";

    el.innerHTML = `
      <div class="brand-logo">
        <img src="/assets/genz-logo.png" alt="GenZ IITIAN" style="height:24px;object-fit:contain;margin-right:2px;">
        <span>Exam Portal</span>
        <span class="role-badge ${isManager ? "manager" : "student"}">
          ${isManager ? I("shield", 13, "#38bdf8") : I("cap", 13, "#34d399")}
          ${isManager ? "Manager" : "Student"}: ${state.currentUser.email}
        </span>
        <span style="font-size:11px;color:#9ca3af;font-weight:600;margin-left:4px;">
          Type: <b style="color:${state.exam.type === "final" ? "#fb7185" : "#38bdf8"};">${state.exam.type.toUpperCase()}</b> | Status: <b style="color:${state.exam.status === "ended" ? "#fb7185" : "#34d399"};">${state.exam.status.toUpperCase()}</b>
        </span>
      </div>
      <div class="btn-group">
        ${
          inPlatform
            ? `<button id="ep-btn-switch-role" class="btn-active">
                 ${isManager ? I("cap", 13, "#ffffff") : I("shield", 13, "#ffffff")}
                 Switch to ${isManager ? "Student View" : "Manager View"}
               </button>
               <button id="ep-btn-back-login">
                 Sign In Screen
               </button>`
            : `<button id="ep-btn-enter-platform" class="btn-active">
                 Open Exam Platform (${isManager ? "Manager" : "Student"})
               </button>`
        }
        <button id="ep-btn-open-tab" title="Open in a new tab for simultaneous manager & student testing">
          + New Tab
        </button>
        <button id="ep-btn-reset-demo" style="background:#450a0a;border-color:#7f1d1d;color:#fca5a5;">
          Reset
        </button>
      </div>
    `;

    const btnSwitch = document.getElementById("ep-btn-switch-role");
    if (btnSwitch) {
      btnSwitch.onclick = () => {
        if (isManager) {
          showManagerConfirmModal({
            title: "Switch to Student View",
            subtitle: "Role Switcher",
            description: "You are currently viewing the Proctor Dashboard. Switching to Student View will open the candidate assessment interface. You can return at any time.",
            confirmText: "Switch View",
            confirmType: "info",
            icon: "users",
            onConfirm: () => {
              state.currentUser = { id: "student", name: "Student Demo", email: "student@iitm.ac.in", role: "student" };
              state.activeView = "exam_platform";
              saveState(state);
            }
          });
        } else {
          state.currentUser = { id: "manager", name: "Exam Manager", email: "manager@iitm.ac.in", role: "manager" };
          state.activeView = "exam_platform";
          saveState(state);
        }
      };
    }

    const btnEnter = document.getElementById("ep-btn-enter-platform");
    if (btnEnter) {
      btnEnter.onclick = () => {
        state.activeView = "exam_platform";
        saveState(state);
      };
    }

    const btnBackLogin = document.getElementById("ep-btn-back-login");
    if (btnBackLogin) {
      btnBackLogin.onclick = () => {
        if (isManager) {
          showManagerConfirmModal({
            title: "Return to Sign In Portal",
            subtitle: "Session Navigation",
            description: "Exit the Proctor Dashboard and return to the main login portal?",
            confirmText: "Go to Sign In",
            confirmType: "info",
            icon: "logOut",
            onConfirm: () => {
              state.activeView = "login";
              saveState(state);
            }
          });
        } else {
          state.activeView = "login";
          saveState(state);
        }
      };
    }

    const btnOpenTab = document.getElementById("ep-btn-open-tab");
    if (btnOpenTab) {
      btnOpenTab.onclick = () => {
        window.open(window.location.href, "_blank");
      };
    }

    const btnReset = document.getElementById("ep-btn-reset-demo");
    if (btnReset) {
      btnReset.onclick = () => {
        showManagerConfirmModal({
          title: "Reset Examination Platform",
          subtitle: "Critical System Reset",
          description: "This will wipe all active student sessions, submitted answers, telemetry violation logs, and re-entry requests, reverting the entire portal to initial defaults.",
          confirmText: "Yes, Reset Platform",
          confirmType: "danger",
          icon: "refresh",
          requireCheckbox: true,
          checkboxLabel: "I confirm wiping all candidate sessions and restoring defaults",
          onConfirm: () => {
            localStorage.removeItem(STORAGE_KEY);
            saveState(defaultState);
          }
        });
      };
    }
  }

  // Inject quick login buttons inside React login card
  function injectLoginButtons(state) {
    const googleBtn = document.querySelector('button[type="button"]');
    if (googleBtn && googleBtn.textContent.includes("Continue with Google")) {
      let quickBox = document.getElementById("ep-quick-login-container");
      if (!quickBox) {
        quickBox = document.createElement("div");
        quickBox.id = "ep-quick-login-container";
        quickBox.style.cssText =
          "margin-bottom:16px;padding:12px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;display:flex;flex-direction:column;gap:8px;";
        googleBtn.parentNode.insertBefore(quickBox, googleBtn);
      }

      quickBox.innerHTML = `
        <img src="/assets/genz-logo.png" alt="GenZ IITIAN" style="height:36px;margin:0 auto 10px auto;display:block;object-fit:contain;">
        <div style="font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:0.06em;color:#475569;margin-bottom:2px;text-align:center;">
          Select Test Account
        </div>
        <button type="button" id="ep-quick-mgr" style="background:#0f172a;color:#fff;border:none;padding:10px 14px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;">
          ${I("shield", 15, "#38bdf8")}
          Login as Test Manager (manager@iitm.ac.in)
        </button>
        <button type="button" id="ep-quick-std" style="background:#059669;color:#fff;border:none;padding:10px 14px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;">
          ${I("cap", 15, "#ffffff")}
          Login as Student (student@iitm.ac.in)
        </button>
      `;

      document.getElementById("ep-quick-mgr").onclick = () => {
        state.currentUser = { id: "manager", name: "Exam Manager", email: "manager@iitm.ac.in", role: "manager" };
        state.activeView = "exam_platform";
        saveState(state);
      };

      document.getElementById("ep-quick-std").onclick = () => {
        state.currentUser = { id: "student", name: "Student Demo", email: "student@iitm.ac.in", role: "student" };
        state.activeView = "exam_platform";
        saveState(state);
      };
    }
  }

  const observer = new MutationObserver(() => {
    const state = getState();
    if (state.activeView === "login") {
      injectLoginButtons(state);
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });

  // ==========================================
  // ANTI-CHEAT ENFORCEMENT & WARNING ENGINE
  // ==========================================
  let isAntiCheatInitialized = false;
  let hasUserSwitchedAway = false;
  let isTabWarningModalOpen = false;
  let tabWarningTimerId = null;
  let ignoreBlurUntil = 0;

  function markInternalExamAction() {
    ignoreBlurUntil = Date.now() + 800;
  }

  function formatOutsideTime(seconds) {
    const safeSeconds = Math.max(0, Math.floor(seconds || 0));
    const mins = Math.floor(safeSeconds / 60);
    const secs = safeSeconds % 60;
    return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }

  function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[ch]);
  }

  function showAntiCheatToast(msg) {
    let toast = document.getElementById("ep-cheat-toast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "ep-cheat-toast";
      document.body.appendChild(toast);
    }
    toast.innerHTML = `${I("alert", 18, "#ffffff")} <span>${msg}</span>`;
    toast.style.display = "flex";
    if (window._epToastTimer) clearTimeout(window._epToastTimer);
    window._epToastTimer = setTimeout(() => {
      if (toast) toast.style.display = "none";
    }, 2800);
  }

  function showTabSwitchWarningModal(warningCount, state, session) {
    isTabWarningModalOpen = true;
    const floatingPanels = ["ep-doubts-modal", "ep-calc-widget"]
      .map((id) => document.getElementById(id))
      .filter((el) => el && el.style.display !== "none")
      .map((el) => {
        const display = el.style.display || "";
        el.style.display = "none";
        return { el, display };
      });
    let modal = document.getElementById("ep-tab-warning-modal");
    if (!modal) {
      modal = document.createElement("div");
      modal.id = "ep-tab-warning-modal";
      modal.className = "ep-modal-backdrop";
      document.body.appendChild(modal);
    }

    const liveStart = session.outsideSince || Date.now();
    const baseOutsideSeconds = session.outsideExamSeconds || 0;

    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:440px;text-align:center;box-shadow:0 25px 50px -12px rgba(220,38,38,0.25);border:1.5px solid #fca5a5;">
        <div class="ep-shield-badge" style="background:#fee2e2;">
          ${I("alert", 36, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#b91c1c;margin-bottom:8px;">
          You Changed Your Tab!
        </h2>
        <p class="ep-onboarding-text" style="color:#334155;margin-bottom:18px;font-size:13px;line-height:1.6;">
          Leaving the examination window or switching tabs is strictly monitored. This security infraction has been recorded.
        </p>
        <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;padding:12px 16px;margin-bottom:20px;display:flex;align-items:center;justify-content:center;gap:10px;color:#991b1b;font-weight:800;font-size:15px;">
          ${I("alert", 18, "#dc2626")}
          Warning ${warningCount}
        </div>
        <div style="background:#fff7ed;border:1px solid #fed7aa;border-radius:10px;padding:10px 14px;margin-bottom:20px;color:#9a3412;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;gap:8px;">
          ${I("clock", 15, "#ea580c")}
          Outside time: <span id="ep-tab-away-time">${formatOutsideTime(baseOutsideSeconds)}</span>
        </div>
        <button id="ep-btn-dismiss-warning" class="ep-modal-btn" style="background:#dc2626;color:#ffffff;box-shadow:0 4px 14px rgba(220,38,38,0.3);">
          I Understand & Resume Exam
        </button>
      </div>
    `;

    modal.style.display = "flex";
    if (tabWarningTimerId) clearInterval(tabWarningTimerId);
    tabWarningTimerId = setInterval(() => {
      const timeEl = document.getElementById("ep-tab-away-time");
      if (timeEl) timeEl.textContent = formatOutsideTime(baseOutsideSeconds + (Date.now() - liveStart) / 1000);
    }, 1000);

    const btnDismiss = document.getElementById("ep-btn-dismiss-warning");
    if (btnDismiss) {
      btnDismiss.onclick = () => {
        if (tabWarningTimerId) clearInterval(tabWarningTimerId);
        tabWarningTimerId = null;
        const freshState = getState();
        const freshSession = freshState.studentSessions[freshState.currentUser.email];
        if (freshSession) {
          const outsideSeconds = Math.max(1, Math.round((Date.now() - liveStart) / 1000));
          freshSession.outsideExamSeconds = (freshSession.outsideExamSeconds || 0) + outsideSeconds;
          freshSession.outsideSince = null;
          freshSession.outsideReason = null;
          const latestLog = freshSession.warningLogs?.[freshSession.warningLogs.length - 1];
          if (latestLog && !latestLog.outsideSeconds) {
            latestLog.outsideSeconds = outsideSeconds;
            latestLog.returnedAt = Date.now();
            latestLog.returnedAtFormatted = new Date().toLocaleTimeString();
          }
          saveState(freshState);
        }
        modal.style.display = "none";
        floatingPanels.forEach(({ el, display }) => {
          el.style.display = display;
        });
        isTabWarningModalOpen = false;
        hasUserSwitchedAway = false;
      };
    }
  }

  function handleTabLeave(reason = "window_switch") {
    const state = getState();
    if (state.activeView !== "exam_platform" || state.currentUser.role !== "student") return;
    const session = state.studentSessions[state.currentUser.email];
    if (!session || session.status !== "in_exam") return;
    if (reason === "window_blur" && Date.now() < ignoreBlurUntil) return;
    if (hasUserSwitchedAway || isTabWarningModalOpen) return;
    if (!session.outsideSince) {
      session.outsideSince = Date.now();
      session.outsideReason = reason;
      saveState(state);
    }
    hasUserSwitchedAway = true;
  }

  function handleTabReturn() {
    if (!hasUserSwitchedAway || isTabWarningModalOpen) return;
    hasUserSwitchedAway = false;

    const state = getState();
    if (state.activeView !== "exam_platform" || state.currentUser.role !== "student") return;
    const session = state.studentSessions[state.currentUser.email];
    if (!session || session.status !== "in_exam") return;

    session.warnings = (session.warnings || 0) + 1;
    session.warningLogs = session.warningLogs || [];
    session.warningLogs.push({
      type: session.outsideReason || "window_switch",
      timestamp: Date.now(),
      timeFormatted: new Date().toLocaleTimeString(),
      leftAt: session.outsideSince || Date.now(),
      leftAtFormatted: new Date(session.outsideSince || Date.now()).toLocaleTimeString(),
      returnedAt: null,
      returnedAtFormatted: null,
      outsideSeconds: 0
    });
    saveState(state);

    const warnVal = document.getElementById("ep-warning-val");
    if (warnVal) warnVal.textContent = session.warnings;
    const warnChip = document.getElementById("ep-warning-chip");
    if (warnChip) warnChip.classList.add("warning-active");

    showTabSwitchWarningModal(session.warnings, state, session);
  }

  function initAntiCheatListeners() {
    if (isAntiCheatInitialized) return;
    isAntiCheatInitialized = true;

    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        handleTabLeave("tab_hidden");
      } else {
        handleTabReturn();
      }
    });

    window.addEventListener("blur", () => {
      handleTabLeave("window_blur");
    });

    window.addEventListener("focus", () => {
      handleTabReturn();
    });

    window.addEventListener("pagehide", () => {
      handleTabLeave("page_hidden");
    });

    window.addEventListener("pageshow", () => {
      handleTabReturn();
    });

    function blockClipboard(e) {
      const state = getState();
      if (state.activeView === "exam_platform" && state.currentUser.role === "student") {
        const session = state.studentSessions[state.currentUser.email];
        if (session && session.status === "in_exam") {
          e.preventDefault();
          showAntiCheatToast("Clipboard actions (Copy/Cut/Paste) are blocked during exams.");
        }
      }
    }
    document.addEventListener("copy", blockClipboard);
    document.addEventListener("cut", blockClipboard);
    document.addEventListener("paste", blockClipboard);

    document.addEventListener("dblclick", (e) => {
      const state = getState();
      if (state.activeView === "exam_platform" && state.currentUser.role === "student") {
        const session = state.studentSessions[state.currentUser.email];
        if (session && session.status === "in_exam") {
          e.preventDefault();
          showAntiCheatToast("Double-click text selection is disabled during exams.");
        }
      }
    });

    document.addEventListener("contextmenu", (e) => {
      const state = getState();
      if (state.activeView === "exam_platform" && state.currentUser.role === "student") {
        const session = state.studentSessions[state.currentUser.email];
        if (session && session.status === "in_exam") {
          e.preventDefault();
          showAntiCheatToast("Right-click inspection is disabled during exams.");
        }
      }
    });

    document.addEventListener("keydown", (e) => {
      const state = getState();
      if (state.activeView === "exam_platform" && state.currentUser.role === "student") {
        const session = state.studentSessions[state.currentUser.email];
        if (session && session.status === "in_exam") {
          const isCmdOrCtrl = e.metaKey || e.ctrlKey;
          const k = e.key.toLowerCase();
          if (
            (isCmdOrCtrl && (k === "c" || k === "v" || k === "x" || k === "p" || k === "u" || k === "s")) ||
            e.key === "F12" ||
            (isCmdOrCtrl && e.shiftKey && (k === "i" || k === "j" || k === "c"))
          ) {
            e.preventDefault();
            showAntiCheatToast("Shortcut action disabled by Examination Guard.");
          }
        }
      }
    });
  }

  // ==========================================
  // EXAM ENDED MODALS
  // ==========================================
  function showExamEndedForceModal(state, session) {
    let modal = document.getElementById("ep-exam-ended-force-modal");
    if (!modal) {
      modal = document.createElement("div");
      modal.id = "ep-exam-ended-force-modal";
      modal.className = "ep-modal-backdrop";
      document.body.appendChild(modal);
    }
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:460px;text-align:center;box-shadow:0 25px 50px -12px rgba(15,23,42,0.35);border:1.5px solid #cbd5e1;">
        <div class="ep-shield-badge" style="background:#fee2e2;">
          ${I("lock", 36, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#0f172a;margin-bottom:8px;">
          Examination Ended
        </h2>
        <p class="ep-onboarding-text" style="color:#475569;margin-bottom:20px;font-size:13.5px;line-height:1.6;">
          The examination has been officially ended by the proctor. All active student sessions are now closed and your recorded answers have been submitted.
        </p>
        <button id="ep-btn-force-quit-exam" class="ep-modal-btn" style="background:#dc2626;color:#ffffff;box-shadow:0 4px 14px rgba(220,38,38,0.3);font-size:14px;font-weight:700;display:inline-flex;align-items:center;justify-content:center;gap:8px;">
          ${I("logOut", 15, "#ffffff")} Force Quit Examination
        </button>
      </div>
    `;
    modal.style.display = "flex";
    const btnForce = document.getElementById("ep-btn-force-quit-exam");
    if (btnForce) {
      btnForce.onclick = () => {
        modal.remove();
        session.status = "submitted";
        session.submittedAt = Date.now();
        saveState(state);
        render();
      };
    }
  }

  function showExamEndedRejoinModal() {
    let modal = document.getElementById("ep-exam-ended-rejoin-modal");
    if (!modal) {
      modal = document.createElement("div");
      modal.id = "ep-exam-ended-rejoin-modal";
      modal.className = "ep-modal-backdrop";
      document.body.appendChild(modal);
    }
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:440px;text-align:center;box-shadow:0 25px 50px -12px rgba(15,23,42,0.35);border:1.5px solid #cbd5e1;">
        <div class="ep-shield-badge" style="background:#fee2e2;">
          ${I("slash", 36, "#dc2626")}
        </div>
        <h2 class="ep-onboarding-title" style="color:#0f172a;margin-bottom:8px;">
          Examination Has Ended
        </h2>
        <p class="ep-onboarding-text" style="color:#475569;margin-bottom:20px;font-size:13.5px;line-height:1.6;">
          This examination was officially concluded and closed. You cannot join or re-join an exam session that has ended.
        </p>
        <button id="ep-btn-close-ended-rejoin" class="ep-modal-btn" style="background:#0f172a;color:#ffffff;font-size:13.5px;font-weight:700;">
          Return to Dashboard
        </button>
      </div>
    `;
    modal.style.display = "flex";
    const btnClose = document.getElementById("ep-btn-close-ended-rejoin");
    if (btnClose) {
      btnClose.onclick = () => {
        modal.style.display = "none";
      };
    }
  }

  // ==========================================
  // MANAGER DOUBLE CONFIRMATION MODAL (ACCIDENTAL TOUCH GUARD)
  // ==========================================
  function showManagerConfirmModal({
    title,
    subtitle = "Manager Action Confirmation",
    description,
    confirmText = "Confirm Action",
    confirmType = "primary", // "danger", "success", "warning", "purple", "teal", "info"
    icon = "alert",
    requireCheckbox = false,
    checkboxLabel = "I confirm and understand this action",
    onConfirm
  }) {
    const oldModal = document.getElementById("ep-manager-confirm-modal");
    if (oldModal) oldModal.remove();

    const colorMap = {
      danger: { badgeBg: "#450a0a", badgeBorder: "#7f1d1d", iconColor: "#f87171", btnBg: "#dc2626", btnColor: "#ffffff" },
      warning: { badgeBg: "#451a03", badgeBorder: "#78350f", iconColor: "#fbbf24", btnBg: "#d97706", btnColor: "#ffffff" },
      success: { badgeBg: "#052e16", badgeBorder: "#14532d", iconColor: "#34d399", btnBg: "#059669", btnColor: "#ffffff" },
      purple: { badgeBg: "#2e1065", badgeBorder: "#581c87", iconColor: "#c084fc", btnBg: "#7c3aed", btnColor: "#ffffff" },
      teal: { badgeBg: "#042f2e", badgeBorder: "#115e59", iconColor: "#2dd4bf", btnBg: "#0d9488", btnColor: "#ffffff" },
      info: { badgeBg: "#082f49", badgeBorder: "#075985", iconColor: "#38bdf8", btnBg: "#0284c7", btnColor: "#ffffff" }
    };
    const theme = colorMap[confirmType] || colorMap.info;

    const modal = document.createElement("div");
    modal.id = "ep-manager-confirm-modal";
    modal.className = "ep-modal-backdrop";
    modal.style.cssText = "display:flex;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.88);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);z-index:999999;align-items:center;justify-content:center;padding:20px;";

    modal.innerHTML = `
      <div class="ep-mgr-confirm-card" style="max-width:500px;width:100%;text-align:left;background:#0a0a0a;border:1.5px solid #222222;border-radius:18px;box-shadow:0 25px 60px -15px rgba(0,0,0,0.95);padding:26px 24px;color:#f9fafb;position:relative;animation:ep-card-pop 0.2s cubic-bezier(0.16, 1, 0.3, 1);">
        <!-- Top bar with Logo & Accidental Touch Guard indicator -->
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;border-bottom:1px solid #1a1a1a;padding-bottom:12px;">
          <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:11px;font-weight:800;color:#94a3b8;letter-spacing:0.06em;text-transform:uppercase;">Accidental Touch Guard</span>
          </div>
          <button id="ep-mgr-modal-close" style="background:transparent;border:none;color:#64748b;cursor:pointer;display:inline-flex;align-items:center;padding:4px;border-radius:6px;" title="Dismiss (Esc)">
            ${I("x", 16, "#94a3b8")}
          </button>
        </div>

        <!-- Action Icon + Titles -->
        <div style="display:flex;align-items:flex-start;gap:14px;margin-bottom:16px;">
          <div style="width:46px;height:46px;border-radius:12px;background:${theme.badgeBg};border:1.5px solid ${theme.badgeBorder};display:flex;align-items:center;justify-content:center;flex-shrink:0;">
            ${I(icon, 22, theme.iconColor)}
          </div>
          <div>
            <div style="font-size:11px;font-weight:800;color:${theme.iconColor};text-transform:uppercase;letter-spacing:0.06em;margin-bottom:3px;">
              ${subtitle}
            </div>
            <div style="font-size:16px;font-weight:800;color:#f8fafc;line-height:1.35;">
              ${title}
            </div>
          </div>
        </div>

        <!-- Action details description box -->
        <div style="background:#111111;border:1px solid #1e1e1e;border-radius:10px;padding:14px 16px;margin-bottom:16px;font-size:13px;color:#cbd5e1;line-height:1.55;">
          ${description}
        </div>

        <!-- Double confirmation badge note -->
        <div style="display:flex;align-items:center;gap:8px;font-size:11.5px;color:#94a3b8;margin-bottom:${requireCheckbox ? "14px" : "20px"};padding:8px 12px;background:rgba(255,255,255,0.03);border-radius:8px;border:1px dashed #2a2a2a;">
          ${I("shield", 14, "#38bdf8")}
          <span><b>Double Confirmation:</b> Second confirmation click is required to execute this manager command.</span>
        </div>

        ${
          requireCheckbox
            ? `
          <label style="display:flex;align-items:center;gap:10px;font-size:12.5px;color:#fca5a5;background:rgba(239,68,68,0.08);border:1px solid rgba(239,68,68,0.25);border-radius:8px;padding:10px 12px;margin-bottom:20px;cursor:pointer;">
            <input type="checkbox" id="ep-mgr-modal-check" style="width:16px;height:16px;cursor:pointer;accent-color:#ef4444;" />
            <span style="font-weight:600;">${checkboxLabel}</span>
          </label>
        `
            : ""
        }

        <!-- Dual Action Buttons -->
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:10px;">
          <button id="ep-mgr-modal-cancel" style="background:#141414;border:1px solid #262626;color:#e2e8f0;padding:10px 18px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">
            ${I("x", 13, "#94a3b8")} Cancel
          </button>
          <button id="ep-mgr-modal-confirm" ${requireCheckbox ? "disabled" : ""} style="background:${theme.btnBg};border:none;color:${theme.btnColor};padding:10px 22px;border-radius:8px;font-size:13px;font-weight:700;cursor:${requireCheckbox ? "not-allowed" : "pointer"};display:inline-flex;align-items:center;gap:8px;box-shadow:0 4px 14px rgba(0,0,0,0.35);opacity:${requireCheckbox ? "0.45" : "1"};transition:opacity 0.15s ease;">
            ${I("check", 14, theme.btnColor)} ${confirmText}
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    const cleanup = () => {
      modal.remove();
      document.removeEventListener("keydown", keyHandler);
    };

    const keyHandler = (e) => {
      if (e.key === "Escape") cleanup();
    };
    document.addEventListener("keydown", keyHandler);

    modal.addEventListener("click", (e) => {
      if (e.target === modal) cleanup();
    });

    document.getElementById("ep-mgr-modal-close").onclick = cleanup;
    document.getElementById("ep-mgr-modal-cancel").onclick = cleanup;

    const confirmBtn = document.getElementById("ep-mgr-modal-confirm");
    const checkEl = document.getElementById("ep-mgr-modal-check");

    if (checkEl) {
      checkEl.onchange = () => {
        if (checkEl.checked) {
          confirmBtn.disabled = false;
          confirmBtn.style.cursor = "pointer";
          confirmBtn.style.opacity = "1";
        } else {
          confirmBtn.disabled = true;
          confirmBtn.style.cursor = "not-allowed";
          confirmBtn.style.opacity = "0.45";
        }
      };
    }

    // Accidental double-touch debounce (200ms lock)
    let canConfirm = false;
    setTimeout(() => {
      canConfirm = true;
    }, 200);

    confirmBtn.onclick = () => {
      if (!canConfirm || confirmBtn.disabled) return;
      cleanup();
      if (typeof onConfirm === "function") {
        onConfirm();
      }
    };
  }

  function showStudentSubmitConfirmModal({ answeredCount, totalCount, onConfirm }) {
    const oldModal = document.getElementById("ep-student-submit-modal");
    if (oldModal) oldModal.remove();

    const modal = document.createElement("div");
    modal.id = "ep-student-submit-modal";
    modal.className = "ep-modal-backdrop";
    modal.style.cssText = "display:flex;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(15,23,42,0.8);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);z-index:999999;align-items:center;justify-content:center;padding:20px;";

    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:460px;width:100%;text-align:center;background:#ffffff;border-radius:20px;box-shadow:0 25px 60px -15px rgba(0,0,0,0.3);padding:30px 24px;color:#0f172a;animation:ep-card-pop 0.2s cubic-bezier(0.16, 1, 0.3, 1);">
        <div class="ep-shield-badge" style="background:#dcfce7;margin:0 auto 16px auto;">
          ${I("checkCircle", 36, "#059669")}
        </div>
        <h2 style="font-size:20px;font-weight:800;color:#0f172a;margin:0 0 8px 0;">
          Exit Examination
        </h2>
        <p style="font-size:13.5px;color:#475569;margin:0 0 18px 0;line-height:1.55;">
          You have recorded answers for <b>${answeredCount} of ${totalCount}</b> questions. Once submitted, your answers will be sealed and your exam session will end.
        </p>
        <div style="display:flex;gap:10px;">
          <button id="ep-btn-cancel-submit" style="flex:1;background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;padding:11px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">
            Return to Exam
          </button>
          <button id="ep-btn-confirm-submit" style="flex:1.2;background:#059669;color:#ffffff;border:none;padding:11px;border-radius:8px;font-size:13px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;box-shadow:0 4px 14px rgba(5,150,105,0.3);">
            ${I("check", 14, "#ffffff")} Submit
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    const cleanup = () => modal.remove();
    document.getElementById("ep-btn-cancel-submit").onclick = cleanup;
    document.getElementById("ep-btn-confirm-submit").onclick = () => {
      cleanup();
      if (typeof onConfirm === "function") onConfirm();
    };
  }

  // ==========================================
  // EMBEDDED CALCULATOR ENGINE (BASIC & PRO)
  // ==========================================
  let calcMode = "basic"; // 'basic' | 'pro'
  let calcExpression = "";
  let calcCurrentVal = "0";
  let calcHistory = "";
  let isCalcOpen = false;

  function toggleCalculator(initialMode = null) {
    markInternalExamAction();
    if (initialMode) calcMode = initialMode;
    let panel = document.getElementById("ep-calc-widget");
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "ep-calc-widget";
      document.body.appendChild(panel);
    }

    if (isCalcOpen && (!initialMode || panel.dataset.mode === initialMode)) {
      panel.style.display = "none";
      isCalcOpen = false;
      return;
    }

    isCalcOpen = true;
    panel.style.display = "flex";
    panel.dataset.mode = calcMode;
    renderCalculatorDOM(panel);
  }

  function showDoubtsModal(state) {
    markInternalExamAction();
    const oldModal = document.getElementById("ep-doubts-modal");
    if (oldModal) oldModal.remove();
    const modal = document.createElement("div");
    modal.id = "ep-doubts-modal";
    modal.style.cssText = "position:fixed;left:16px;bottom:94px;width:360px;height:430px;background:#ffffff;border:1px solid #cbd5e1;border-radius:14px;box-shadow:0 18px 45px rgba(15,23,42,0.22);z-index:999999;display:flex;flex-direction:column;overflow:hidden;";
    modal.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 14px;border-bottom:1px solid #e2e8f0;background:#f8fafc;">
          <div style="display:flex;align-items:center;gap:10px;">
            ${I("message", 18, "#059669")}
            <h2 style="font-size:15px;font-weight:800;color:#0f172a;margin:0;">Doubts</h2>
          </div>
          <button id="ep-doubts-close" style="background:#ffffff;border:1px solid #cbd5e1;color:#334155;border-radius:8px;padding:6px 8px;cursor:pointer;font-weight:800;">
            ${I("x", 14, "#334155")}
          </button>
        </div>
        <div id="ep-doubts-stream" style="flex:1;min-height:0;overflow-y:auto;background:#ffffff;padding:12px;display:flex;flex-direction:column;gap:10px;">
          ${
            state.chatMessages.length
              ? state.chatMessages
                  .map(
                    (m) => {
                      const role = m.role || (m.from === "Student" ? "student" : "manager");
                      const isMe = role === "student";
                      const sender = escapeHTML(m.senderName || m.from || (isMe ? "Student" : "Manager"));
                      const time = m.timestamp ? new Date(m.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : escapeHTML(m.time || "");
                      const text = escapeHTML(m.text || m.message || "");
                      return `
                    <div style="align-self:${isMe ? "flex-end" : "flex-start"};max-width:82%;background:${isMe ? "#ecfdf5" : "#ffffff"};border:1px solid ${isMe ? "#86efac" : "#e2e8f0"};border-radius:10px;padding:10px;">
                      <div style="font-size:11px;font-weight:800;color:${isMe ? "#059669" : "#2563eb"};margin-bottom:4px;">${sender}${time ? ` · ${time}` : ""}</div>
                      <div style="font-size:13px;color:#334155;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere;">${text}</div>
                    </div>
                  `;
                    }
                  )
                  .join("")
              : `<div style="font-size:13px;color:#64748b;text-align:center;padding:20px;">No messages yet.</div>`
          }
        </div>
        <div style="padding:10px 12px;border-top:1px solid #e2e8f0;background:#f8fafc;">
          <div style="display:flex;gap:8px;">
            <input id="ep-doubts-input" type="text" maxlength="240" placeholder="Type your doubt..." style="flex:1;min-width:0;border:1px solid #cbd5e1;border-radius:8px;padding:9px 10px;font-size:13px;outline:none;color:#0f172a;" />
            <button id="ep-doubts-send" style="background:#059669;color:#fff;border:none;border-radius:8px;padding:9px 12px;font-size:12px;font-weight:800;cursor:pointer;">Send</button>
          </div>
          <div id="ep-doubts-error" style="min-height:14px;margin-top:5px;font-size:11px;color:#dc2626;font-weight:700;"></div>
        </div>
    `;
    document.body.appendChild(modal);
    const close = () => modal.remove();
    document.getElementById("ep-doubts-close").onclick = close;
    const input = document.getElementById("ep-doubts-input");
    const send = document.getElementById("ep-doubts-send");
    const error = document.getElementById("ep-doubts-error");
    const stream = document.getElementById("ep-doubts-stream");
    if (stream) stream.scrollTop = stream.scrollHeight;
    const sendDoubt = () => {
      const text = input.value.trim().slice(0, 240);
      const now = Date.now();
      if (!text) return;
      if (now - (state.lastDoubtSentAt || 0) < 5000) {
        error.textContent = "Please wait a few seconds before sending again.";
        return;
      }
      state.lastDoubtSentAt = now;
      state.chatMessages.push({
        id: "msg-" + now,
        senderName: "Student",
        role: "student",
        text,
        timestamp: now,
        isAnnouncement: false
      });
      saveState(state);
      showDoubtsModal(state);
    };
    send.onclick = sendDoubt;
    input.onkeydown = (e) => {
      if (e.key === "Enter") sendDoubt();
    };
  }

  function renderCalculatorDOM(panel) {
    panel.className = `ep-calc-panel ${calcMode === "pro" ? "pro-mode" : ""}`;
    panel.innerHTML = `
      <div class="ep-calc-header">
        <div style="display:flex;align-items:center;gap:6px;color:#0f172a;font-weight:700;font-size:12px;">
          ${I("calculator", 14, "#10b981")}
          <span>${calcMode === "pro" ? "Scientific (Pro)" : "Basic"} Calculator</span>
        </div>
        <div style="display:flex;align-items:center;gap:8px;">
          <div class="ep-calc-tabs">
            <button class="ep-calc-tab-btn ${calcMode === "basic" ? "active" : ""}" id="ep-calc-tab-basic">Basic</button>
            <button class="ep-calc-tab-btn ${calcMode === "pro" ? "active" : ""}" id="ep-calc-tab-pro">Pro</button>
          </div>
          <button id="ep-calc-btn-close" style="background:transparent;border:none;color:#64748b;cursor:pointer;padding:4px;display:flex;">
            ${I("x", 14, "#64748b")}
          </button>
        </div>
      </div>

      <div class="ep-calc-screen">
        <div class="ep-calc-history" id="ep-calc-hist-text">${calcHistory}</div>
        <div class="ep-calc-display" id="ep-calc-disp-text">${calcCurrentVal}</div>
      </div>

      <div class="ep-calc-body">
        ${
          calcMode === "basic"
            ? `
          <div class="ep-calc-grid-basic">
            <button class="ep-calc-key action-clear" data-k="C">C</button>
            <button class="ep-calc-key action-clear" data-k="DEL">DEL</button>
            <button class="ep-calc-key op" data-k="±">±</button>
            <button class="ep-calc-key op" data-k="/">÷</button>

            <button class="ep-calc-key" data-k="7">7</button>
            <button class="ep-calc-key" data-k="8">8</button>
            <button class="ep-calc-key" data-k="9">9</button>
            <button class="ep-calc-key op" data-k="*">×</button>

            <button class="ep-calc-key" data-k="4">4</button>
            <button class="ep-calc-key" data-k="5">5</button>
            <button class="ep-calc-key" data-k="6">6</button>
            <button class="ep-calc-key op" data-k="-">−</button>

            <button class="ep-calc-key" data-k="1">1</button>
            <button class="ep-calc-key" data-k="2">2</button>
            <button class="ep-calc-key" data-k="3">3</button>
            <button class="ep-calc-key op" data-k="+">+</button>

            <button class="ep-calc-key" data-k="0" style="grid-column: span 2;">0</button>
            <button class="ep-calc-key" data-k=".">.</button>
            <button class="ep-calc-key action-equals" data-k="=">=</button>
          </div>
        `
            : `
          <div class="ep-calc-grid-pro">
            <button class="ep-calc-key fn" data-k="sin">sin</button>
            <button class="ep-calc-key fn" data-k="cos">cos</button>
            <button class="ep-calc-key fn" data-k="tan">tan</button>
            <button class="ep-calc-key fn" data-k="log">log</button>
            <button class="ep-calc-key fn" data-k="ln">ln</button>

            <button class="ep-calc-key fn" data-k="sqrt">√</button>
            <button class="ep-calc-key fn" data-k="sqr">x²</button>
            <button class="ep-calc-key fn" data-k="pow">^</button>
            <button class="ep-calc-key fn" data-k="pi">π</button>
            <button class="ep-calc-key fn" data-k="e">e</button>

            <button class="ep-calc-key fn" data-k="(">(</button>
            <button class="ep-calc-key fn" data-k=")">)</button>
            <button class="ep-calc-key fn" data-k="inv">1/x</button>
            <button class="ep-calc-key fn" data-k="abs">abs</button>
            <button class="ep-calc-key fn" data-k="%">%</button>

            <button class="ep-calc-key action-clear" data-k="C">C</button>
            <button class="ep-calc-key action-clear" data-k="DEL">DEL</button>
            <button class="ep-calc-key op" data-k="±">±</button>
            <button class="ep-calc-key op" data-k="/">÷</button>
            <button class="ep-calc-key op" data-k="*">×</button>

            <button class="ep-calc-key" data-k="7">7</button>
            <button class="ep-calc-key" data-k="8">8</button>
            <button class="ep-calc-key" data-k="9">9</button>
            <button class="ep-calc-key op" data-k="-">−</button>
            <button class="ep-calc-key op" data-k="+">+</button>

            <button class="ep-calc-key" data-k="4">4</button>
            <button class="ep-calc-key" data-k="5">5</button>
            <button class="ep-calc-key" data-k="6">6</button>
            <button class="ep-calc-key" data-k="0">0</button>
            <button class="ep-calc-key" data-k=".">.</button>

            <button class="ep-calc-key" data-k="1">1</button>
            <button class="ep-calc-key" data-k="2">2</button>
            <button class="ep-calc-key" data-k="3">3</button>
            <button class="ep-calc-key action-equals" data-k="=" style="grid-column: span 2;">=</button>
          </div>
        `
        }
      </div>
    `;

    const btnClose = document.getElementById("ep-calc-btn-close");
    if (btnClose) {
      btnClose.onclick = () => {
        panel.style.display = "none";
        isCalcOpen = false;
      };
    }

    const tabBasic = document.getElementById("ep-calc-tab-basic");
    if (tabBasic) {
      tabBasic.onclick = () => {
        calcMode = "basic";
        renderCalculatorDOM(panel);
      };
    }

    const tabPro = document.getElementById("ep-calc-tab-pro");
    if (tabPro) {
      tabPro.onclick = () => {
        calcMode = "pro";
        renderCalculatorDOM(panel);
      };
    }

    panel.querySelectorAll(".ep-calc-key").forEach((btn) => {
      btn.onclick = () => handleCalcKey(btn.dataset.k, panel);
    });
  }

  function handleCalcKey(key, panel) {
    if (key === "C") {
      calcCurrentVal = "0";
      calcExpression = "";
      calcHistory = "";
    } else if (key === "DEL") {
      calcCurrentVal = calcCurrentVal.length > 1 ? calcCurrentVal.slice(0, -1) : "0";
    } else if (key === "±") {
      if (calcCurrentVal !== "0") {
        calcCurrentVal = calcCurrentVal.startsWith("-") ? calcCurrentVal.slice(1) : "-" + calcCurrentVal;
      }
    } else if (key === "pi") {
      calcCurrentVal = String(Math.PI.toFixed(6));
    } else if (key === "e") {
      calcCurrentVal = String(Math.E.toFixed(6));
    } else if (["sin", "cos", "tan", "log", "ln", "sqrt", "sqr", "inv", "abs"].includes(key)) {
      const v = parseFloat(calcCurrentVal) || 0;
      let res = 0;
      if (key === "sin") res = Math.sin((v * Math.PI) / 180);
      else if (key === "cos") res = Math.cos((v * Math.PI) / 180);
      else if (key === "tan") res = Math.tan((v * Math.PI) / 180);
      else if (key === "log") res = Math.log10(v);
      else if (key === "ln") res = Math.log(v);
      else if (key === "sqrt") res = Math.sqrt(v);
      else if (key === "sqr") res = v * v;
      else if (key === "inv") res = v !== 0 ? 1 / v : 0;
      else if (key === "abs") res = Math.abs(v);
      calcHistory = `${key}(${v}) =`;
      calcCurrentVal = String(Number.isInteger(res) ? res : Number(res.toFixed(6)));
    } else if (["+", "-", "*", "/", "%", "pow"].includes(key)) {
      const sym = key === "pow" ? "^" : key;
      calcExpression += calcCurrentVal + " " + sym + " ";
      calcHistory = calcExpression;
      calcCurrentVal = "0";
    } else if (key === "(" || key === ")") {
      calcExpression += " " + key + " ";
      calcHistory = calcExpression;
    } else if (key === "=") {
      const full = calcExpression + calcCurrentVal;
      calcHistory = full + " =";
      try {
        const sanitized = full.replace(/\^/g, "**").replace(/×/g, "*").replace(/÷/g, "/");
        const res = Function(`"use strict"; return (${sanitized});`)();
        calcCurrentVal = String(Number.isInteger(res) ? res : Number(res.toFixed(6)));
      } catch (e) {
        calcCurrentVal = "Error";
      }
      calcExpression = "";
    } else {
      if (key === "." && calcCurrentVal.includes(".")) return;
      if (calcCurrentVal === "0" && key !== ".") {
        calcCurrentVal = key;
      } else {
        calcCurrentVal += key;
      }
    }

    const d = document.getElementById("ep-calc-disp-text");
    if (d) d.textContent = calcCurrentVal;
    const h = document.getElementById("ep-calc-hist-text");
    if (h) h.textContent = calcHistory;
  }

  // ==========================================
  // MAIN RENDER DISPATCHER
  // ==========================================
  function render() {
    initAntiCheatListeners();
    const state = getState();
    renderRoleSwitcher(state);

    let container = document.getElementById("ep-main-app");
    if (!container) {
      container = document.createElement("div");
      container.id = "ep-main-app";
      document.body.appendChild(container);
    }

    const originalRoot = document.getElementById("root");

    if (state.activeView === "login") {
      if (originalRoot) originalRoot.style.display = "block";
      container.style.display = "none";
      injectLoginButtons(state);
    } else {
      if (originalRoot) originalRoot.style.display = "none";
      container.style.display = "block";

      if (state.currentUser.role === "manager") {
        renderManagerPortal(container, state);
      } else {
        renderStudentInterface(container, state);
      }
    }
  }

  // ==========================================
  // 1. EXAM MANAGER PORTAL (Obsidian Proctor)
  // ==========================================
  let currentMgrTab = "monitor";

  function renderManagerPortal(container, state) {
    const exam = state.exam;
    const enrolledCount = exam.allowedEmails.length;
    const sessionList = Object.values(state.studentSessions);
    const activeCount = sessionList.filter((s) => s.status === "in_exam").length;
    const leaveLogCount = sessionList.reduce((sum, s) => sum + (s.warningLogs || []).length, 0);
    const pendingReentry = state.reentryRequests.filter((r) => r.status === "pending");

    const totalQ = exam.questions.length;
    const totalAnswered = sessionList.reduce((acc, s) => acc + Object.keys(s.answers || {}).length, 0);
    const avgProgress = sessionList.length ? Math.round((totalAnswered / (sessionList.length * totalQ)) * 100) : 0;

    container.innerHTML = `
      <div id="ep-root" style="background:#000000;min-height:calc(100vh - 48px);color:#f9fafb;">
        <div class="saas-container">
          <!-- Top Executive Control Bar -->
          <div class="saas-header">
            <div>
              <div class="saas-breadcrumb">
                <span>Assessments</span>
                <span style="color:#4b5563;">/</span>
                <span>GenZ IITian</span>
                <span style="color:#4b5563;">/</span>
                <span class="active">Python Endterm 2026</span>
              </div>
              <div class="saas-title">
                ${exam.title}
                <span class="saas-status-pill ${exam.status}">
                  <span class="saas-pulse-dot"></span>
                  ${exam.status}
                </span>
                <span style="font-size:12px;padding:3px 8px;border-radius:6px;background:${exam.type === "final" ? "rgba(244,63,94,0.15)" : "rgba(56,189,248,0.15)"};color:${exam.type === "final" ? "#fb7185" : "#38bdf8"};border:1px solid ${exam.type === "final" ? "rgba(244,63,94,0.3)" : "rgba(56,189,248,0.3)"};">
                  ${exam.type === "final" ? "FINAL TEST" : "GENERAL TEST"}
                </span>
              </div>
            </div>

            <!-- Action Toolbar -->
            <div class="saas-control-group">
              <button id="ep-mgr-toggle-type" class="saas-btn" style="background:#141414;border-color:#262626;color:#f9fafb;" title="Switch between Final and General exam">
                ${I("settings", 13, "#9ca3af")}
                Type: <b>${exam.type.toUpperCase()}</b>
              </button>

              ${
                exam.type === "final"
                  ? `<button id="ep-mgr-publish-results" class="saas-btn ${exam.resultsPublished ? "saas-btn-primary" : "saas-btn-purple"}">
                       ${I("broadcast", 13, "currentColor")}
                       ${exam.resultsPublished ? "Results Published" : "Publish Results"}
                     </button>`
                  : ""
              }

              <button id="ep-mgr-export-csv" class="saas-btn" style="background:#042f2e;color:#2dd4bf;border-color:#0d9488;" title="Export marks & records as CSV">
                ${I("download", 13, "#2dd4bf")}
                Export Marks (CSV)
              </button>

              ${
                exam.status === "live"
                  ? `<button id="ep-mgr-pause" class="saas-btn saas-btn-warning">
                       ${I("pause", 13, "#fbbf24")} Pause
                     </button>`
                  : exam.status === "paused"
                  ? `<button id="ep-mgr-resume" class="saas-btn saas-btn-primary">
                       ${I("play", 13, "#34d399")} Resume
                     </button>`
                  : `<button id="ep-mgr-start" class="saas-btn saas-btn-primary">
                       ${I("play", 13, "#34d399")} Start
                     </button>`
              }

              <div class="saas-extend-dock">
                <span class="saas-extend-label">Extend:</span>
                <button id="ep-mgr-ext-5" class="saas-extend-btn">+5m</button>
                <button id="ep-mgr-ext-10" class="saas-extend-btn">+10m</button>
                <button id="ep-mgr-ext-15" class="saas-extend-btn">+15m</button>
              </div>

              <button id="ep-mgr-end" class="saas-btn saas-btn-danger">
                ${I("square", 13, "#fb7185")} End Exam
              </button>
            </div>
          </div>

          <!-- 4 KPI Metric Cards -->
          <div class="saas-kpi-grid">
            <div class="saas-kpi-card">
              <div class="saas-kpi-title">
                <span>Active Test Takers</span>
                <span style="color:#34d399;font-size:11px;">LIVE</span>
              </div>
              <div class="saas-kpi-value-row">
                <span class="saas-kpi-value">${activeCount}</span>
                <span style="color:#6b7280;font-size:14px;font-weight:600;">/ ${enrolledCount} in session</span>
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
                <span class="saas-kpi-value">${enrolledCount}</span>
                <span style="color:#6b7280;font-size:14px;font-weight:600;">students</span>
              </div>
              <div class="saas-kpi-subtext">
                Cohort: <b>GENZ-2026-TERM2</b>
              </div>
            </div>

            <div class="saas-kpi-card">
              <div class="saas-kpi-title">
                <span>Cohort Progress</span>
                <span style="color:#6b7280;font-size:11px;">COMPLETION</span>
              </div>
              <div class="saas-kpi-value-row">
                <span class="saas-kpi-value">${avgProgress}%</span>
                <span style="color:#6b7280;font-size:12px;font-weight:600;">avg pace</span>
              </div>
              <div style="width:100%;height:4px;background:#1f1f1f;border-radius:9999px;overflow:hidden;margin-top:8px;">
                <div style="height:100%;background:#10b981;width:${avgProgress}%;"></div>
              </div>
            </div>

            <div class="saas-kpi-card" style="${pendingReentry.length > 0 ? "border-color:#f59e0b;background:#1c170d;" : ""}">
              <div class="saas-kpi-title">
                <span>Re-entry Approval Queue</span>
                <span style="color:${pendingReentry.length > 0 ? "#f59e0b" : "#6b7280"};font-size:11px;">
                  ${pendingReentry.length > 0 ? "ATTENTION" : "NORMAL"}
                </span>
              </div>
              <div class="saas-kpi-value-row">
                <span class="saas-kpi-value" style="color:${pendingReentry.length > 0 ? "#fbbf24" : "#f9fafb"};">
                  ${pendingReentry.length}
                </span>
                <span style="color:#6b7280;font-size:14px;font-weight:600;">pending review</span>
              </div>
              <div class="saas-kpi-subtext">
                ${pendingReentry.length > 0 ? `<b style="color:#fbbf24;">Candidates waiting</b>` : "No locked candidates"}
              </div>
            </div>
          </div>

          <!-- Tabs Navigation -->
          <div class="saas-tab-bar">
            <button class="saas-tab-btn ${currentMgrTab === "monitor" ? "active" : ""}" data-tab="monitor">
              ${I("barChart", 14)} Live Monitor <span class="saas-tab-badge">${activeCount}</span>
            </button>
            <button class="saas-tab-btn ${currentMgrTab === "leave_log" ? "active" : ""}" data-tab="leave_log">
              ${I("clock", 14)} Leave Log <span class="saas-tab-badge">${leaveLogCount}</span>
            </button>
            <button class="saas-tab-btn ${currentMgrTab === "reentry" ? "active" : ""}" data-tab="reentry">
              ${I("door", 14)} Re-entry Approval Queue
              ${pendingReentry.length > 0 ? `<span class="saas-tab-badge" style="background:#78350f;color:#fbbf24;">${pendingReentry.length}</span>` : ""}
            </button>
            <button class="saas-tab-btn ${currentMgrTab === "builder" ? "active" : ""}" data-tab="builder">
              ${I("fileText", 14)} Exam Builder & Questions <span class="saas-tab-badge">${exam.questions.length}</span>
            </button>
            <button class="saas-tab-btn ${currentMgrTab === "whitelist" ? "active" : ""}" data-tab="whitelist">
              ${I("users", 14)} Whitelist & Access <span class="saas-tab-badge">${enrolledCount}</span>
            </button>
            <button class="saas-tab-btn ${currentMgrTab === "chat" ? "active" : ""}" data-tab="chat">
              ${I("message", 14)} Chat & Announcements
            </button>
          </div>

          <!-- Tab Content Container -->
          <div id="ep-mgr-tab-body">
            ${renderMgrTabContent(currentMgrTab, state)}
          </div>
        </div>
      </div>
    `;

    document.querySelectorAll(".saas-tab-btn").forEach((btn) => {
      btn.onclick = () => {
        currentMgrTab = btn.getAttribute("data-tab");
        render();
      };
    });

    const btnToggleType = document.getElementById("ep-mgr-toggle-type");
    if (btnToggleType) {
      btnToggleType.onclick = () => {
        const nextType = state.exam.type === "final" ? "general" : "final";
        showManagerConfirmModal({
          title: `Switch Mode to ${nextType === "final" ? "Official Final Test" : "General (Practice)"}`,
          subtitle: "Exam Configuration",
          description: `Change exam mode from <b>${state.exam.type.toUpperCase()}</b> to <b>${nextType.toUpperCase()}</b>. In Final mode, scores and question answers are protected until proctor publication.`,
          confirmText: "Confirm Switch Mode",
          confirmType: "purple",
          icon: "settings",
          onConfirm: () => {
            state.exam.type = nextType;
            saveState(state);
          }
        });
      };
    }

    const btnPublish = document.getElementById("ep-mgr-publish-results");
    if (btnPublish) {
      btnPublish.onclick = () => {
        const willPublish = !state.exam.resultsPublished;
        showManagerConfirmModal({
          title: willPublish ? "Publish Official Cohort Results" : "Unpublish Cohort Results",
          subtitle: "Score Release Gate",
          description: willPublish
            ? "Scores, percentages, correct answers, and faculty explanations will become visible to all students immediately."
            : "Scores and detailed answer explanations will be hidden from student screens.",
          confirmText: willPublish ? "Publish Results" : "Unpublish Results",
          confirmType: "purple",
          icon: "broadcast",
          onConfirm: () => {
            state.exam.resultsPublished = willPublish;
            saveState(state);
          }
        });
      };
    }

    const btnExportCSV = document.getElementById("ep-mgr-export-csv");
    if (btnExportCSV) {
      btnExportCSV.onclick = () => {
        showManagerConfirmModal({
          title: "Export Candidate Records as CSV",
          subtitle: "Telemetry & Score Export",
          description: "Generate and download a CSV file containing marks, attendance timestamps, tab switch violations, and completion statuses for all enrolled students.",
          confirmText: "Download CSV",
          confirmType: "teal",
          icon: "download",
          onConfirm: () => {
            exportMarksAsCSV(state);
          }
        });
      };
    }

    const btnPause = document.getElementById("ep-mgr-pause");
    if (btnPause) {
      btnPause.onclick = () => {
        showManagerConfirmModal({
          title: "Pause Examination",
          subtitle: "Session Suspension",
          description: "All candidate test screens will temporarily pause and countdown timers will halt until resumed.",
          confirmText: "Pause Exam",
          confirmType: "warning",
          icon: "pause",
          onConfirm: () => {
            state.exam.status = "paused";
            saveState(state);
          }
        });
      };
    }

    const btnResume = document.getElementById("ep-mgr-resume");
    if (btnResume) {
      btnResume.onclick = () => {
        showManagerConfirmModal({
          title: "Resume Examination",
          subtitle: "Session Resumption",
          description: "Unpause the examination and restore test screens and clocks for all active candidates.",
          confirmText: "Resume Exam",
          confirmType: "success",
          icon: "play",
          onConfirm: () => {
            state.exam.status = "live";
            saveState(state);
          }
        });
      };
    }

    const btnStart = document.getElementById("ep-mgr-start");
    if (btnStart) {
      btnStart.onclick = () => {
        showManagerConfirmModal({
          title: "Start Live Examination",
          subtitle: "Session Launch",
          description: "Change exam status to LIVE. Enrolled candidates will immediately be permitted to pass onboarding and begin answering questions.",
          confirmText: "Start Exam",
          confirmType: "success",
          icon: "play",
          onConfirm: () => {
            state.exam.status = "live";
            state.exam.startedAt = Date.now();
            saveState(state);
          }
        });
      };
    }

    const btnEnd = document.getElementById("ep-mgr-end");
    if (btnEnd) {
      btnEnd.onclick = () => {
        showManagerConfirmModal({
          title: "End Live Examination",
          subtitle: "Critical Proctor Action",
          description: "This will officially conclude the exam session for all 52 candidates. Active sessions will be locked and current answers forcefully submitted. This action cannot be reversed.",
          confirmText: "Yes, End Examination",
          confirmType: "danger",
          icon: "square",
          requireCheckbox: true,
          checkboxLabel: "I understand this forcefully concludes the exam for all candidates",
          onConfirm: () => {
            state.exam.status = "ended";
            saveState(state);
          }
        });
      };
    }

    [5, 10, 15].forEach((mins) => {
      const el = document.getElementById(`ep-mgr-ext-${mins}`);
      if (el) {
        el.onclick = () => {
          showManagerConfirmModal({
            title: `Extend Exam Time (+${mins} Minutes)`,
            subtitle: "Clock Extension",
            description: `Add <b>${mins} additional minutes</b> to the examination timer for all active students.`,
            confirmText: `Add +${mins}m`,
            confirmType: "teal",
            icon: "clock",
            onConfirm: () => {
              state.exam.extendedMinutes += mins;
              saveState(state);
            }
          });
        };
      }
    });

    bindMgrTabEvents(currentMgrTab, state);
  }

  function exportMarksAsCSV(state) {
    const exam = state.exam;
    const sessions = Object.values(state.studentSessions);
    const totalPossibleMarks = exam.questions.reduce((sum, q) => sum + (q.marks || 0), 0);

    const headers = [
      "Email",
      "Candidate Name",
      "Student ID",
      "Exam Type",
      "Attendance Recorded At",
      "Tab Switch Warnings",
      "Leave Log",
      "Questions Answered",
      "Total Marks Scored",
      "Total Maximum Marks",
      "Percentage",
      "Status"
    ];

    const rows = sessions.map((s, idx) => {
      let score = 0;
      exam.questions.forEach((q) => {
        const studentAns = s.answers ? s.answers[q.id] : undefined;
        if (studentAns !== undefined) {
          if (Array.isArray(q.correct)) {
            if (Array.isArray(studentAns) && JSON.stringify(studentAns.sort()) === JSON.stringify(q.correct.sort())) {
              score += q.marks;
            }
          } else if (String(studentAns).trim().toLowerCase() === String(q.correct).trim().toLowerCase()) {
            score += q.marks;
          }
        }
      });

      const answeredCount = Object.keys(s.answers || {}).length;
      const pct = totalPossibleMarks > 0 ? ((score / totalPossibleMarks) * 100).toFixed(1) : "0.0";

      return [
        `"${s.email}"`,
        `"${s.name}"`,
        `"${s.studentId || "22F30018" + (40 + idx)}"`,
        `"${exam.type.toUpperCase()}"`,
        `"${s.attendanceRecordedAt || "Not Marked"}"`,
        s.warnings || 0,
        `"${(s.warningLogs || [])
          .map((log, logIdx) => {
            const isLive = !log.outsideSeconds && s.outsideSince && logIdx === (s.warningLogs || []).length - 1;
            const seconds = (log.outsideSeconds || 0) + (isLive ? (Date.now() - s.outsideSince) / 1000 : 0);
            return `#${logIdx + 1} ${log.leftAtFormatted || log.timeFormatted || "--"} to ${isLive ? "Still outside" : log.returnedAtFormatted || "--"} (${formatOutsideTime(seconds)})`;
          })
          .join(" | ")}"`,
        `${answeredCount}/${exam.questions.length}`,
        score,
        totalPossibleMarks,
        `${pct}%`,
        `"${s.status}"`
      ].join(",");
    });

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `GenZ_IITian_Exam_Marks_${exam.id}_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function renderMgrTabContent(tab, state) {
    const exam = state.exam;

    if (tab === "monitor") {
      const sessions = Object.values(state.studentSessions);
      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div class="saas-search-box">
              <span style="color:#6b7280;display:flex;align-items:center;">${I("search", 14, "#6b7280")}</span>
              <input type="text" placeholder="Search candidate name or email (Ctrl/Cmd+K)...">
            </div>

            <div style="display:flex;align-items:center;gap:10px;">
              <span style="font-size:12px;color:#9ca3af;">Filter:</span>
              <select style="background:#0d0d0d;border:1px solid #262626;color:#f9fafb;padding:6px 12px;border-radius:6px;font-size:12px;">
                <option>All Candidates</option>
                <option>Active in Session</option>
                <option>Locked / Exit Pending</option>
                <option>Submitted</option>
              </select>
              <button id="ep-mgr-btn-broadcast-nav" style="background:#141414;border:1px solid #262626;color:#f9fafb;padding:6px 12px;border-radius:6px;font-size:12px;font-weight:600;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">
                ${I("broadcast", 13, "#9ca3af")} Broadcast
              </button>
            </div>
          </div>

          <div style="overflow-x:auto;">
            <table class="saas-table">
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Attendance Time</th>
                  <th>Tab Warnings</th>
                  <th>Session Status</th>
                  <th>Progress</th>
                  <th>Time Elapsed</th>
                  <th>Re-entry Gate</th>
                  <th style="text-align:right;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${
                  sessions.length === 0
                    ? `<tr><td colspan="8" style="padding:40px;text-align:center;color:#6b7280;">No active candidate sessions recorded.</td></tr>`
                    : sessions
                        .map((s, idx) => {
                          const ansCount = Object.keys(s.answers || {}).length;
                          const percent = Math.round((ansCount / exam.questions.length) * 100);
                          const isExited = s.status === "exited";
                          const isSubmitted = s.status === "submitted";
                          const dotClass = isExited ? "exited" : isSubmitted ? "submitted" : "active";
                          const warnings = s.warnings || 0;

                          return `
                          <tr>
                            <td>
                              <div class="saas-candidate-cell">
                                <div class="saas-avatar" title="Candidate profile">
                                  ${
                                    s.photoDataUrl
                                      ? `<img src="${s.photoDataUrl}" alt="Webcam Photo" />`
                                      : s.name.split(" ").map((n) => n[0]).join("").slice(0, 2)
                                  }
                                  <span class="saas-avatar-dot ${dotClass}"></span>
                                </div>
                                <div>
                                  <div style="font-weight:700;color:#f9fafb;font-size:13px;display:flex;align-items:center;gap:6px;">
                                    ${s.name}
                                    ${s.photoDataUrl ? `<span style="font-size:10px;padding:1px 5px;border-radius:4px;background:#064e3b;color:#34d399;display:inline-flex;align-items:center;gap:4px;">${I("camera", 10, "#34d399")} Verified</span>` : ""}
                                  </div>
                                  <div style="color:#6b7280;font-size:11px;">${s.email}</div>
                                </div>
                              </div>
                            </td>

                            <td>
                              ${
                                s.attendanceRecordedAt
                                  ? `<span class="saas-badge-success">${I("check", 11, "#34d399")} ${s.attendanceRecordedAt}</span>`
                                  : `<span class="saas-badge-muted">${I("clock", 11, "#9ca3af")} Not Marked</span>`
                              }
                            </td>

                            <td>
                              ${
                                warnings > 0
                                  ? `<span class="saas-badge-danger">${I("alert", 11, "#fb7185")} ${warnings} Tab Switches</span>`
                                  : `<span class="saas-badge-muted" style="color:#34d399;border-color:rgba(16,185,129,0.3);">${I("check", 11, "#34d399")} 0 Warnings</span>`
                              }
                            </td>

                            <td>
                              <span style="display:inline-flex;align-items:center;gap:6px;padding:3px 8px;border-radius:6px;font-size:11px;font-weight:700;
                                background:${isExited ? "rgba(244,63,94,0.12)" : isSubmitted ? "rgba(56,189,248,0.12)" : "rgba(16,185,129,0.12)"};
                                color:${isExited ? "#fb7185" : isSubmitted ? "#38bdf8" : "#34d399"};
                                border:1px solid ${isExited ? "rgba(244,63,94,0.25)" : isSubmitted ? "rgba(56,189,248,0.25)" : "rgba(16,185,129,0.25)"};">
                                ${isExited ? "Exited (Locked)" : isSubmitted ? "Submitted" : "In Session"}
                              </span>
                            </td>

                            <td>
                              <div style="display:flex;align-items:center;gap:10px;min-width:130px;">
                                <div style="flex:1;height:6px;background:#1f1f1f;border-radius:9999px;overflow:hidden;">
                                  <div style="height:100%;background:${percent === 100 ? "#10b981" : "#38bdf8"};width:${percent}%;"></div>
                                </div>
                                <span style="font-size:11px;font-weight:700;color:#9ca3af;font-family:ui-monospace,monospace;">
                                  ${ansCount}/${exam.questions.length}
                                </span>
                              </div>
                            </td>

                            <td style="font-family:ui-monospace,SFMono-Regular,monospace;color:#9ca3af;font-size:12px;">
                              ${s.startedAt ? Math.floor((Date.now() - s.startedAt) / 60000) + "m" : "--"}
                            </td>

                            <td>
                              ${
                                isExited
                                  ? `<span style="color:#fbbf24;font-size:12px;font-weight:700;display:flex;align-items:center;gap:4px;">
                                       ${I("alert", 12, "#fbbf24")} Approval Required
                                     </span>`
                                  : `<span style="color:#10b981;font-size:12px;font-weight:600;display:flex;align-items:center;gap:4px;">
                                       ${I("check", 12, "#10b981")} Normal
                                     </span>`
                              }
                            </td>

                            <td style="text-align:right;">
                              <div style="display:inline-flex;gap:6px;">
                                ${
                                  isExited
                                    ? `<button class="btn-mgr-approve-reentry" data-email="${s.email}" style="background:#064e3b;border:1px solid #047857;color:#34d399;padding:5px 10px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer;">
                                         Approve Re-entry
                                       </button>`
                                    : `<button class="btn-mgr-lock-session" data-email="${s.email}" style="background:#141414;border:1px solid #262626;color:#f9fafb;padding:5px 10px;border-radius:6px;font-size:11px;font-weight:600;cursor:pointer;">
                                         Lock Session
                                       </button>`
                                }
                              </div>
                            </td>
                          </tr>
                        `;
                        })
                        .join("")
                }
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    if (tab === "leave_log") {
      const rows = Object.values(state.studentSessions).flatMap((s) =>
        (s.warningLogs || []).map((log, idx) => {
          const isLive = !log.outsideSeconds && s.outsideSince && idx === (s.warningLogs || []).length - 1;
          const seconds = (log.outsideSeconds || 0) + (isLive ? (Date.now() - s.outsideSince) / 1000 : 0);
          return { s, log, idx, isLive, seconds };
        })
      );

      return `
        <div class="saas-card">
          <div class="saas-table-toolbar">
            <div style="font-size:16px;font-weight:800;color:#f9fafb;display:flex;align-items:center;gap:8px;">
              ${I("clock", 18, "#fb7185")} Leave Log
            </div>
            <div style="font-size:12px;color:#9ca3af;">Each tab/window leave is recorded separately.</div>
          </div>
          <div style="overflow-x:auto;">
            <table class="saas-table">
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Counter</th>
                  <th>Left Site At</th>
                  <th>Returned At</th>
                  <th>Count Time</th>
                  <th>Reason</th>
                </tr>
              </thead>
              <tbody>
                ${
                  rows.length === 0
                    ? `<tr><td colspan="6" style="padding:40px;text-align:center;color:#6b7280;">No leave events recorded.</td></tr>`
                    : rows
                        .map(
                          ({ s, log, idx, isLive, seconds }) => `
                          <tr>
                            <td>
                              <div style="font-weight:700;color:#f9fafb;font-size:13px;">${s.name}</div>
                              <div style="color:#6b7280;font-size:11px;">${s.email}</div>
                            </td>
                            <td><span class="saas-badge-danger">#${idx + 1}</span></td>
                            <td style="font-family:ui-monospace,SFMono-Regular,monospace;color:#e5e7eb;font-size:12px;">${log.leftAtFormatted || log.timeFormatted || "--"}</td>
                            <td>
                              ${
                                isLive
                                  ? `<span class="saas-badge-danger">${I("clock", 11, "#fb7185")} Still outside</span>`
                                  : `<span style="font-family:ui-monospace,SFMono-Regular,monospace;color:#e5e7eb;font-size:12px;">${log.returnedAtFormatted || "--"}</span>`
                              }
                            </td>
                            <td><span class="saas-badge-danger">${I("clock", 11, "#fb7185")} ${formatOutsideTime(seconds)}</span></td>
                            <td style="color:#9ca3af;font-size:12px;">${(log.type || "window_switch").replaceAll("_", " ")}</td>
                          </tr>
                        `
                        )
                        .join("")
                }
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    if (tab === "reentry") {
      const requests = state.reentryRequests;
      return `
        <div class="saas-card" style="padding:24px;">
          <div style="font-size:16px;font-weight:800;color:#f9fafb;margin-bottom:6px;display:flex;align-items:center;gap:8px;">
            ${I("door", 18, "#38bdf8")} Candidate Re-entry Approvals
          </div>
          <p style="color:#9ca3af;font-size:13px;margin-bottom:20px;">
            Security lockdown is triggered whenever a student exits the assessment window. Review and grant re-entry below:
          </p>

          ${
            requests.length === 0
              ? `<div style="text-align:center;padding:40px;background:#080808;border:1px dashed #222222;border-radius:10px;color:#6b7280;font-size:13px;">
                   ${I("checkCircle", 20, "#10b981")} No students currently locked out. Re-entry queue is clear.
                 </div>`
              : `<div style="display:flex;flex-direction:column;gap:12px;">
                   ${requests
                     .map(
                       (r) => `
                     <div style="background:#080808;border:1px solid #1c1c1c;border-radius:10px;padding:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
                       <div>
                         <div style="font-weight:700;color:#f9fafb;font-size:14px;">${r.studentName} (${r.studentEmail})</div>
                         <div style="color:#9ca3af;font-size:12px;margin-top:2px;">
                           Exited at: <b>${new Date(r.timestamp).toLocaleTimeString()}</b> | Reason: "${r.reason || "Window left or minimized"}"
                         </div>
                       </div>
                       <div style="display:flex;gap:8px;">
                         <button class="btn-approve-request" data-id="${r.id}" style="background:#059669;color:#fff;border:none;padding:7px 14px;border-radius:6px;font-size:12px;font-weight:700;cursor:pointer;">
                           Approve & Unlock
                         </button>
                         <button class="btn-reject-request" data-id="${r.id}" style="background:#141414;color:#fb7185;border:1px solid #262626;padding:7px 12px;border-radius:6px;font-size:12px;font-weight:600;cursor:pointer;">
                           Reject
                         </button>
                       </div>
                     </div>
                   `
                     )
                     .join("")}
                 </div>`
          }
        </div>
      `;
    }

    if (tab === "builder") {
      return `
        <div class="saas-card" style="padding:24px;">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">
            <div>
              <div style="font-size:16px;font-weight:800;color:#f9fafb;display:flex;align-items:center;gap:8px;">
                ${I("fileText", 18, "#38bdf8")} Questions Configuration (${exam.questions.length})
              </div>
              <div style="font-size:12px;color:#9ca3af;">Manage sections, marks, negative marking, and code blocks.</div>
            </div>
          </div>

          <div style="display:flex;flex-direction:column;gap:14px;">
            ${exam.questions
              .map(
                (q, idx) => `
              <div style="background:#080808;border:1px solid #1c1c1c;border-radius:10px;padding:16px;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                  <span style="font-weight:800;color:#38bdf8;font-size:13px;">Q${idx + 1} • ${q.type.toUpperCase().replace("_", " ")}</span>
                  <span style="font-size:12px;color:#34d399;font-weight:700;">+${q.marks} Marks ${q.negative ? `| -${q.negative} Neg` : ""}</span>
                </div>
                <div style="font-size:13px;color:#e5e7eb;margin-bottom:8px;">${q.prompt}</div>
                ${q.code ? `<pre style="background:#000000;border:1px solid #1c1c1c;padding:10px;border-radius:6px;font-size:12px;color:#a7f3d0;margin:6px 0;"><code>${q.code}</code></pre>` : ""}
              </div>
            `
              )
              .join("")}
          </div>
        </div>
      `;
    }

    if (tab === "whitelist") {
      return `
        <div class="saas-card" style="padding:24px;">
          <div style="font-size:16px;font-weight:800;color:#f9fafb;margin-bottom:4px;display:flex;align-items:center;gap:8px;">
            ${I("users", 18, "#38bdf8")} Whitelist Access Control (${exam.allowedEmails.length} Students)
          </div>
          <p style="color:#9ca3af;font-size:13px;margin-bottom:18px;">
            Only students whose email addresses are whitelisted can access this examination.
          </p>

          <div style="display:flex;gap:10px;margin-bottom:20px;">
            <input type="email" id="input-new-whitelist" placeholder="Enter student email (e.g. roll@iitm.ac.in)..." style="flex:1;background:#0e0e0e;border:1px solid #262626;color:#f9fafb;padding:9px 14px;border-radius:8px;font-size:13px;" />
            <button id="btn-add-whitelist" style="background:#059669;color:#fff;border:none;padding:9px 18px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">
              + Add Email
            </button>
          </div>

          <div style="display:grid;grid-template-columns:repeat(auto-fill, minmax(240px, 1fr));gap:10px;max-height:360px;overflow-y:auto;padding-right:4px;">
            ${exam.allowedEmails
              .map(
                (email) => `
              <div style="background:#0e0e0e;border:1px solid #1c1c1c;border-radius:8px;padding:8px 12px;display:flex;justify-content:space-between;align-items:center;">
                <span style="font-size:12px;color:#d1d5db;font-family:ui-monospace,monospace;">${email}</span>
                <button class="btn-remove-whitelist" data-email="${email}" style="background:transparent;border:none;color:#fb7185;cursor:pointer;display:inline-flex;align-items:padding:2px 4px;">${I("x", 13, "#fb7185")}</button>
              </div>
            `
              )
              .join("")}
          </div>
        </div>
      `;
    }

    if (tab === "chat") {
      return `
        <div class="saas-card" style="padding:24px;display:flex;flex-direction:column;height:500px;">
          <div style="font-size:16px;font-weight:800;color:#f9fafb;margin-bottom:4px;display:flex;align-items:center;gap:8px;">
            ${I("message", 18, "#38bdf8")} Exam Support Chat & Announcements
          </div>
          <div style="font-size:12px;color:#9ca3af;margin-bottom:14px;">
            Broadcast updates or address candidate inquiries in real-time.
          </div>

          <div id="ep-mgr-chat-stream" style="flex:1;overflow-y:auto;background:#080808;border:1px solid #1c1c1c;border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:10px;margin-bottom:14px;">
            ${
              state.chatMessages.length === 0
                ? `<div style="text-align:center;color:#6b7280;padding:40px;">No messages yet.</div>`
                : state.chatMessages
                    .map(
                      (m) => {
                        const role = m.role || (m.from === "Student" ? "student" : "manager");
                        const isMe = role === "manager";
                        const id = escapeHTML(m.id || "");
                        const sender = escapeHTML(m.senderName || m.from || (isMe ? "Exam Manager" : "Student"));
                        const text = escapeHTML(m.text || m.message || "");
                        return `
                  <div style="align-self:${isMe ? "flex-end" : "flex-start"};max-width:80%;background:${m.isAnnouncement ? "rgba(245,158,11,0.15)" : isMe ? "#064e3b" : "#141414"};border:1px solid ${m.isAnnouncement ? "#b45309" : isMe ? "#047857" : "#262626"};border-radius:10px;padding:10px 14px;">
                    <div style="display:flex;justify-content:space-between;gap:12px;font-size:11px;margin-bottom:4px;color:${isMe ? "#34d399" : "#93c5fd"};font-weight:700;">
                      <span>${sender} ${m.isAnnouncement ? "ANNOUNCEMENT" : ""}</span>
                      <span style="color:#6b7280;">${m.timestamp ? new Date(m.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : escapeHTML(m.time || "")}</span>
                    </div>
                    <div style="font-size:13px;color:#f9fafb;line-height:1.4;white-space:pre-wrap;overflow-wrap:anywhere;">${text}</div>
                    <div style="display:flex;gap:6px;justify-content:flex-end;margin-top:8px;">
                      ${isMe ? `<button class="btn-mgr-chat-edit" data-id="${id}" style="background:#111827;border:1px solid #374151;color:#d1d5db;border-radius:6px;padding:3px 7px;font-size:10px;font-weight:700;cursor:pointer;">Edit</button>` : ""}
                      <button class="btn-mgr-chat-delete" data-id="${id}" style="background:#2a0f13;border:1px solid #7f1d1d;color:#fecaca;border-radius:6px;padding:3px 7px;font-size:10px;font-weight:700;cursor:pointer;">Delete</button>
                    </div>
                  </div>
                `;
                      }
                    )
                    .join("")
            }
          </div>

          <div style="display:flex;gap:10px;">
            <input type="text" id="ep-mgr-chat-input" placeholder="Type announcement or message to candidates..." style="flex:1;background:#080808;border:1px solid #262626;color:#f9fafb;padding:10px 14px;border-radius:8px;font-size:13px;" />
            <button id="ep-mgr-chat-send" style="background:#059669;color:#fff;border:none;padding:10px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">
              Send
            </button>
          </div>
        </div>
      `;
    }

    return "";
  }

  function bindMgrTabEvents(tab, state) {
    if (tab === "monitor") {
      const btnBcast = document.getElementById("ep-mgr-btn-broadcast-nav");
      if (btnBcast) {
        btnBcast.onclick = () => {
          showManagerConfirmModal({
            title: "Switch to Broadcast Channel",
            subtitle: "Proctor Announcements",
            description: "Open the Chat & Announcements channel to broadcast live messages and instructions to all 52 candidates?",
            confirmText: "Go to Broadcast",
            confirmType: "info",
            icon: "broadcast",
            onConfirm: () => {
              currentMgrTab = "chat";
              render();
            }
          });
        };
      }

      document.querySelectorAll(".btn-mgr-lock-session").forEach((btn) => {
        btn.onclick = () => {
          const email = btn.getAttribute("data-email");
          const candidateName = state.studentSessions[email]?.name || email;
          showManagerConfirmModal({
            title: `Lock Session: ${candidateName}`,
            subtitle: "Security Lockdown",
            description: `Immediately freeze candidate workstation for <b>${email}</b> and force an exit. Re-entry will require explicit manager review.`,
            confirmText: "Lock Candidate",
            confirmType: "danger",
            icon: "lock",
            onConfirm: () => {
              if (state.studentSessions[email]) {
                state.studentSessions[email].status = "exited";
                state.reentryRequests.push({
                  id: "reentry-" + Date.now(),
                  studentEmail: email,
                  studentName: state.studentSessions[email].name,
                  timestamp: Date.now(),
                  reason: "Security lockdown initiated by Exam Manager",
                  status: "pending"
                });
                saveState(state);
              }
            }
          });
        };
      });

      document.querySelectorAll(".btn-mgr-approve-reentry").forEach((btn) => {
        btn.onclick = () => {
          const email = btn.getAttribute("data-email");
          const candidateName = state.studentSessions[email]?.name || email;
          showManagerConfirmModal({
            title: `Approve Re-entry: ${candidateName}`,
            subtitle: "Re-entry Authorization",
            description: `Clear security lockdown and allow <b>${email}</b> to resume their examination session.`,
            confirmText: "Approve Re-entry",
            confirmType: "success",
            icon: "check",
            onConfirm: () => {
              if (state.studentSessions[email]) {
                state.studentSessions[email].status = "in_exam";
                state.reentryRequests = state.reentryRequests.filter((r) => r.studentEmail !== email);
                saveState(state);
              }
            }
          });
        };
      });
    }

    if (tab === "reentry") {
      document.querySelectorAll(".btn-approve-request").forEach((btn) => {
        btn.onclick = () => {
          const id = btn.getAttribute("data-id");
          const req = state.reentryRequests.find((r) => r.id === id);
          const name = req ? req.studentName : "Candidate";
          const email = req ? req.studentEmail : "";
          showManagerConfirmModal({
            title: `Approve Candidate Re-entry`,
            subtitle: "Re-entry Queue",
            description: `Approve re-entry request for <b>${name} (${email})</b>. Candidate will be restored to active test session.`,
            confirmText: "Approve Re-entry",
            confirmType: "success",
            icon: "check",
            onConfirm: () => {
              if (req && state.studentSessions[req.studentEmail]) {
                state.studentSessions[req.studentEmail].status = "in_exam";
                state.reentryRequests = state.reentryRequests.filter((r) => r.id !== id);
                saveState(state);
              }
            }
          });
        };
      });

      document.querySelectorAll(".btn-reject-request").forEach((btn) => {
        btn.onclick = () => {
          const id = btn.getAttribute("data-id");
          const req = state.reentryRequests.find((r) => r.id === id);
          const name = req ? req.studentName : "Candidate";
          const email = req ? req.studentEmail : "";
          showManagerConfirmModal({
            title: `Reject Candidate Re-entry`,
            subtitle: "Re-entry Queue",
            description: `Deny re-entry request for <b>${name} (${email})</b>. Candidate session will remain locked.`,
            confirmText: "Reject Request",
            confirmType: "danger",
            icon: "slash",
            onConfirm: () => {
              state.reentryRequests = state.reentryRequests.filter((r) => r.id !== id);
              saveState(state);
            }
          });
        };
      });
    }

    if (tab === "whitelist") {
      const btnAdd = document.getElementById("btn-add-whitelist");
      if (btnAdd) {
        btnAdd.onclick = () => {
          const input = document.getElementById("input-new-whitelist");
          const val = input.value.trim().toLowerCase();
          if (!val) return;
          if (state.exam.allowedEmails.includes(val)) {
            alert("Email already in whitelist.");
            return;
          }
          showManagerConfirmModal({
            title: "Add Candidate to Whitelist",
            subtitle: "Access Control",
            description: `Grant examination access to student email <b>${val}</b>.`,
            confirmText: "Add to Whitelist",
            confirmType: "success",
            icon: "users",
            onConfirm: () => {
              state.exam.allowedEmails.push(val);
              input.value = "";
              saveState(state);
            }
          });
        };
      }

      document.querySelectorAll(".btn-remove-whitelist").forEach((btn) => {
        btn.onclick = () => {
          const email = btn.getAttribute("data-email");
          showManagerConfirmModal({
            title: `Revoke Whitelist Access`,
            subtitle: "Access Control",
            description: `Remove <b>${email}</b> from the allowed candidates whitelist. They will no longer be permitted to take the exam.`,
            confirmText: "Remove Access",
            confirmType: "danger",
            icon: "x",
            onConfirm: () => {
              state.exam.allowedEmails = state.exam.allowedEmails.filter((e) => e !== email);
              saveState(state);
            }
          });
        };
      });
    }

    if (tab === "chat") {
      document.querySelectorAll(".btn-mgr-chat-delete").forEach((btn) => {
        btn.onclick = () => {
          const id = btn.getAttribute("data-id");
          state.chatMessages = state.chatMessages.filter((m) => (m.id || "") !== id);
          saveState(state);
          render();
        };
      });

      document.querySelectorAll(".btn-mgr-chat-edit").forEach((btn) => {
        btn.onclick = () => {
          const id = btn.getAttribute("data-id");
          const msg = state.chatMessages.find((m) => (m.id || "") === id && (m.role || "manager") === "manager");
          if (!msg) return;
          const text = prompt("Edit message", msg.text || msg.message || "");
          if (text === null) return;
          const safeText = text.trim().slice(0, 500);
          if (!safeText) return;
          msg.text = safeText;
          msg.timestamp = Date.now();
          saveState(state);
          render();
        };
      });

      const btnSend = document.getElementById("ep-mgr-chat-send");
      const input = document.getElementById("ep-mgr-chat-input");
      if (btnSend && input) {
        input.maxLength = 500;
        const doSend = () => {
          const text = input.value.trim().slice(0, 500);
          const now = Date.now();
          if (text) {
            if (now - (state.lastManagerChatSentAt || 0) < 3000) return;
            state.lastManagerChatSentAt = now;
            state.chatMessages.push({
              id: "msg-" + now,
              senderName: "Exam Manager",
              role: "manager",
              text: text,
              timestamp: now,
              isAnnouncement: true
            });
            input.value = "";
            saveState(state);
            render();
          }
        };
        btnSend.onclick = () => {
          const text = input.value.trim().slice(0, 500);
          if (!text) return;
          showManagerConfirmModal({
            title: "Broadcast Announcement",
            subtitle: "Live Communication",
            description: `Broadcast the following announcement to all 52 students: <div style="margin-top:8px;padding:8px;background:rgba(255,255,255,0.05);border-radius:6px;font-weight:600;color:#f9fafb;">"${escapeHTML(text)}"</div>`,
            confirmText: "Broadcast to Candidates",
            confirmType: "warning",
            icon: "broadcast",
            onConfirm: doSend
          });
        };
        input.onkeydown = (e) => {
          if (e.key === "Enter") btnSend.click();
        };
      }
    }
  }

  // ==========================================
  // 2. STUDENT PORTAL & EXAM WORKSPACE
  // ==========================================
  let activeWebcamStream = null;
  let tempCapturedPhoto = null;

  function renderStudentInterface(container, state) {
    const student = state.currentUser;
    const exam = state.exam;
    const isWhitelisted = exam.allowedEmails.includes(student.email);

    if (!state.studentSessions[student.email]) {
      state.studentSessions[student.email] = {
        email: student.email,
        name: student.name,
        studentId: "22F3001840",
        status: "not_started",
        onboardingStep: 0,
        attendanceRecordedAt: null,
        attendanceTimestamp: null,
        photoDataUrl: null,
        warnings: 0,
        warningLogs: [],
        outsideExamSeconds: 0,
        outsideSince: null,
        outsideReason: null,
        cocAgreedAt: null,
        cocAgreedAtFormatted: null,
        currentQuestionIndex: 0,
        currentSectionId: exam.sections[0]?.id || "sec-a",
        answers: {},
        reviewFlags: [],
        startedAt: null,
        lastActive: Date.now()
      };
      saveState(state);
    }

    const session = state.studentSessions[student.email];

    if (session.status === "not_started") {
      renderStudentHub(container, state, session, isWhitelisted);
      return;
    }

    if (session.status === "exited") {
      container.innerHTML = `
        <div id="ep-root" style="display:flex;align-items:center;justify-content:center;min-height:80vh;padding:20px;background:#f8fafc;">
          <div class="ep-onboarding-card" style="max-width:480px;">
            <div class="ep-shield-badge" style="background:#fee2e2;">
              ${I("lock", 36, "#dc2626")}
            </div>
            <h2 class="ep-onboarding-title" style="color:#0f172a;">
              Your exam access is waiting for manager approval.
            </h2>
            <p class="ep-onboarding-text">
              You exited the examination window. Security policy requires the course manager to review and approve your re-entry request before you can resume.
            </p>
            <div style="background:#fef3c7;border:1px solid #fde68a;border-radius:10px;padding:12px;color:#92400e;font-size:13px;font-weight:700;margin-bottom:20px;width:100%;display:flex;align-items:center;justify-content:center;gap:8px;">
              ${I("clock", 15, "#92400e")} Request submitted. Waiting for manager approval...
            </div>
            <div style="font-size:12px;color:#64748b;">
              Tip: Switch to <b>Manager View</b> tab above to approve this request in 1 click!
            </div>
          </div>
        </div>
      `;
      return;
    }

    if (session.status === "submitted") {
      renderStudentResultsView(container, state, session);
      return;
    }

    renderStudentLiveExam(container, state, session);
  }

  // ==========================================
  // STUDENT HUB & SCHEDULED EXAMS TAB
  // ==========================================
  function renderStudentHub(container, state, session, isWhitelisted) {
    const exam = state.exam;
    const activeTab = state.studentActiveTab === "results" ? "results" : "scheduled_exams";

    container.innerHTML = `
      <div id="ep-root" style="min-height:calc(100vh - 48px);background:#f8fafc;color:#0f172a;">
        <div class="ep-student-hub">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;flex-wrap:wrap;gap:12px;">
            <div style="display:flex;align-items:center;gap:14px;">
              <img src="/assets/genz-logo.png" alt="GenZ IITIAN" style="height:36px;object-fit:contain;">
              <div>
                <h1 style="font-size:24px;font-weight:800;color:#0f172a;margin:0 0 4px 0;">Student Assessment Portal</h1>
                <div style="font-size:13px;color:#64748b;">
                  Welcome, <b>${state.currentUser.name}</b> (${session.email}) • Roll: <b>22F3001840</b>
                </div>
              </div>
            </div>
            <div style="display:flex;align-items:center;gap:8px;">
              <button id="ep-btn-view-coc" style="background:#ffffff;color:#0f172a;border:1px solid #cbd5e1;padding:7px 12px;border-radius:9999px;font-size:12px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">
                ${I("shield", 13, "#475569")} COC
              </button>
              <span style="font-size:12px;color:#059669;background:#dcfce7;border:1px solid #86efac;padding:5px 12px;border-radius:9999px;font-weight:700;display:inline-flex;align-items:center;gap:6px;">
                ${I("checkCircle", 13, "#059669")} Portal Active
              </span>
            </div>
          </div>

          <div class="ep-hub-nav">
            <button class="ep-hub-tab-btn ${activeTab === "scheduled_exams" ? "active" : ""}" data-tab="scheduled_exams" style="position:relative;">
              ${I("zap", 15)} Scheduled Exams
              <span style="background:#059669;color:#fff;font-size:10px;font-weight:800;padding:2px 7px;border-radius:9999px;margin-left:4px;">
                1 Active
              </span>
            </button>
            <button class="ep-hub-tab-btn ${activeTab === "results" ? "active" : ""}" data-tab="results">
              ${I("barChart", 15)} Past Results & Transcripts
            </button>
          </div>

          ${
            activeTab === "scheduled_exams"
              ? isWhitelisted
                ? `
                <div class="ep-exam-hero-card">
                  <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:12px;margin-bottom:16px;">
                    <div>
                      <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                        <span style="font-size:11px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;padding:3px 8px;border-radius:6px;background:${exam.type === "final" ? "#ffe4e6" : "#e0f2fe"};color:${exam.type === "final" ? "#e11d48" : "#0284c7"};">
                          ${exam.type === "final" ? "OFFICIAL FINAL TEST" : "GENERAL TEST"}
                        </span>
                      </div>
                      <h2 style="font-size:22px;font-weight:800;color:#0f172a;margin:0 0 6px 0;">
                        ${exam.title}
                      </h2>
                      <div style="font-size:13px;color:#64748b;">
                        Subject: <b>${exam.subject}</b> • Term 2 Assessment
                      </div>
                    </div>

                    <button id="ep-btn-attend-exam" style="background:#059669;color:#ffffff;border:none;padding:12px 26px;border-radius:10px;font-size:14px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;gap:8px;box-shadow:0 4px 14px rgba(5,150,105,0.3);">
                      Attend Exam →
                    </button>
                  </div>

                  <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(180px, 1fr));gap:12px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:16px;margin-bottom:18px;">
                    <div>
                      <div style="font-size:11px;color:#64748b;font-weight:700;text-transform:uppercase;">Time Limit</div>
                      <div style="font-size:15px;font-weight:800;color:#0f172a;margin-top:2px;">
                        ${exam.durationMinutes} Minutes
                      </div>
                    </div>
                    <div>
                      <div style="font-size:11px;color:#64748b;font-weight:700;text-transform:uppercase;">Total Marks</div>
                      <div style="font-size:15px;font-weight:800;color:#0f172a;margin-top:2px;">
                        +22 Marks (8 Questions)
                      </div>
                    </div>
                    <div>
                      <div style="font-size:11px;color:#64748b;font-weight:700;text-transform:uppercase;">Verification</div>
                      <div style="font-size:13px;font-weight:700;color:#475569;margin-top:2px;">
                        Attendance + Live Photo
                      </div>
                    </div>
                  </div>

                </div>
              `
                : `
                <div class="ep-exam-hero-card" style="text-align:center;padding:40px;">
                  <div style="margin-bottom:12px;">${I("slash", 40, "#dc2626")}</div>
                  <h3 style="font-size:20px;font-weight:800;color:#0f172a;margin:0 0 8px 0;">Access Restricted</h3>
                  <p style="color:#64748b;font-size:14px;max-width:460px;margin:0 auto 18px auto;">
                    Your email (<b>${session.email}</b>) has not been added to the whitelist for this examination.
                  </p>
                  <div style="font-size:12px;color:#94a3b8;">
                    Contact your course manager or switch to <b>Manager View</b> to whitelist your address.
                  </div>
                </div>
              `
              : ""
          }

          ${
            activeTab === "results"
              ? `<div class="ep-exam-hero-card" style="padding:24px;">
                   <div style="font-size:16px;font-weight:800;color:#0f172a;margin-bottom:8px;">Past Exam Transcripts</div>
                   <p style="color:#64748b;font-size:13px;">No past semester transcripts recorded yet for this session.</p>
                 </div>`
              : ""
          }
        </div>
      </div>
    `;

    document.querySelectorAll(".ep-hub-tab-btn").forEach((btn) => {
      btn.onclick = () => {
        state.studentActiveTab = btn.getAttribute("data-tab");
        saveState(state);
      };
    });

    const btnAttend = document.getElementById("ep-btn-attend-exam");
    if (btnAttend) {
      btnAttend.onclick = () => {
        if (getExamDeviceInfo().isPhone) {
          showLaptopOnlyModal();
          return;
        }
        if (state.exam.status === "ended") {
          showExamEndedRejoinModal();
          return;
        }
        state.activeOnboardingModal = 1;
        saveState(state);
      };
    }

    const btnViewCoc = document.getElementById("ep-btn-view-coc");
    if (btnViewCoc) {
      btnViewCoc.onclick = showCocModal;
    }

    if (state.activeOnboardingModal) {
      renderOnboardingModal(state, session);
    }
  }

  function showCocModal() {
    const oldModal = document.getElementById("ep-coc-modal");
    if (oldModal) oldModal.remove();

    const modal = document.createElement("div");
    modal.id = "ep-coc-modal";
    modal.className = "ep-modal-backdrop";
    modal.style.display = "flex";
    modal.innerHTML = `
      <div class="ep-onboarding-card" style="max-width:760px;text-align:left;max-height:86vh;overflow-y:auto;">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:16px;">
          <div>
            <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">
              ${I("shield", 22, "#059669")}
              <h2 style="font-size:20px;font-weight:800;color:#0f172a;margin:0;">Candidate Code of Conduct</h2>
            </div>
          </div>
          <button id="ep-coc-close" style="background:#f8fafc;border:1px solid #cbd5e1;color:#334155;border-radius:8px;padding:8px 10px;cursor:pointer;font-weight:800;">
            ${I("x", 14, "#334155")}
          </button>
        </div>

        <h3 style="font-size:16px;font-weight:800;color:#1e3a8a;margin:0 0 12px 0;">
          Online Remote Proctored Exams
        </h3>
        <p style="font-size:13.5px;color:#334155;line-height:1.7;margin-bottom:18px;">
          This exam is conducted online from the examinee's place of residence and proctored remotely. The following guidelines must be followed by all examinees.
        </p>
        <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(240px, 1fr));gap:12px;">
          ${[
            ["Personal details", "No examinee shall share personal details with proctors, including but not limited to phone number or address, during or after the exam."],
            ["Clean desk", "The table or desk where the examinee takes this exam shall not have any items kept that may have sensitive information, including but not limited to phone numbers and address."],
            ["No assistance", "No examinee shall aid, or attempt to aid, another candidate by discussing answers via email, text, chat, call, or any other method."],
            ["Confidential exam", "No examinee will disclose any details of what happened during the exam or examination trials to anyone outside."],
            ["Ask inside exam", "If an examinee wishes to ask a question during the exam, they should post the query in the exam room chat window and the proctor will clarify the issue."],
            ["Violation action", "If any examinee is found to have violated the Code of Conduct for Online Examinations, or to have acted improperly, they will be liable to disciplinary procedures. This can include withholding exam results, suspension, or termination from the program."]
          ]
            .map(
              ([title, body], idx) => `
                <div style="border:1px solid #e2e8f0;background:#f8fafc;border-radius:12px;padding:12px 14px;">
                  <div style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:800;color:#0f172a;margin-bottom:6px;">
                    <span style="width:22px;height:22px;border-radius:9999px;background:#dcfce7;color:#047857;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:900;">${idx + 1}</span>
                    ${title}
                  </div>
                  <div style="font-size:12.5px;line-height:1.55;color:#475569;">${body}</div>
                </div>
              `
            )
            .join("")}
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    const close = () => modal.remove();
    document.getElementById("ep-coc-close").onclick = close;
    modal.addEventListener("click", (e) => {
      if (e.target === modal) close();
    });
  }

  // ==========================================
  // ONBOARDING MODALS (4-Step Sequential Flow)
  // ==========================================
  function renderOnboardingModal(state, session) {
    const step = state.activeOnboardingModal;
    const exam = state.exam;

    let backdrop = document.getElementById("ep-modal-wrapper");
    if (!backdrop) {
      backdrop = document.createElement("div");
      backdrop.id = "ep-modal-wrapper";
      backdrop.className = "ep-modal-backdrop";
      document.body.appendChild(backdrop);
    }

    // STEP 1: Environment & Network Checklist
    if (step === 1) {
      backdrop.innerHTML = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge">
            ${I("shield", 36, "#059669")}
          </div>

          <h2 class="ep-onboarding-title">Exam Environment Check</h2>
          <p class="ep-onboarding-text">
          Please confirm your testing workspace meets GenZ IITian academic integrity standards:
          </p>

          <div class="ep-checklist-box">
            <div class="ep-checklist-item">
              ${I("lock", 16, "#059669")}
              <div><b>Locked & Private Room:</b> Ensure you are alone with no other persons present.</div>
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

          <button id="ep-btn-step1-next" class="ep-modal-btn">
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

      document.getElementById("ep-btn-step1-next").onclick = () => {
        state.activeOnboardingModal = 2;
        saveState(state);
      };
      return;
    }

    // STEP 2: Attendance Modal (Exact replica of user's uploaded image!)
    if (step === 2) {
      backdrop.innerHTML = `
        <div class="ep-onboarding-card">
          <!-- Circular badge with verified scalloped shield checkmark -->
          <div class="ep-shield-badge" style="background:#e2e8f0;">
            <svg width="40" height="40" viewBox="0 0 24 24" fill="#334155" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 1L14.7 3.3L18.3 3.6L19.4 7.1L22.4 9.1L21.8 12.7L23.3 16L20.5 18.3L19.8 21.9L16.2 22.1L13.8 24.5L10.5 23.3L7.7 24.5L5.3 22.1L1.7 21.9L1 18.3L-1.8 16L-0.3 12.7L-0.9 9.1L2.1 7.1L3.2 3.6L6.8 3.3L9.5 1L12 1Z" opacity="0.15" />
              <circle cx="12" cy="12" r="10" fill="#334155"/>
              <path d="M8 12.3L10.7 15L16.3 9.4" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>

          <h2 class="ep-onboarding-title">Record my Attendance</h2>
          <p class="ep-onboarding-text" style="font-size:13.5px;color:#334155;line-height:1.65;margin-bottom:24px;">
            By marking your attendance, you confirm your presence for the exam. Please note that once your attendance is recorded, any exit from the exam session will be registered and could affect your ability to continue. Make sure you're ready before proceeding. If you face any technical issues, reach out to support immediately
          </p>

          <button id="ep-btn-step2-confirm" class="ep-modal-btn" style="background:#475569;">
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

      document.getElementById("ep-btn-step2-confirm").onclick = () => {
        const timeStr = new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
        session.attendanceRecordedAt = timeStr;
        session.attendanceTimestamp = Date.now();
        state.activeOnboardingModal = 3;
        saveState(state);
      };
      return;
    }

    // STEP 3: Live Camera Photo Verification
    if (step === 3) {
      tempCapturedPhoto = null;
      backdrop.innerHTML = `
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
            <img id="ep-cam-snapshot" class="ep-cam-preview-img" style="display:none;" />
            <div id="ep-cam-fallback-tag" style="display:none;position:absolute;bottom:8px;left:8px;font-size:10px;background:rgba(0,0,0,0.6);color:#fff;padding:2px 6px;border-radius:4px;">
              Live Viewfinder
            </div>
          </div>

          <div id="ep-cam-action-bar" style="width:100%;">
            <button id="ep-btn-take-photo" class="ep-modal-btn" style="background:#059669;display:flex;align-items:center;justify-content:center;gap:8px;">
              ${I("camera", 16, "#ffffff")} Capture Photo
            </button>
          </div>

          <div id="ep-cam-confirm-bar" style="display:none;width:100%;gap:10px;">
            <button id="ep-btn-retake-photo" class="ep-modal-btn" style="background:#f1f5f9;color:#334155;border:1px solid #cbd5e1;flex:1;display:flex;align-items:center;justify-content:center;gap:6px;">
              ${I("refresh", 14, "#334155")} Retake
            </button>
            <button id="ep-btn-confirm-photo" class="ep-modal-btn" style="background:#059669;flex:1;display:flex;align-items:center;justify-content:center;gap:6px;">
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

      const video = document.getElementById("ep-cam-stream");
      const canvas = document.getElementById("ep-cam-canvas");
      const snapshotImg = document.getElementById("ep-cam-snapshot");
      const btnTake = document.getElementById("ep-btn-take-photo");
      const btnRetake = document.getElementById("ep-btn-retake-photo");
      const btnConfirm = document.getElementById("ep-btn-confirm-photo");
      const actionBar = document.getElementById("ep-cam-action-bar");
      const confirmBar = document.getElementById("ep-cam-confirm-bar");

      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        navigator.mediaDevices
          .getUserMedia({ video: { width: 320, height: 240 } })
          .then((stream) => {
            activeWebcamStream = stream;
            video.srcObject = stream;
          })
          .catch(() => {
            simulateCanvasCamera(canvas, video);
          });
      } else {
        simulateCanvasCamera(canvas, video);
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
        snapshotImg.src = dataUrl;
        const tag = document.getElementById("ep-cam-fallback-tag");
        if (tag) tag.style.display = "block";
      }

      btnTake.onclick = () => {
        const ctx = canvas.getContext("2d");
        if (video.videoWidth > 0) {
          ctx.drawImage(video, 0, 0, 320, 240);
        } else {
          simulateCanvasCamera(canvas, video);
        }
        tempCapturedPhoto = canvas.toDataURL("image/jpeg");
        snapshotImg.src = tempCapturedPhoto;
        video.style.display = "none";
        snapshotImg.style.display = "block";

        actionBar.style.display = "none";
        confirmBar.style.display = "flex";
      };

      btnRetake.onclick = () => {
        video.style.display = "block";
        snapshotImg.style.display = "none";
        actionBar.style.display = "block";
        confirmBar.style.display = "none";
      };

      btnConfirm.onclick = () => {
        session.photoDataUrl = tempCapturedPhoto;
        if (activeWebcamStream) {
          activeWebcamStream.getTracks().forEach((t) => t.stop());
          activeWebcamStream = null;
        }
        state.activeOnboardingModal = 4;
        saveState(state);
      };
      return;
    }

    // STEP 4: Exam Protocol & Final Agreement (Checkbox unselected by default, no emojis)
    if (step === 4) {
      backdrop.innerHTML = `
        <div class="ep-onboarding-card">
          <div class="ep-shield-badge" style="background:#fef3c7;">
            ${I("fileText", 36, "#d97706")}
          </div>

          <h2 class="ep-onboarding-title" style="margin-bottom:6px;">
            Exam Type — ${exam.type === "final" ? "Final Test" : "General Test"}
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

          <!-- NOT checked by default -->
          <label style="display:flex;align-items:center;gap:10px;font-size:13px;font-weight:600;color:#334155;cursor:pointer;margin-bottom:20px;text-align:left;width:100%;">
            <input type="checkbox" id="ep-cb-agree" style="width:17px;height:17px;accent-color:#059669;cursor:pointer;" />
            <span>I understand and agree to all examination rules.</span>
          </label>

          <!-- Disabled by default, NO rocket emoji -->
          <button id="ep-btn-final-enter" class="ep-modal-btn" disabled style="background:#94a3b8;color:#ffffff;cursor:not-allowed;box-shadow:none;">
            I Agree & Start Exam
          </button>

          <div class="ep-modal-stepper">
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot"></span>
            <span class="ep-stepper-dot active"></span>
          </div>
        </div>
      `;

      const cb = document.getElementById("ep-cb-agree");
      const btn = document.getElementById("ep-btn-final-enter");

      cb.onchange = () => {
        if (cb.checked) {
          btn.disabled = false;
          btn.style.background = "#059669";
          btn.style.cursor = "pointer";
          btn.style.boxShadow = "0 4px 14px rgba(5,150,105,0.3)";
        } else {
          btn.disabled = true;
          btn.style.background = "#94a3b8";
          btn.style.cursor = "not-allowed";
          btn.style.boxShadow = "none";
        }
      };

      btn.onclick = () => {
        if (!cb.checked) return;
        if (getExamDeviceInfo().isPhone) {
          showLaptopOnlyModal();
          return;
        }
        session.status = "in_exam";
        session.startedAt = Date.now();
        session.cocAgreedAt = null;
        session.cocAgreedAtFormatted = null;
        session.currentSectionId = "sec-coc";
        state.activeOnboardingModal = null;
        if (backdrop) backdrop.remove();
        saveState(state);
      };
      return;
    }
  }

  // ==========================================
  // LIVE EXAM WORKSPACE
  // ==========================================
  function renderStudentLiveExam(container, state, session) {
    const exam = state.exam;
    const currentQIdx = session.currentQuestionIndex || 0;
    const currentQuestion = exam.questions[currentQIdx] || exam.questions[0];
    const totalQ = exam.questions.length;
    const sectionQuestions = exam.questions.filter((q) => q.sectionId === session.currentSectionId);
    const sectionAnsweredCount = sectionQuestions.filter((q) => session.answers[q.id] !== undefined && session.answers[q.id] !== "").length;
    const sectionReviewCount = sectionQuestions.filter((q) => session.reviewFlags.includes(q.id)).length;
    const sectionUnansweredCount = sectionQuestions.length - sectionAnsweredCount;
    const currentSectionQuestionIndex = Math.max(0, sectionQuestions.findIndex((q) => q.id === currentQuestion?.id));

    const totalSeconds = (exam.durationMinutes + exam.extendedMinutes) * 60;
    const elapsedSeconds = session.startedAt ? Math.floor((Date.now() - session.startedAt) / 1000) : 0;
    const remainingSeconds = Math.max(0, totalSeconds - elapsedSeconds);
    const mins = Math.floor(remainingSeconds / 60);
    const secs = remainingSeconds % 60;
    const timeFormatted = `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;

    const warnings = session.warnings || 0;

    container.innerHTML = `
      <div id="ep-root" class="ep-live-exam-root" style="display:flex;flex-direction:column;height:calc(100vh - 48px);overflow:hidden;background:#f8fafc;user-select:none;-webkit-user-select:none;">
        <!-- Top Header Bar -->
        <header style="height:clamp(62px, 5.4vw, 82px);background:#ffffff;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between;padding:0 clamp(18px, 2vw, 34px);flex-shrink:0;">
          <div style="display:flex;align-items:center;gap:12px;">
            <img src="/assets/genz-logo.png" alt="GenZ IITIAN" style="height:30px;max-width:90px;object-fit:contain;">
            <div>
              <h1 style="font-size:clamp(14px, 1.15vw, 21px);font-weight:800;color:#0f172a;margin:0;">${exam.title}</h1>
              <div style="font-size:clamp(11px, 0.9vw, 15px);color:#64748b;">
                ${session.name} (${session.email}) • Attendance: <b>${session.attendanceRecordedAt || "Verified"}</b>
              </div>
            </div>
          </div>

          <!-- Warnings, Timer & Submit -->
          <div style="display:flex;align-items:center;gap:10px;">
            <div id="ep-warning-chip" class="ep-header-warning ${warnings > 0 ? "warning-active" : ""}">
              ${I("alert", 14, warnings > 0 ? "#dc2626" : "#64748b")}
              Warnings: <b id="ep-warning-val">${warnings}</b>
            </div>

            <!-- Live Timer -->
            <div style="display:flex;align-items:center;gap:6px;background:#f1f5f9;padding:6px 12px;border-radius:8px;border:1px solid #cbd5e1;">
              <span style="width:8px;height:8px;border-radius:9999px;background:${mins < 5 || exam.status === "ended" ? "#ef4444" : "#059669"};animation:ep-pulse 2s infinite;"></span>
              <span style="font-size:11px;font-weight:700;color:#64748b;">Time:</span>
              <span style="font-size:15px;font-weight:800;color:${mins < 5 || exam.status === "ended" ? "#ef4444" : "#0f172a"};font-family:ui-monospace,monospace;">
                ${exam.status === "ended" ? "ENDED" : timeFormatted}
              </span>
            </div>

            <!-- Exit Button -->
            <button id="btn-student-submit" style="background:#059669;border:none;color:#fff;padding:7px 18px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:6px;box-shadow:0 1px 3px rgba(5,150,105,0.3);transition:background 0.15s;">
              ${I("check", 13, "#ffffff")} Submit & Exit
            </button>
          </div>
        </header>

        <!-- Main Body -->
        <div style="display:flex;flex:1;overflow:hidden;">
          <aside id="ep-sidebar" style="width:clamp(280px, 24vw, 380px);background:#ffffff;border-right:2px solid #0f172a;display:flex;flex-direction:column;flex-shrink:0;">
            <div style="padding:14px 16px;border-bottom:1px solid #e2e8f0;">
              <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:8px;">
                Sections
              </div>
              <div style="display:flex;flex-direction:column;gap:6px;">
                ${exam.sections
                  .map((sec) => {
                    const isActive = sec.id === session.currentSectionId;
                    const isCoc = sec.id === "sec-coc";
                    const lockedUntilCoc = !isCoc && !session.cocAgreedAt;
                    const secQCount = exam.questions.filter((q) => q.sectionId === sec.id).length;
                    return `
                      <button class="btn-select-section ep-section-btn" data-id="${sec.id}" style="text-align:left;padding:8px 12px;border-radius:8px;border:1.5px solid ${isActive ? "#059669" : "#e2e8f0"};background:${isActive ? "#f0fdf4" : "#ffffff"};color:${lockedUntilCoc ? "#94a3b8" : isActive ? "#059669" : "#334155"};font-weight:700;font-size:13px;cursor:pointer;display:flex;align-items:center;justify-content:space-between;gap:6px;opacity:${lockedUntilCoc ? "0.65" : "1"};">
                        <span style="display:inline-flex;align-items:center;gap:6px;">
                          ${isCoc ? I("shield", 13, isActive ? "#059669" : "#64748b") : ""}
                          ${sec.title}
                        </span>
                        ${isCoc ? `<span style="font-size:10px;font-weight:800;background:#dbeafe;color:#1e40af;padding:1px 6px;border-radius:4px;">RULES</span>` : `<span>(${secQCount})</span>`}
                      </button>
                    `;
                  })
                  .join("")}
              </div>
            </div>

            <!-- Question Palette Grid -->
            <div style="flex:1;overflow-y:auto;padding:16px;">
              <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#64748b;margin-bottom:12px;">
                Question Palette
              </div>
              <div class="ep-q-grid">
                ${sectionQuestions.length
                  ? sectionQuestions
                      .map((q, sectionQIndex) => {
                    const qIndex = exam.questions.findIndex((item) => item.id === q.id);
                    const isAnswered = session.answers[q.id] !== undefined && session.answers[q.id] !== "";
                    const isReviewed = session.reviewFlags.includes(q.id);
                    const isCurrent = qIndex === currentQIdx && session.currentSectionId !== "sec-coc";

                    let statusClass = "ep-q-unvisited";
                    if (isReviewed) statusClass = "ep-q-review";
                    else if (isAnswered) statusClass = "ep-q-answered";

                    return `
                      <button class="ep-q-btn ${statusClass} ${isCurrent ? "current" : ""}" data-q="${qIndex}" style="${!session.cocAgreedAt ? "opacity:0.55;cursor:not-allowed;" : ""}">
                        ${sectionQIndex + 1}
                      </button>
                    `;
                  })
                  .join("")
                  : `<div style="grid-column:1/-1;color:#94a3b8;font-size:12px;font-weight:700;text-align:center;padding:14px 0;">No questions in this section</div>`}
              </div>
            </div>

            <div style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#ffffff;">
              <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
                <button id="ep-btn-calc" title="Open Calculator" style="background:#f0fdf4;border:1px solid #86efac;color:#047857;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                  ${I("calculator", 13, "#047857")} Calculator
                </button>
                <button id="ep-btn-header-chat" style="background:#0f172a;color:#fff;border:none;padding:9px 10px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                  ${I("message", 13, "#ffffff")} Doubts ${state.chatMessages.length > 0 ? `<span style="background:#059669;color:#fff;font-size:10px;padding:1px 6px;border-radius:9999px;">${state.chatMessages.length}</span>` : ""}
                </button>
              </div>
            </div>

            <!-- Legend Summary -->
            <div style="padding:12px 16px;border-top:1px solid #e2e8f0;background:#f8fafc;font-size:11px;color:#475569;">
              <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;">
                <div style="display:flex;align-items:center;gap:6px;">
                  <span style="width:10px;height:10px;border-radius:3px;background:#dcfce7;border:1px solid #86efac;"></span>
                  Answered (${sectionAnsweredCount})
                </div>
                <div style="display:flex;align-items:center;gap:6px;">
                  <span style="width:10px;height:10px;border-radius:3px;background:#ede9fe;border:1px solid #c4b5fd;"></span>
                  Review (${sectionReviewCount})
                </div>
                <div style="display:flex;align-items:center;gap:6px;">
                  <span style="width:10px;height:10px;border-radius:3px;background:#f1f5f9;border:1px solid #cbd5e1;"></span>
                  Unvisited (${sectionUnansweredCount})
                </div>
              </div>
            </div>
          </aside>

          <!-- Main Workspace -->
          <main style="flex:1;display:flex;flex-direction:column;overflow-y:auto;padding:clamp(22px, 2vw, 42px) clamp(28px, 3vw, 58px);background:#ffffff;">
            ${
              session.currentSectionId === "sec-coc"
                ? `
                <!-- Code of Conduct (COC) Full View -->
                <div style="flex:1;overflow-y:auto;max-width:880px;">
                  <div style="display:flex;align-items:center;gap:12px;margin-bottom:14px;padding-bottom:12px;border-bottom:1px solid #e2e8f0;">
                    <img src="/assets/genz-logo.png" alt="GenZ IITIAN" style="height:28px;object-fit:contain;">
                    <div style="font-size:16px;font-weight:800;color:#0f172a;">Candidate Code of Conduct</div>
                  </div>

                  <h2 style="font-size:16px;font-weight:800;color:#1e3a8a;margin:0 0 12px 0;">
                    Online Remote Proctored Exams
                  </h2>
                  <p style="font-size:13.5px;color:#334155;line-height:1.7;margin-bottom:18px;">
                    This exam is conducted online from the examinee's place of residence and proctored remotely by the GenZ IITian team. The following guidelines must be followed by all examinees.
                  </p>

                  <ol style="font-size:13px;color:#334155;line-height:1.75;padding-left:22px;display:flex;flex-direction:column;gap:10px;margin-bottom:28px;">
                    <li><b>Personal details:</b> No examinee shall share personal details with proctors, including but not limited to phone number or address, during or after the exam.</li>
                    <li><b>Clean desk:</b> The table or desk where the examinee takes this exam shall not have any items kept that may have sensitive information, including but not limited to phone numbers and address.</li>
                    <li><b>No assistance:</b> No examinee shall aid, or attempt to aid, another candidate by discussing answers via email, text, chat, call, or any other method.</li>
                    <li><b>Confidential exam:</b> No examinee will disclose any details of what happened during the exam or examination trials to anyone outside.</li>
                    <li><b>Ask inside exam:</b> If an examinee wishes to ask a question during the exam, they should post the query in the exam room chat window and the proctor will clarify the issue.</li>
                    <li><b>Violation action:</b> If any examinee is found to have violated the Code of Conduct for Online Examinations, or to have acted improperly, they will be liable to disciplinary procedures. This can include withholding exam results, suspension, or termination from the program.</li>
                  </ol>

                  <div style="padding-top:16px;border-top:1px solid #e2e8f0;display:flex;flex-direction:column;align-items:flex-start;gap:14px;">
                    <label style="display:flex;align-items:center;gap:10px;font-size:13px;font-weight:700;color:#334155;cursor:pointer;">
                      <input type="checkbox" id="ep-coc-agree" ${session.cocAgreedAt ? "checked" : ""} style="width:17px;height:17px;accent-color:#059669;cursor:pointer;" />
                      <span>I know and I agree to follow the Code of Conduct.</span>
                    </label>
                    ${session.cocAgreedAtFormatted ? `<div style="font-size:11.5px;color:#64748b;">Agreed at: <b>${session.cocAgreedAtFormatted}</b></div>` : ""}
                    <button id="ep-btn-coc-continue" ${session.cocAgreedAt ? "" : "disabled"} style="background:${session.cocAgreedAt ? "#059669" : "#94a3b8"};color:#ffffff;border:none;padding:10px 22px;border-radius:8px;font-size:13px;font-weight:700;cursor:${session.cocAgreedAt ? "pointer" : "not-allowed"};display:inline-flex;align-items:center;gap:8px;box-shadow:${session.cocAgreedAt ? "0 2px 8px rgba(5,150,105,0.25)" : "none"};">
                      ${I("check", 14, "#ffffff")} Back to Exam Questions →
                    </button>
                  </div>
                </div>
                `
                : `
                <!-- Question Top Details -->
                <div style="display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #e2e8f0;padding-bottom:12px;margin-bottom:18px;">
                  <div style="display:flex;align-items:center;gap:10px;">
                    <span style="font-size:17px;font-weight:800;color:#0f172a;">Question ${currentSectionQuestionIndex + 1} of ${sectionQuestions.length}</span>
                    <span style="padding:3px 8px;border-radius:6px;background:#e0f2fe;color:#0369a1;font-size:11px;font-weight:700;">
                      ${currentQuestion.type.toUpperCase().replace("_", " ")}
                    </span>
                  </div>
                  <div style="font-size:12px;font-weight:700;color:#059669;">
                    +${currentQuestion.marks} Marks ${currentQuestion.negative ? `| -${currentQuestion.negative} Negative` : ""}
                  </div>
                </div>

                <!-- Question Prompt -->
                <div style="font-size:15px;color:#0f172a;line-height:1.6;font-weight:500;margin-bottom:14px;">
                  ${currentQuestion.prompt}
                </div>

                <!-- Code snippet if any -->
                ${
                  currentQuestion.code
                    ? `<pre style="background:#0f172a;color:#f8fafc;padding:14px;border-radius:8px;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:13px;line-height:1.5;margin-bottom:18px;overflow-x:auto;"><code>${currentQuestion.code}</code></pre>`
                    : ""
                }

                <!-- Answer Options -->
                <div style="margin-bottom:28px;">
                  ${renderQuestionInputs(currentQuestion, session.answers[currentQuestion.id])}
                </div>

                <!-- Action Bar -->
                <div style="margin-top:auto;display:flex;justify-content:space-between;align-items:center;border-top:1px solid #e2e8f0;padding-top:18px;">
                  <div style="display:flex;gap:8px;">
                    <button id="btn-q-prev" ${currentQIdx === 0 ? "disabled" : ""} style="background:#fff;border:1px solid #cbd5e1;color:#475569;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:${currentQIdx === 0 ? "not-allowed" : "pointer"};opacity:${currentQIdx === 0 ? 0.4 : 1};">
                      ← Prev
                    </button>
                    <button id="btn-q-clear" style="background:#fff;border:1px solid #cbd5e1;color:#64748b;padding:9px 14px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">
                      Clear
                    </button>
                  </div>

                  <div style="display:flex;gap:8px;">
                    <button id="btn-q-review" style="background:#f5f3ff;border:1px solid #c4b5fd;color:#6d28d9;padding:9px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;">
                      ${session.reviewFlags.includes(currentQuestion.id) ? "Marked for Review" : "Review & Next"}
                    </button>
                    <button id="btn-q-save-next" style="background:#059669;color:#fff;border:none;padding:9px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">
                      ${currentQIdx === totalQ - 1 ? "Save Response" : "Save & Next →"}
                    </button>
                  </div>
                </div>
                `
            }
          </main>
        </div>
      </div>
    `;

    if (exam.status === "ended") {
      showExamEndedForceModal(state, session);
    }

    bindStudentLiveExamEvents(state, session, currentQIdx, currentQuestion, totalQ);
  }

  function renderTabSwitchAlertModal(state, session) {
    let backdrop = document.getElementById("ep-tabswitch-modal");
    if (!backdrop) {
      backdrop = document.createElement("div");
      backdrop.id = "ep-tabswitch-modal";
      backdrop.className = "ep-modal-backdrop";
      document.body.appendChild(backdrop);
    }

    backdrop.innerHTML = `
      <div class="ep-onboarding-card" style="border:2px solid #ef4444;max-width:440px;">
        <div class="ep-shield-badge" style="background:#fee2e2;margin-bottom:12px;">
          ${I("alert", 36, "#dc2626")}
        </div>
        <h3 style="font-size:20px;font-weight:800;color:#991b1b;margin:0 0 8px 0;">
          Warning: Tab Change Detected!
        </h3>
        <p style="color:#64748b;font-size:13px;line-height:1.5;margin-bottom:16px;">
          You switched away from the exam tab. Navigating outside the testing window is an infraction and has been recorded.
        </p>

        <div style="background:#fef2f2;border:1px solid #fecaca;padding:12px;border-radius:10px;margin-bottom:20px;width:100%;text-align:center;">
          <span style="font-size:11px;color:#991b1b;font-weight:700;text-transform:uppercase;">TOTAL WARNING COUNT</span>
          <div style="font-size:26px;font-weight:900;color:#dc2626;margin:4px 0;">${session.warnings}</div>
        </div>

        <button id="ep-btn-resume-tabswitch" class="ep-modal-btn" style="background:#0f172a;">
          I Understand & Resume Exam
        </button>
      </div>
    `;

    document.getElementById("ep-btn-resume-tabswitch").onclick = () => {
      tabSwitchAlertActive = false;
      if (backdrop) backdrop.remove();
      render();
    };
  }

  function renderQuestionInputs(q, currentAnswer) {
    if (q.type === "mcq_single" || q.type === "true_false") {
      return `
        <div style="display:flex;flex-direction:column;gap:10px;">
          ${q.options
            .map((opt, i) => {
              const isChecked = currentAnswer === i;
              return `
              <label style="display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:10px;border:1.5px solid ${isChecked ? "#059669" : "#e2e8f0"};background:${isChecked ? "#f0fdf4" : "#ffffff"};cursor:pointer;transition:all 0.15s ease;">
                <input type="radio" name="opt-mcq" value="${i}" ${isChecked ? "checked" : ""} style="width:16px;height:16px;accent-color:#059669;" />
                <span style="font-size:14px;color:#1e293b;font-weight:${isChecked ? "600" : "500"};">${opt}</span>
              </label>
            `;
            })
            .join("")}
        </div>
      `;
    }

    if (q.type === "mcq_multi") {
      const selectedArr = Array.isArray(currentAnswer) ? currentAnswer : [];
      return `
        <div style="display:flex;flex-direction:column;gap:10px;">
          ${q.options
            .map((opt, i) => {
              const isChecked = selectedArr.includes(i);
              return `
              <label style="display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:10px;border:1.5px solid ${isChecked ? "#059669" : "#e2e8f0"};background:${isChecked ? "#f0fdf4" : "#ffffff"};cursor:pointer;transition:all 0.15s ease;">
                <input type="checkbox" name="opt-multi" value="${i}" ${isChecked ? "checked" : ""} style="width:16px;height:16px;accent-color:#059669;" />
                <span style="font-size:14px;color:#1e293b;font-weight:${isChecked ? "600" : "500"};">${opt}</span>
              </label>
            `;
            })
            .join("")}
        </div>
      `;
    }

    if (q.type === "numerical") {
      return `
        <div>
          <label style="display:block;font-size:12px;font-weight:700;color:#64748b;margin-bottom:6px;">Enter Numerical Answer:</label>
          <input type="number" id="input-numerical-ans" value="${currentAnswer !== undefined ? currentAnswer : ""}" placeholder="e.g. 42" style="background:#fff;border:1.5px solid #cbd5e1;padding:10px 14px;border-radius:8px;font-size:15px;width:240px;color:#0f172a;outline:none;" />
        </div>
      `;
    }

    if (q.type === "short_answer") {
      return `
        <div>
          <label style="display:block;font-size:12px;font-weight:700;color:#64748b;margin-bottom:6px;">Enter Short Answer (Single word/keyword):</label>
          <input type="text" id="input-short-ans" value="${currentAnswer || ""}" placeholder="Type your answer here..." style="background:#fff;border:1.5px solid #cbd5e1;padding:10px 14px;border-radius:8px;font-size:14px;width:320px;color:#0f172a;outline:none;" />
        </div>
      `;
    }

    return "";
  }

  function bindStudentLiveExamEvents(state, session, currentQIdx, currentQuestion, totalQ) {
    document.querySelectorAll(".btn-select-section").forEach((btn) => {
      btn.onclick = () => {
        const secId = btn.getAttribute("data-id");
        if (secId !== "sec-coc" && !session.cocAgreedAt) {
          session.currentSectionId = "sec-coc";
          saveState(state);
          return;
        }
        session.currentSectionId = secId;
        if (secId !== "sec-coc") {
          const firstQIdx = state.exam.questions.findIndex((q) => q.sectionId === secId);
          if (firstQIdx !== -1) session.currentQuestionIndex = firstQIdx;
        }
        saveState(state);
      };
    });

    document.querySelectorAll(".ep-q-btn").forEach((btn) => {
      btn.onclick = () => {
        if (!session.cocAgreedAt) {
          session.currentSectionId = "sec-coc";
          saveState(state);
          return;
        }
        const targetQ = parseInt(btn.getAttribute("data-q"), 10);
        session.currentQuestionIndex = targetQ;
        const qObj = state.exam.questions[targetQ];
        if (qObj) session.currentSectionId = qObj.sectionId;
        saveState(state);
      };
    });

    function grabCurrentInputAnswer() {
      if (currentQuestion.type === "mcq_single" || currentQuestion.type === "true_false") {
        const checked = document.querySelector('input[name="opt-mcq"]:checked');
        return checked ? parseInt(checked.value, 10) : undefined;
      }
      if (currentQuestion.type === "mcq_multi") {
        const checkedBoxes = Array.from(document.querySelectorAll('input[name="opt-multi"]:checked'));
        return checkedBoxes.map((cb) => parseInt(cb.value, 10));
      }
      if (currentQuestion.type === "numerical") {
        const inp = document.getElementById("input-numerical-ans");
        return inp && inp.value !== "" ? parseFloat(inp.value) : undefined;
      }
      if (currentQuestion.type === "short_answer") {
        const inp = document.getElementById("input-short-ans");
        return inp && inp.value.trim() !== "" ? inp.value.trim() : undefined;
      }
      return undefined;
    }

    const btnSaveNext = document.getElementById("btn-q-save-next");
    if (btnSaveNext) {
      btnSaveNext.onclick = () => {
        const ans = grabCurrentInputAnswer();
        if (ans !== undefined && (!Array.isArray(ans) || ans.length > 0)) {
          session.answers[currentQuestion.id] = ans;
        }
        if (currentQIdx < totalQ - 1) {
          session.currentQuestionIndex = currentQIdx + 1;
          const nextQ = state.exam.questions[currentQIdx + 1];
          if (nextQ) session.currentSectionId = nextQ.sectionId;
        }
        saveState(state);
      };
    }

    const btnPrev = document.getElementById("btn-q-prev");
    if (btnPrev && currentQIdx > 0) {
      btnPrev.onclick = () => {
        const ans = grabCurrentInputAnswer();
        if (ans !== undefined) session.answers[currentQuestion.id] = ans;
        session.currentQuestionIndex = currentQIdx - 1;
        const prevQ = state.exam.questions[currentQIdx - 1];
        if (prevQ) session.currentSectionId = prevQ.sectionId;
        saveState(state);
      };
    }

    const btnClear = document.getElementById("btn-q-clear");
    if (btnClear) {
      btnClear.onclick = () => {
        delete session.answers[currentQuestion.id];
        session.reviewFlags = session.reviewFlags.filter((id) => id !== currentQuestion.id);
        saveState(state);
      };
    }

    const btnReview = document.getElementById("btn-q-review");
    if (btnReview) {
      btnReview.onclick = () => {
        const ans = grabCurrentInputAnswer();
        if (ans !== undefined) session.answers[currentQuestion.id] = ans;
        if (!session.reviewFlags.includes(currentQuestion.id)) {
          session.reviewFlags.push(currentQuestion.id);
        } else {
          session.reviewFlags = session.reviewFlags.filter((id) => id !== currentQuestion.id);
        }
        if (currentQIdx < totalQ - 1) {
          session.currentQuestionIndex = currentQIdx + 1;
        }
        saveState(state);
      };
    }

    const btnCalc = document.getElementById("ep-btn-calc");
    if (btnCalc) {
      btnCalc.onmousedown = markInternalExamAction;
      btnCalc.onclick = () => toggleCalculator("pro");
    }

    const btnDoubts = document.getElementById("ep-btn-header-chat");
    if (btnDoubts) {
      btnDoubts.onmousedown = markInternalExamAction;
      btnDoubts.onclick = () => showDoubtsModal(state);
    }

    const btnCocContinue = document.getElementById("ep-btn-coc-continue");
    const cbCocAgree = document.getElementById("ep-coc-agree");
    if (cbCocAgree && btnCocContinue) {
      cbCocAgree.onchange = () => {
        if (!cbCocAgree.checked) return;
        const now = new Date();
        session.cocAgreedAt = now.getTime();
        session.cocAgreedAtFormatted = now.toLocaleString();
        btnCocContinue.disabled = false;
        btnCocContinue.style.background = "#059669";
        btnCocContinue.style.cursor = "pointer";
        btnCocContinue.style.boxShadow = "0 2px 8px rgba(5,150,105,0.25)";
        saveState(state);
      };
    }
    if (btnCocContinue) {
      btnCocContinue.onclick = () => {
        if (!session.cocAgreedAt) return;
        session.currentSectionId = state.exam.sections.find((s) => s.id !== "sec-coc")?.id || "sec-a";
        saveState(state);
      };
    }

    const btnSubmit = document.getElementById("btn-student-submit");
    if (btnSubmit) {
      btnSubmit.onclick = () => {
        const ansCount = Object.keys(session.answers).length;
        showStudentSubmitConfirmModal({
          answeredCount: ansCount,
          totalCount: totalQ,
          onConfirm: () => {
            session.status = "submitted";
            session.submittedAt = Date.now();
            saveState(state);
          }
        });
      };
    }
  }

  // ==========================================
  // RESULTS VIEW (Final vs General logic)
  // ==========================================
  function renderStudentResultsView(container, state, session) {
    const exam = state.exam;
    const isFinal = exam.type === "final";
    const isPublished = isFinal ? exam.resultsPublished : true;

    let score = 0;
    let totalMarks = 0;
    const breakdown = exam.questions.map((q) => {
      totalMarks += q.marks;
      const studentAns = session.answers[q.id];
      let isCorrect = false;

      if (studentAns !== undefined) {
        if (Array.isArray(q.correct)) {
          if (Array.isArray(studentAns) && JSON.stringify(studentAns.sort()) === JSON.stringify(q.correct.sort())) {
            isCorrect = true;
          }
        } else if (String(studentAns).trim().toLowerCase() === String(q.correct).trim().toLowerCase()) {
          isCorrect = true;
        }
      }

      if (isCorrect) score += q.marks;
      return { q, studentAns, isCorrect };
    });

    const percent = totalMarks > 0 ? Math.round((score / totalMarks) * 100) : 0;

    container.innerHTML = `
      <div id="ep-root" style="min-height:calc(100vh - 48px);background:#f8fafc;padding:30px 20px;color:#0f172a;display:flex;align-items:center;justify-content:center;">
        <div style="max-width:840px;margin:0 auto;">
          <div style="background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:36px 28px;box-shadow:0 18px 50px rgba(15,23,42,0.08);margin-bottom:24px;text-align:center;animation:ep-card-pop 0.28s cubic-bezier(0.16, 1, 0.3, 1);">
            <div class="ep-shield-badge" style="background:#dcfce7;margin:0 auto 18px auto;animation:ep-success-pulse 1.4s ease-in-out infinite;">
              ${I("checkCircle", 36, "#15803d")}
            </div>
            <h1 style="font-size:24px;font-weight:800;color:#0f172a;margin:0 0 6px 0;">
              Exam Submitted Successfully
            </h1>

            ${
              isFinal && !isPublished
                ? ""
                : `
                <div style="display:grid;grid-template-columns:repeat(3, 1fr);gap:14px;max-width:560px;margin:0 auto 24px auto;">
                  <div style="background:#f0fdf4;border:1.5px solid #86efac;border-radius:12px;padding:16px;">
                    <div style="font-size:28px;font-weight:900;color:#15803d;font-family:ui-monospace,monospace;">
                      ${score} / ${totalMarks}
                    </div>
                    <div style="font-size:12px;color:#166534;font-weight:700;">Score Achieved</div>
                  </div>
                  <div style="background:#eff6ff;border:1.5px solid #bfdbfe;border-radius:12px;padding:16px;">
                    <div style="font-size:28px;font-weight:900;color:#1d4ed8;font-family:ui-monospace,monospace;">
                      ${percent}%
                    </div>
                    <div style="font-size:12px;color:#1e40af;font-weight:700;">Percentage</div>
                  </div>
                  <div style="background:#faf5ff;border:1.5px solid #e9d5ff;border-radius:12px;padding:16px;">
                    <div style="font-size:28px;font-weight:900;color:#7e22ce;font-family:ui-monospace,monospace;">
                      ${Object.keys(session.answers).length} / ${exam.questions.length}
                    </div>
                    <div style="font-size:12px;color:#6b21a8;font-weight:700;">Answered</div>
                  </div>
                </div>
              `
            }

            <button id="ep-btn-retest" style="background:#0f172a;color:#fff;border:none;padding:10px 20px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;">
              Retest Exam Attempt
            </button>
          </div>

          ${
            isPublished
              ? `
              <div style="background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:24px;box-shadow:0 4px 20px rgba(0,0,0,0.05);">
                <div style="font-size:18px;font-weight:800;color:#0f172a;margin-bottom:6px;display:flex;align-items:center;gap:8px;">
                  ${I("fileText", 18, "#059669")} Question-by-Question Answer Breakdown
                </div>
                <p style="font-size:13px;color:#64748b;margin-bottom:20px;">
                  Review which questions were correct, where marks were lost, and read faculty explanations:
                </p>

                <div style="display:flex;flex-direction:column;gap:16px;">
                  ${breakdown
                    .map(({ q, studentAns, isCorrect }, idx) => {
                      const displayAns =
                        studentAns === undefined
                          ? "<i>(Not attempted)</i>"
                          : Array.isArray(studentAns)
                          ? studentAns.map((i) => q.options[i]).join(", ")
                          : q.options && q.options[studentAns] !== undefined
                          ? q.options[studentAns]
                          : String(studentAns);

                      const displayCorrect = Array.isArray(q.correct)
                        ? q.correct.map((i) => q.options[i]).join(", ")
                        : q.options && q.options[q.correct] !== undefined
                        ? q.options[q.correct]
                        : String(q.correct);

                      return `
                      <div style="border:1.5px solid ${isCorrect ? "#86efac" : studentAns === undefined ? "#e2e8f0" : "#fecaca"};background:${isCorrect ? "#f0fdf4" : studentAns === undefined ? "#f8fafc" : "#fff1f2"};border-radius:12px;padding:18px;">
                        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                          <span style="font-weight:800;font-size:13px;color:#0f172a;">
                            Question ${idx + 1}
                          </span>
                          <span style="font-size:12px;font-weight:800;padding:2px 8px;border-radius:6px;background:${isCorrect ? "#dcfce7" : "#fee2e2"};color:${isCorrect ? "#15803d" : "#b91c1c"};">
                            ${isCorrect ? `+${q.marks} Marks` : `0 Marks`}
                          </span>
                        </div>

                        <div style="font-size:14px;color:#1e293b;margin-bottom:10px;font-weight:600;">
                          ${q.prompt}
                        </div>

                        ${q.code ? `<pre style="background:#0f172a;color:#a7f3d0;padding:10px;border-radius:6px;font-size:12px;margin:8px 0;"><code>${q.code}</code></pre>` : ""}

                        <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;font-size:12.5px;margin-top:12px;">
                          <div style="background:#ffffff;border:1px solid #e2e8f0;padding:10px;border-radius:8px;">
                            <div style="color:#64748b;font-weight:700;font-size:11px;text-transform:uppercase;">Your Answer:</div>
                            <div style="color:${isCorrect ? "#15803d" : "#b91c1c"};font-weight:700;margin-top:2px;">
                              ${displayAns}
                            </div>
                          </div>
                          <div style="background:#ffffff;border:1px solid #e2e8f0;padding:10px;border-radius:8px;">
                            <div style="color:#64748b;font-weight:700;font-size:11px;text-transform:uppercase;">Correct Answer:</div>
                            <div style="color:#15803d;font-weight:700;margin-top:2px;">
                              ${displayCorrect}
                            </div>
                          </div>
                        </div>

                        ${
                          q.explanation
                            ? `<div style="margin-top:10px;font-size:12px;color:#475569;background:rgba(255,255,255,0.7);padding:8px 10px;border-radius:6px;">
                                 <b>Explanation:</b> ${q.explanation}
                               </div>`
                            : ""
                        }
                      </div>
                    `;
                    })
                    .join("")}
                </div>
              </div>
            `
              : ""
          }
        </div>
      </div>
    `;

    document.getElementById("ep-btn-retest").onclick = () => {
      session.status = "not_started";
      session.answers = {};
      session.reviewFlags = [];
      session.warnings = 0;
      session.warningLogs = [];
      session.outsideExamSeconds = 0;
      session.outsideSince = null;
      session.outsideReason = null;
      session.cocAgreedAt = null;
      session.cocAgreedAtFormatted = null;
      session.onboardingStep = 0;
      session.attendanceRecordedAt = null;
      session.photoDataUrl = null;
      state.activeOnboardingModal = null;
      saveState(state);
    };
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", render);
  } else {
    render();
  }
})();
