#!/usr/bin/env python3
"""
GenZ IITian Examination Platform Backend Server
Unified SPA Static Server & RESTful Exam State Management Engine
Zero External Dependencies (Python 3 Standard Library)
"""

import http.server
import socketserver
import os
import sys
import json
import time
import threading

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(DIRECTORY, "data")
STATE_FILE = os.path.join(DATA_DIR, "exam_state.json")

# Thread safety lock for state operations
state_lock = threading.Lock()

def get_default_state():
    return {
        "activeView": "login",
        "studentActiveTab": "scheduled_exams",
        "activeOnboardingModal": None,
        "currentUser": {
            "id": "manager",
            "name": "Exam Manager",
            "email": "",
            "role": "manager"
        },
        "exam": {
            "id": "iitm-python-endterm",
            "title": "GenZ IITian — Python & Computational Thinking Endterm",
            "subject": "Python Programming & Data Structures",
            "type": "final",
            "status": "live",
            "resultsPublished": False,
            "durationMinutes": 60,
            "extendedMinutes": 0,
            "startedAt": int(time.time() * 1000) - (15 * 60 * 1000),
            "instructions": "No outside aids permitted. Exiting the exam window requires manager approval to re-enter.",
            "chatEnabled": True,
            "allowedEmails": [
                "",
                "tushar@iitm.ac.in"
            ] + [f"student{i}@iitm.ac.in" for i in range(1, 51)],
            "sections": [
                {"id": "sec-coc", "title": "Code of Conduct (COC)", "isCoc": True},
                {"id": "sec-a", "title": "Section A: Core Concepts", "marksEach": 2, "negativeEach": 0.5},
                {"id": "sec-b", "title": "Section B: Algorithmic Logic & Output", "marksEach": 3, "negativeEach": 1.0}
            ],
            "questions": [
                {
                    "id": "q1",
                    "sectionId": "sec-a",
                    "type": "mcq_single",
                    "marks": 2,
                    "negative": 0.5,
                    "prompt": "What is the output of the following Python slice operation on a list?",
                    "code": "x = [1, 2, 3, 4, 5]\nprint(x[::-1])",
                    "options": ["[1, 2, 3, 4, 5]", "[5, 4, 3, 2, 1]", "(5, 4, 3, 2, 1)", "SyntaxError"],
                    "correct": 1,
                    "explanation": "Slice x[::-1] steps backward through list x from end to start, reversing it to [5, 4, 3, 2, 1]."
                },
                {
                    "id": "q2",
                    "sectionId": "sec-a",
                    "type": "mcq_multi",
                    "marks": 2,
                    "negative": 0.5,
                    "prompt": "Which of the following statements correctly create a Python dictionary? (Select all that apply)",
                    "code": None,
                    "options": [
                        "d = {'roll': 101, 'name': 'Aditi'}",
                        "d = dict(roll=101, name='Aditi')",
                        "d = { ('id', 1): 'admin' }",
                        "d = { ['id']: 'admin' }"
                    ],
                    "correct": [0, 1, 2],
                    "explanation": "Tuples are immutable and hashable, so ('id', 1) is a valid dict key. Lists are mutable and cannot be dict keys."
                },
                {
                    "id": "q3",
                    "sectionId": "sec-a",
                    "type": "true_false",
                    "marks": 2,
                    "negative": 0.5,
                    "prompt": "In Python, a standard dictionary preserves insertion order of keys starting from Python 3.7+.",
                    "code": None,
                    "options": ["True", "False"],
                    "correct": 0,
                    "explanation": "Starting in Python 3.7, dict insertion order is an official part of the Python language specification."
                },
                {
                    "id": "q4",
                    "sectionId": "sec-a",
                    "type": "numerical",
                    "marks": 2,
                    "negative": 0,
                    "prompt": "What is the returned integer value of the following set length expression?",
                    "code": "len(set([10, 20, 20, 30, 10, 40, 50]))",
                    "correct": 5,
                    "explanation": "Unique values in [10, 20, 20, 30, 10, 40, 50] are {10, 20, 30, 40, 50}, which has 5 elements."
                },
                {
                    "id": "q5",
                    "sectionId": "sec-b",
                    "type": "mcq_single",
                    "marks": 3,
                    "negative": 1.0,
                    "prompt": "What is the worst-case time complexity of searching in a balanced Binary Search Tree (AVL tree) of N nodes?",
                    "code": None,
                    "options": ["O(1)", "O(log N)", "O(N)", "O(N log N)"],
                    "correct": 1,
                    "explanation": "Balanced BSTs (AVL / Red-Black) maintain height of O(log N), so search is guaranteed O(log N) in worst case."
                },
                {
                    "id": "q6",
                    "sectionId": "sec-b",
                    "type": "short_answer",
                    "marks": 3,
                    "negative": 0,
                    "prompt": "What keyword is used in Python inside an inner function to modify a variable defined in the enclosing (non-global) scope?",
                    "code": None,
                    "correct": "nonlocal",
                    "explanation": "The 'nonlocal' keyword binds an inner function variable to its closest enclosing non-global scope."
                },
                {
                    "id": "q7",
                    "sectionId": "sec-b",
                    "type": "mcq_single",
                    "marks": 3,
                    "negative": 1.0,
                    "prompt": "What will be printed when running this generator function?",
                    "code": "def gen():\n    yield 1\n    yield 2\n\ng = gen()\nnext(g)\nprint(next(g))",
                    "options": ["1", "2", "StopIteration", "None"],
                    "correct": 1,
                    "explanation": "First next(g) yields 1. Second next(g) yields 2 and print() outputs 2."
                },
                {
                    "id": "q8",
                    "sectionId": "sec-b",
                    "type": "numerical",
                    "marks": 3,
                    "negative": 0,
                    "prompt": "Calculate the exact output value of the arithmetic precedence expression:",
                    "code": "res = 2 ** 3 * 2 + 10 // 3\nprint(res)",
                    "correct": 19,
                    "explanation": "2**3 = 8; 8*2 = 16; 10//3 = 3; 16 + 3 = 19."
                }
            ]
        },
        "reentryRequests": [],
        "studentSessions": {
            "": {
                "email": "",
                "name": "Candidate",
                "studentId": "22F3001840",
                "status": "not_started",
                "onboardingStep": 0,
                "attendanceRecordedAt": None,
                "attendanceTimestamp": None,
                "photoDataUrl": None,
                "warnings": 0,
                "warningLogs": [],
                "outsideExamSeconds": 0,
                "outsideSince": None,
                "outsideReason": None,
                "cocAgreedAt": None,
                "cocAgreedAtFormatted": None,
                "currentQuestionIndex": 0,
                "currentSectionId": "sec-a",
                "answers": {},
                "reviewFlags": [],
                "startedAt": None,
                "lastActive": int(time.time() * 1000)
            }
        },
        "chatMessages": [
            {
                "id": "msg-1",
                "senderName": "Exam Manager",
                "role": "manager",
                "text": "Welcome students. Ensure your internet connection is stable. Leaving the window triggers re-entry lock.",
                "timestamp": int(time.time() * 1000) - (14 * 60 * 1000),
                "isAnnouncement": True
            }
        ]
    }

def load_persisted_state():
    os.makedirs(DATA_DIR, exist_ok=True)
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[Backend Warning] Could not parse {STATE_FILE}: {e}. Initializing default state.")
    state = get_default_state()
    save_persisted_state(state)
    return state

def save_persisted_state(state):
    os.makedirs(DATA_DIR, exist_ok=True)
    tmp_file = STATE_FILE + ".tmp"
    with open(tmp_file, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp_file, STATE_FILE)

# In-memory shared state
current_state = load_persisted_state()

class ExamPlatformHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Enable CORS and disable aggressive caching for seamless API and SPA updates
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def send_json(self, status_code, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _fallback_if_needed(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or (os.path.isdir(path) and not os.path.exists(os.path.join(path, "index.html"))):
            self.path = "/index.html"

    def do_GET(self):
        clean_path = self.path.split("?")[0]

        # REST API Routes
        if clean_path == "/api/health":
            return self.send_json(200, {"status": "ok", "service": "genzexam-backend", "time": time.time()})

        if clean_path == "/api/state":
            with state_lock:
                return self.send_json(200, current_state)

        if clean_path == "/api/exam":
            with state_lock:
                return self.send_json(200, current_state.get("exam", {}))

        if clean_path == "/api/chat":
            with state_lock:
                return self.send_json(200, current_state.get("chatMessages", []))

        if clean_path == "/api/reentry":
            with state_lock:
                return self.send_json(200, current_state.get("reentryRequests", []))

        if clean_path == "/api/students":
            with state_lock:
                return self.send_json(200, current_state.get("studentSessions", {}))

        # Static file serving & SPA routing
        self._fallback_if_needed()
        return super().do_GET()

    def do_HEAD(self):
        clean_path = self.path.split("?")[0]
        if clean_path.startswith("/api/"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            return

        self._fallback_if_needed()
        return super().do_HEAD()

    def do_POST(self):
        clean_path = self.path.split("?")[0]

        # Read JSON body
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b"{}"
        try:
            payload = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            return self.send_json(400, {"error": "Invalid JSON format in request body"})

        global current_state

        # 1. Full or merged state synchronization
        if clean_path == "/api/state":
            with state_lock:
                if isinstance(payload, dict):
                    # Smart merge
                    if "exam" in payload and isinstance(payload["exam"], dict):
                        current_state.setdefault("exam", {}).update(payload["exam"])
                    if "studentSessions" in payload and isinstance(payload["studentSessions"], dict):
                        current_state.setdefault("studentSessions", {}).update(payload["studentSessions"])
                    if "chatMessages" in payload and isinstance(payload["chatMessages"], list):
                        current_state["chatMessages"] = payload["chatMessages"]
                    if "reentryRequests" in payload and isinstance(payload["reentryRequests"], list):
                        current_state["reentryRequests"] = payload["reentryRequests"]
                    if "activeView" in payload:
                        current_state["activeView"] = payload["activeView"]
                    if "studentActiveTab" in payload:
                        current_state["studentActiveTab"] = payload["studentActiveTab"]

                    save_persisted_state(current_state)
                return self.send_json(200, {"success": True, "state": current_state})

        # 2. Reset examination state
        if clean_path == "/api/reset":
            with state_lock:
                current_state = get_default_state()
                save_persisted_state(current_state)
                return self.send_json(200, {"success": True, "state": current_state})

        # 3. Dedicated Chat message broadcast
        if clean_path == "/api/chat":
            with state_lock:
                msg = payload.get("message")
                if msg:
                    if "id" not in msg:
                        msg["id"] = f"msg-{int(time.time()*1000)}"
                    if "timestamp" not in msg:
                        msg["timestamp"] = int(time.time() * 1000)
                    current_state.setdefault("chatMessages", []).append(msg)
                    save_persisted_state(current_state)
                    return self.send_json(200, {"success": True, "message": msg})
                return self.send_json(400, {"error": "Missing message object"})

        # 4. Atomic Action Dispatcher (Manager Controls & Student Submissions)
        if clean_path == "/api/action":
            action = payload.get("action")
            with state_lock:
                exam = current_state.setdefault("exam", {})

                if action == "start_exam":
                    exam["status"] = "live"
                    exam["startedAt"] = int(time.time() * 1000)

                elif action == "pause_exam":
                    exam["status"] = "paused"

                elif action == "resume_exam":
                    exam["status"] = "live"

                elif action == "end_exam":
                    exam["status"] = "ended"
                    # Mark active students as submitted
                    for s in current_state.get("studentSessions", {}).values():
                        if s.get("status") in ("in_progress", "not_started"):
                            s["status"] = "submitted"
                            s["submittedAt"] = int(time.time() * 1000)

                elif action == "extend_time":
                    mins = payload.get("minutes", 5)
                    exam["extendedMinutes"] = exam.get("extendedMinutes", 0) + mins

                elif action == "toggle_type":
                    exam["type"] = payload.get("type", "final")

                elif action == "publish_results":
                    exam["resultsPublished"] = payload.get("resultsPublished", True)

                elif action == "add_whitelist":
                    email = payload.get("email")
                    if email and email not in exam.setdefault("allowedEmails", []):
                        exam["allowedEmails"].append(email)

                elif action == "remove_whitelist":
                    email = payload.get("email")
                    if email and email in exam.setdefault("allowedEmails", []):
                        exam["allowedEmails"].remove(email)

                elif action == "sync_student_session":
                    email = payload.get("email")
                    updates = payload.get("updates", {})
                    if email:
                        sess = current_state.setdefault("studentSessions", {}).setdefault(email, {})
                        sess.update(updates)
                        sess["lastActive"] = int(time.time() * 1000)

                elif action == "request_reentry":
                    req = payload.get("request")
                    if req:
                        current_state.setdefault("reentryRequests", []).append(req)

                elif action == "approve_reentry":
                    req_id = payload.get("requestId")
                    email = payload.get("email")
                    for r in current_state.get("reentryRequests", []):
                        if r.get("id") == req_id:
                            r["status"] = "approved"
                    if email and email in current_state.get("studentSessions", {}):
                        current_state["studentSessions"][email]["status"] = "in_progress"

                elif action == "reject_reentry":
                    req_id = payload.get("requestId")
                    for r in current_state.get("reentryRequests", []):
                        if r.get("id") == req_id:
                            r["status"] = "rejected"

                elif action == "lock_session":
                    email = payload.get("email")
                    if email and email in current_state.get("studentSessions", {}):
                        current_state["studentSessions"][email]["status"] = "reentry_required"

                else:
                    return self.send_json(400, {"error": f"Unknown action: {action}"})

                save_persisted_state(current_state)
                return self.send_json(200, {"success": True, "action": action, "state": current_state})

        return self.send_json(404, {"error": "API route not found"})

if __name__ == "__main__":
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("", PORT), ExamPlatformHandler) as httpd:
        print(f"============================================================")
        print(f"   GenZ IITian Examination Platform Backend Running         ")
        print(f"   URL: http://localhost:{PORT}                             ")
        print(f"   API Endpoints: /api/state, /api/action, /api/chat        ")
        print(f"============================================================")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
