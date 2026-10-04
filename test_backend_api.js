/**
 * Comprehensive Automated Verification Suite for GenZ Exam Backend API
 * Tests REST Endpoints, State Management, Atomic Actions, and Real-Time Sync
 */

const http = require("http");
const assert = require("assert");

const BASE_URL = "http://localhost:3000";

function request(options, data = null) {
  return new Promise((resolve, reject) => {
    options.headers = options.headers || {};
    let payloadStr = null;
    if (data) {
      payloadStr = typeof data === "string" ? data : JSON.stringify(data);
      options.headers["Content-Length"] = Buffer.byteLength(payloadStr);
    }
    const req = http.request(options, (res) => {
      let body = [];
      res.on("data", (chunk) => body.push(chunk));
      res.on("end", () => {
        const text = Buffer.concat(body).toString("utf8");
        let json = null;
        try {
          json = JSON.parse(text);
        } catch (e) {
          json = text;
        }
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: json
        });
      });
    });
    req.on("error", (err) => reject(err));
    if (payloadStr) {
      req.write(payloadStr);
    }
    req.end();
  });
}

async function runBackendTests() {
  console.log("==============================================================");
  console.log("       GENZ EXAM BACKEND REST API AUTOMATED TEST SUITE        ");
  console.log("==============================================================\n");

  // 1. Health check
  console.log("[1/6] Testing GET /api/health...");
  const healthRes = await request({
    hostname: "localhost",
    port: 3000,
    path: "/api/health",
    method: "GET"
  });
  assert.strictEqual(healthRes.statusCode, 200, "Health endpoint must return 200");
  assert.strictEqual(healthRes.data.status, "ok", "Status must be ok");
  console.log("  ✓ GET /api/health returned 200 OK\n");

  // 2. State fetch
  console.log("[2/6] Testing GET /api/state...");
  const stateRes = await request({
    hostname: "localhost",
    port: 3000,
    path: "/api/state",
    method: "GET"
  });
  assert.strictEqual(stateRes.statusCode, 200, "State endpoint must return 200");
  assert.ok(stateRes.data.exam, "State must contain exam object");
  assert.ok(Array.isArray(stateRes.data.exam.questions), "State must contain questions array");
  assert.strictEqual(stateRes.data.exam.questions.length, 8, "Default exam must have 8 questions");
  console.log("  ✓ GET /api/state verified with 8 default questions\n");

  // 3. State update
  console.log("[3/6] Testing POST /api/state (Sync)...");
  const updatePayload = {
    exam: {
      instructions: "Updated instructions via automated backend test."
    }
  };
  const updateRes = await request(
    {
      hostname: "localhost",
      port: 3000,
      path: "/api/state",
      method: "POST",
      headers: { "Content-Type": "application/json" }
    },
    updatePayload
  );
  assert.strictEqual(updateRes.statusCode, 200, "POST /api/state must return 200");
  assert.strictEqual(
    updateRes.data.state.exam.instructions,
    "Updated instructions via automated backend test.",
    "Exam instructions must be updated"
  );
  console.log("  ✓ POST /api/state synchronized state successfully\n");

  // 4. Action Dispatcher
  console.log("[4/6] Testing POST /api/action...");
  // 4.1 Extend Time Action
  const extRes = await request(
    {
      hostname: "localhost",
      port: 3000,
      path: "/api/action",
      method: "POST",
      headers: { "Content-Type": "application/json" }
    },
    { action: "extend_time", minutes: 10 }
  );
  assert.strictEqual(extRes.statusCode, 200);
  assert.strictEqual(extRes.data.state.exam.extendedMinutes >= 10, true, "Exam time extended");

  // 4.2 Student session sync
  const studentEmail = "test_student@iitm.ac.in";
  const syncStudentRes = await request(
    {
      hostname: "localhost",
      port: 3000,
      path: "/api/action",
      method: "POST",
      headers: { "Content-Type": "application/json" }
    },
    {
      action: "sync_student_session",
      email: studentEmail,
      updates: {
        status: "in_progress",
        answers: { q1: 1, q4: 5 },
        warnings: 1
      }
    }
  );
  assert.strictEqual(syncStudentRes.statusCode, 200);
  assert.ok(syncStudentRes.data.state.studentSessions[studentEmail]);
  assert.strictEqual(syncStudentRes.data.state.studentSessions[studentEmail].answers.q1, 1);
  assert.strictEqual(syncStudentRes.data.state.studentSessions[studentEmail].warnings, 1);
  console.log("  ✓ POST /api/action handled extend_time and sync_student_session successfully\n");

  // 5. Chat message broadcast
  console.log("[5/6] Testing POST /api/chat & GET /api/chat...");
  const chatPayload = {
    message: {
      id: "msg-test-1",
      senderName: "Proctor Admin",
      role: "manager",
      text: "Proctor announcement test message.",
      isAnnouncement: true
    }
  };
  const chatPostRes = await request(
    {
      hostname: "localhost",
      port: 3000,
      path: "/api/chat",
      method: "POST",
      headers: { "Content-Type": "application/json" }
    },
    chatPayload
  );
  assert.strictEqual(chatPostRes.statusCode, 200);

  const chatGetRes = await request({
    hostname: "localhost",
    port: 3000,
    path: "/api/chat",
    method: "GET"
  });
  assert.strictEqual(chatGetRes.statusCode, 200);
  assert.ok(
    chatGetRes.data.some((m) => m.text === "Proctor announcement test message."),
    "Sent message must appear in chatMessages"
  );
  console.log("  ✓ Chat broadcasting and retrieval verified\n");

  // 6. Reset state
  console.log("[6/6] Testing POST /api/reset...");
  const resetRes = await request({
    hostname: "localhost",
    port: 3000,
    path: "/api/reset",
    method: "POST"
  });
  assert.strictEqual(resetRes.statusCode, 200);
  assert.strictEqual(resetRes.data.state.exam.extendedMinutes, 0, "Extended minutes reset to 0");
  console.log("  ✓ Platform state reset to pristine default\n");

  console.log("==============================================================");
  console.log("       ALL BACKEND API TESTS PASSED SUCCESSFULLY (100%)       ");
  console.log("==============================================================");
}

runBackendTests().catch((err) => {
  console.error("Backend test failed:", err);
  process.exit(1);
});
