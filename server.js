#!/usr/bin/env node
/**
 * GenZ IITian Examination Platform - Node.js Backend Server
 * Native Node.js HTTP Server with Zero External Dependencies
 */

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = parseInt(process.argv[2] || process.env.PORT || 3000, 10);
const DIRECTORY = __dirname;
const DATA_DIR = path.join(DIRECTORY, "data");
const STATE_FILE = path.join(DATA_DIR, "exam_state.json");

function getDefaultState() {
  return {
    activeView: "login",
    studentActiveTab: "scheduled_exams",
    activeOnboardingModal: null,
    currentUser: {
      id: "manager",
      name: "Exam Manager",
      email: "",
      role: "manager"
    },
    exam: {
      id: "iitm-python-endterm",
      title: "QUIZ- LAB — Python & Computational Thinking Endterm",
      subject: "Python Programming & Data Structures",
      type: "final",
      status: "live",
      resultsPublished: false,
      durationMinutes: 60,
      extendedMinutes: 0,
      startedAt: Date.now() - 15 * 60 * 1000,
      instructions: "No outside aids permitted. Exiting the exam window requires manager approval to re-enter.",
      chatEnabled: true,
      allowedEmails: [
        "",
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
      "": {
        email: "",
        name: "Candidate",
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
}

function loadState() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (fs.existsSync(STATE_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
    } catch (e) {
      console.warn(`[Node Server] Error loading ${STATE_FILE}:`, e.message);
    }
  }
  const defaultState = getDefaultState();
  saveState(defaultState);
  return defaultState;
}

function saveState(state) {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  const tmp = `${STATE_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state, null, 2), "utf8");
  fs.renameSync(tmp, STATE_FILE);
}

let currentState = loadState();

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
  ".ttf": "font/ttf",
  ".woff": "font/woff",
  ".woff2": "font/woff2"
};

function sendJson(res, statusCode, data) {
  const body = Buffer.from(JSON.stringify(data), "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": body.length,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, DELETE",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Cache-Control": "no-cache, no-store, must-revalidate"
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const urlParts = req.url.split("?");
  const cleanPath = urlParts[0];

  // Global CORS Headers
  if (req.method === "OPTIONS") {
    res.writeHead(200, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, DELETE",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Content-Length": "0"
    });
    return res.end();
  }

  // REST API Routes
  if (req.method === "GET") {
    if (cleanPath === "/api/health") {
      return sendJson(res, 200, { status: "ok", service: "genzexam-node", time: Date.now() });
    }
    if (cleanPath === "/api/state") {
      return sendJson(res, 200, currentState);
    }
    if (cleanPath === "/api/exam") {
      return sendJson(res, 200, currentState.exam || {});
    }
    if (cleanPath === "/api/chat") {
      return sendJson(res, 200, currentState.chatMessages || []);
    }
    if (cleanPath === "/api/reentry") {
      return sendJson(res, 200, currentState.reentryRequests || []);
    }
    if (cleanPath === "/api/students") {
      return sendJson(res, 200, currentState.studentSessions || {});
    }
  }

  if (req.method === "POST") {
    let body = [];
    req.on("data", (chunk) => body.push(chunk));
    req.on("end", () => {
      let payload = {};
      try {
        const raw = Buffer.concat(body).toString("utf8");
        payload = raw ? JSON.parse(raw) : {};
      } catch (err) {
        return sendJson(res, 400, { error: "Invalid JSON body" });
      }

      if (cleanPath === "/api/state") {
        if (payload && typeof payload === "object") {
          if (payload.exam) Object.assign(currentState.exam, payload.exam);
          if (payload.studentSessions) Object.assign(currentState.studentSessions, payload.studentSessions);
          if (Array.isArray(payload.chatMessages)) currentState.chatMessages = payload.chatMessages;
          if (Array.isArray(payload.reentryRequests)) currentState.reentryRequests = payload.reentryRequests;
          if (payload.activeView) currentState.activeView = payload.activeView;
          if (payload.studentActiveTab) currentState.studentActiveTab = payload.studentActiveTab;
          saveState(currentState);
        }
        return sendJson(res, 200, { success: true, state: currentState });
      }

      if (cleanPath === "/api/reset") {
        currentState = getDefaultState();
        saveState(currentState);
        return sendJson(res, 200, { success: true, state: currentState });
      }

      if (cleanPath === "/api/chat") {
        const msg = payload.message;
        if (msg) {
          if (!msg.id) msg.id = `msg-${Date.now()}`;
          if (!msg.timestamp) msg.timestamp = Date.now();
          currentState.chatMessages = currentState.chatMessages || [];
          currentState.chatMessages.push(msg);
          saveState(currentState);
          return sendJson(res, 200, { success: true, message: msg });
        }
        return sendJson(res, 400, { error: "Missing message" });
      }

      if (cleanPath === "/api/action") {
        const action = payload.action;
        const exam = currentState.exam || {};

        if (action === "start_exam") {
          exam.status = "live";
          exam.startedAt = Date.now();
        } else if (action === "pause_exam") {
          exam.status = "paused";
        } else if (action === "resume_exam") {
          exam.status = "live";
        } else if (action === "end_exam") {
          exam.status = "ended";
          for (const s of Object.values(currentState.studentSessions || {})) {
            if (s.status === "in_progress" || s.status === "not_started") {
              s.status = "submitted";
              s.submittedAt = Date.now();
            }
          }
        } else if (action === "extend_time") {
          exam.extendedMinutes = (exam.extendedMinutes || 0) + (payload.minutes || 5);
        } else if (action === "toggle_type") {
          exam.type = payload.type || "final";
        } else if (action === "publish_results") {
          exam.resultsPublished = payload.resultsPublished !== false;
        } else if (action === "add_whitelist") {
          if (payload.email && !exam.allowedEmails.includes(payload.email)) {
            exam.allowedEmails.push(payload.email);
          }
        } else if (action === "remove_whitelist") {
          exam.allowedEmails = exam.allowedEmails.filter((e) => e !== payload.email);
        } else if (action === "sync_student_session") {
          if (payload.email) {
            currentState.studentSessions[payload.email] = {
              ...(currentState.studentSessions[payload.email] || {}),
              ...(payload.updates || {}),
              lastActive: Date.now()
            };
          }
        } else if (action === "request_reentry") {
          if (payload.request) currentState.reentryRequests.push(payload.request);
        } else if (action === "approve_reentry") {
          for (const r of currentState.reentryRequests || []) {
            if (r.id === payload.requestId) r.status = "approved";
          }
          if (payload.email && currentState.studentSessions[payload.email]) {
            currentState.studentSessions[payload.email].status = "in_progress";
          }
        } else if (action === "reject_reentry") {
          for (const r of currentState.reentryRequests || []) {
            if (r.id === payload.requestId) r.status = "rejected";
          }
        } else if (action === "lock_session") {
          if (payload.email && currentState.studentSessions[payload.email]) {
            currentState.studentSessions[payload.email].status = "reentry_required";
          }
        } else {
          return sendJson(res, 400, { error: `Unknown action: ${action}` });
        }

        saveState(currentState);
        return sendJson(res, 200, { success: true, action, state: currentState });
      }

      return sendJson(res, 404, { error: "API route not found" });
    });
    return;
  }

  // Static File Serving & SPA Fallback
  let filePath = path.join(DIRECTORY, cleanPath);
  if (cleanPath === "/") {
    filePath = path.join(DIRECTORY, "landing.html");
  } else if (cleanPath === "/papers" || cleanPath === "/papers/") {
    filePath = path.join(DIRECTORY, "papers.html");
  } else if (cleanPath === "/paper-pricing" || cleanPath === "/paper-pricing/") {
    filePath = path.join(DIRECTORY, "paper-pricing.html");
  } else if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(DIRECTORY, "index.html");
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      filePath = path.join(DIRECTORY, "index.html");
    }
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || "application/octet-stream";

    fs.readFile(filePath, (readErr, content) => {
      if (readErr) {
        res.writeHead(500, { "Content-Type": "text/plain" });
        return res.end("500 Internal Server Error");
      }
      res.writeHead(200, {
        "Content-Type": contentType,
        "Content-Length": content.length,
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        "Expires": "0",
        "Access-Control-Allow-Origin": "*"
      });
      res.end(content);
    });
  });
});

server.listen(PORT, () => {
  console.log(`============================================================`);
  console.log(`   GenZ IITian Examination Platform (Node Engine)           `);
  console.log(`   Listening at http://localhost:${PORT}                    `);
  console.log(`   API Endpoints: /api/state, /api/action, /api/chat        `);
  console.log(`============================================================`);
});
