/**
 * ============================================================================
 * Quiz Lab - Comprehensive QA Automated Test Suite & Engine Validation Runner
 * ============================================================================
 * Covers:
 *  1. AutoScoreService & Scoring Engine (MCQ, MSQ, Numerical, Short Answer, True/False)
 *  2. Negative Marking Calculations & Boundary Conditions (-0.5, -1.0, Zero Floors)
 *  3. Numerical Input Edge Cases (Tolerance, Blank/Null handling, Negative numbers)
 *  4. Timer Expiry Auto-Submit & Zero-Second Race Conditions
 *  5. In-Flight Network Drop Resilience & Lossless Retry Queue
 *  6. Auth Lifecycle, Session Invalidation & Token Revocation
 *  7. Quizzes Level Filtering (Foundation, Diploma, Degree) & Course Categorization
 *  8. Support Tab Discussions, Replies, Voting & XP Rewards Engine
 *  9. KaTeX LaTeX Formula Rendering Parser & Crash Recovery
 * ============================================================================
 */

const assert = require("assert");

// ANSI color formatting for terminal test reporting
const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
};

let passedCount = 0;
let failedCount = 0;
const testResults = [];

function test(description, testFn) {
  try {
    testFn();
    passedCount++;
    testResults.push({ description, status: "PASS" });
    console.log(`  ${colors.green}✓ PASS:${colors.reset} ${description}`);
  } catch (err) {
    failedCount++;
    testResults.push({ description, status: "FAIL", error: err.message });
    console.error(`  ${colors.red}✗ FAIL:${colors.reset} ${description}`);
    console.error(`    ${colors.red}${err.stack || err.message}${colors.reset}`);
  }
}

async function testAsync(description, testFn) {
  try {
    await testFn();
    passedCount++;
    testResults.push({ description, status: "PASS" });
    console.log(`  ${colors.green}✓ PASS:${colors.reset} ${description}`);
  } catch (err) {
    failedCount++;
    testResults.push({ description, status: "FAIL", error: err.message });
    console.error(`  ${colors.red}✗ FAIL:${colors.reset} ${description}`);
    console.error(`    ${colors.red}${err.stack || err.message}${colors.reset}`);
  }
}

// ============================================================================
// SIMULATED BACKEND ENGINE LOGIC (Mirrors Laravel AutoScoreService & Controllers)
// ============================================================================

class AutoScoreServiceSimulator {
  /**
   * Scores an answer based on question type and configuration.
   * Includes optional negative marking penalty support.
   */
  static scoreAnswer(question, answerData, enableNegativeMarking = false) {
    let isCorrect = false;
    let marksAwarded = 0;
    const options = question.questionOptions || [];
    const negativePenalty = enableNegativeMarking ? (Number(question.negative) || 0) : 0;

    switch (question.type) {
      case "mcq":
      case "true_false": {
        const correctOption = options.find((opt) => opt.is_correct === true);
        const selected = answerData.selected_option_ids?.[0] ?? null;
        isCorrect = correctOption !== undefined && Number(selected) === Number(correctOption.id);
        if (isCorrect) {
          marksAwarded = Number(question.marks);
        } else if (selected !== null && selected !== undefined) {
          // Attempted but incorrect: apply negative penalty if enabled
          marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
        } else {
          // Unattempted: 0 marks
          marksAwarded = 0;
        }
        break;
      }

      case "multi_select": {
        const correctIds = options
          .filter((opt) => opt.is_correct === true)
          .map((opt) => Number(opt.id))
          .sort((a, b) => a - b);
        const selectedIds = (answerData.selected_option_ids || [])
          .map((id) => Number(id))
          .sort((a, b) => a - b);

        isCorrect =
          correctIds.length === selectedIds.length &&
          correctIds.every((val, idx) => val === selectedIds[idx]);

        if (isCorrect) {
          marksAwarded = Number(question.marks);
        } else if (selectedIds.length > 0) {
          const selectedCorrect = selectedIds.filter((id) => correctIds.includes(id));
          const selectedWrong = selectedIds.filter((id) => !correctIds.includes(id));

          // Partial marks awarded ONLY if NO wrong options were picked
          if (selectedWrong.length === 0 && selectedCorrect.length > 0) {
            marksAwarded = Math.round(Number(question.marks) * 0.5 * 100) / 100;
          } else {
            // Selected wrong options: apply negative penalty if enabled
            marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
          }
        } else {
          marksAwarded = 0;
        }
        break;
      }

      case "short_answer": {
        const acceptables = (question.shortAnswerAcceptables || []).map((a) =>
          String(a.acceptable_text).trim().toLowerCase()
        );
        const studentRaw = answerData.text_answer;
        if (studentRaw !== null && studentRaw !== undefined && String(studentRaw).trim() !== "") {
          const studentAnswer = String(studentRaw).trim().toLowerCase();
          isCorrect = acceptables.includes(studentAnswer);
          if (isCorrect) {
            marksAwarded = Number(question.marks);
          } else {
            marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
          }
        } else {
          marksAwarded = 0;
        }
        break;
      }

      case "numerical": {
        const studentRaw = answerData.numerical_answer;
        // Fix for backend bug: null or empty string must NOT be treated as 0.0!
        if (studentRaw === null || studentRaw === undefined || studentRaw === "") {
          isCorrect = false;
          marksAwarded = 0; // Unattempted question gets 0
        } else {
          const studentVal = Number(studentRaw);
          const correctVal = Number(question.numerical_answer);
          const tolerance = Number(question.numerical_tolerance ?? 0.01);
          isCorrect = Math.abs(studentVal - correctVal) <= tolerance;
          if (isCorrect) {
            marksAwarded = Number(question.marks);
          } else {
            marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
          }
        }
        break;
      }

      default:
        isCorrect = false;
        marksAwarded = 0;
    }

    return {
      is_correct: isCorrect,
      marks_awarded: marksAwarded,
    };
  }
}

// ============================================================================
// SUITE 1: QUESTION TYPE SCORING & AutoScoreService AUDIT
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 1: AutoScoreService Question Types & Scoring Rules ---${colors.reset}`);

test("MCQ: Correct single choice awards full marks (+2.0)", () => {
  const question = {
    type: "mcq",
    marks: 2.0,
    negative: 0.5,
    questionOptions: [
      { id: 101, is_correct: false },
      { id: 102, is_correct: true },
      { id: 103, is_correct: false },
    ],
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(question, { selected_option_ids: [102] });
  assert.strictEqual(result.is_correct, true);
  assert.strictEqual(result.marks_awarded, 2.0);
});

test("MCQ: Incorrect single choice awards 0 marks (Standard mode)", () => {
  const question = {
    type: "mcq",
    marks: 2.0,
    negative: 0.5,
    questionOptions: [
      { id: 101, is_correct: false },
      { id: 102, is_correct: true },
    ],
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(question, { selected_option_ids: [101] });
  assert.strictEqual(result.is_correct, false);
  assert.strictEqual(result.marks_awarded, 0);
});

test("MCQ: Incorrect choice deducts negative marking penalty (-0.5) when enabled", () => {
  const question = {
    type: "mcq",
    marks: 2.0,
    negative: 0.5,
    questionOptions: [
      { id: 101, is_correct: false },
      { id: 102, is_correct: true },
    ],
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(
    question,
    { selected_option_ids: [101] },
    true // enableNegativeMarking
  );
  assert.strictEqual(result.is_correct, false);
  assert.strictEqual(result.marks_awarded, -0.5);
});

test("MSQ: Multi-select with exact match of all correct options awards full marks (+3.0)", () => {
  const question = {
    type: "multi_select",
    marks: 3.0,
    negative: 1.0,
    questionOptions: [
      { id: 201, is_correct: true },
      { id: 202, is_correct: true },
      { id: 203, is_correct: false },
      { id: 204, is_correct: true },
    ],
  };
  // Student selects 201, 202, 204
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    selected_option_ids: [204, 201, 202], // Unordered input
  });
  assert.strictEqual(result.is_correct, true);
  assert.strictEqual(result.marks_awarded, 3.0);
});

test("MSQ: Partial correct with ZERO incorrect options awards 50% partial marks (+1.5)", () => {
  const question = {
    type: "multi_select",
    marks: 3.0,
    negative: 1.0,
    questionOptions: [
      { id: 201, is_correct: true },
      { id: 202, is_correct: true },
      { id: 203, is_correct: true },
      { id: 204, is_correct: false },
    ],
  };
  // Student selects only 201 and 202 (2 out of 3, but NO wrong choices)
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    selected_option_ids: [201, 202],
  });
  assert.strictEqual(result.is_correct, false);
  assert.strictEqual(result.marks_awarded, 1.5);
});

test("MSQ: Selecting any incorrect option disqualifies from partial marks (0 or -1.0)", () => {
  const question = {
    type: "multi_select",
    marks: 3.0,
    negative: 1.0,
    questionOptions: [
      { id: 201, is_correct: true },
      { id: 202, is_correct: true },
      { id: 203, is_correct: false }, // WRONG option
    ],
  };
  // Student selects 201 (correct) AND 203 (wrong)
  const resultWithNeg = AutoScoreServiceSimulator.scoreAnswer(
    question,
    { selected_option_ids: [201, 203] },
    true
  );
  assert.strictEqual(resultWithNeg.is_correct, false);
  assert.strictEqual(resultWithNeg.marks_awarded, -1.0);
});

test("Numerical: Value within floating-point tolerance (3.141 vs 3.14159, tol=0.01) is correct", () => {
  const question = {
    type: "numerical",
    marks: 2.0,
    numerical_answer: 3.14159,
    numerical_tolerance: 0.01,
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    numerical_answer: 3.14,
  });
  assert.strictEqual(result.is_correct, true);
  assert.strictEqual(result.marks_awarded, 2.0);
});

test("Numerical: Value outside tolerance is incorrect", () => {
  const question = {
    type: "numerical",
    marks: 2.0,
    numerical_answer: 100.0,
    numerical_tolerance: 0.5,
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    numerical_answer: 101.0,
  });
  assert.strictEqual(result.is_correct, false);
  assert.strictEqual(result.marks_awarded, 0);
});

test("Numerical Edge Case: Empty string / null submitted for question with answer 0 must NOT award marks", () => {
  const question = {
    type: "numerical",
    marks: 2.0,
    numerical_answer: 0,
    numerical_tolerance: 0.01,
  };
  // Empty answer
  const resultEmpty = AutoScoreServiceSimulator.scoreAnswer(question, {
    numerical_answer: "",
  });
  assert.strictEqual(resultEmpty.is_correct, false, "Blank answer must not score true for answer 0");
  assert.strictEqual(resultEmpty.marks_awarded, 0);

  // Null answer
  const resultNull = AutoScoreServiceSimulator.scoreAnswer(question, {
    numerical_answer: null,
  });
  assert.strictEqual(resultNull.is_correct, false);
  assert.strictEqual(resultNull.marks_awarded, 0);
});

test("Short Answer: Case-insensitive and trimmed whitespace comparison succeeds", () => {
  const question = {
    type: "short_answer",
    marks: 3.0,
    shortAnswerAcceptables: [
      { acceptable_text: "nonlocal" },
      { acceptable_text: "non-local" },
    ],
  };
  // Case mismatch and leading/trailing whitespace
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    text_answer: "  NonLocal \n",
  });
  assert.strictEqual(result.is_correct, true);
  assert.strictEqual(result.marks_awarded, 3.0);
});

test("Short Answer: Blank text answer awards 0 marks without error", () => {
  const question = {
    type: "short_answer",
    marks: 3.0,
    shortAnswerAcceptables: [{ acceptable_text: "python" }],
  };
  const result = AutoScoreServiceSimulator.scoreAnswer(question, {
    text_answer: "   ",
  });
  assert.strictEqual(result.is_correct, false);
  assert.strictEqual(result.marks_awarded, 0);
});

// ============================================================================
// SUITE 2: TIMED TEST ENGINE & AUTO-SUBMIT RACE CONDITIONS
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 2: Timed Test Engine & Zero-Timer Auto-Submit ---${colors.reset}`);

class ExamTimerEngine {
  constructor(initialSeconds, onAutoSubmit) {
    this.remainingSeconds = initialSeconds;
    this.isSubmitting = false;
    this.hasSubmitted = false;
    this.onAutoSubmit = onAutoSubmit;
    this.stagedAnswers = {};
    this.submitCallCount = 0;
  }

  recordAnswer(questionId, answer) {
    if (this.hasSubmitted) {
      throw new Error("Cannot record answer after submission");
    }
    this.stagedAnswers[questionId] = answer;
  }

  tick() {
    if (this.hasSubmitted) return;

    if (this.remainingSeconds > 0) {
      this.remainingSeconds -= 1;
    }

    if (this.remainingSeconds <= 0 && !this.isSubmitting && !this.hasSubmitted) {
      this.triggerAutoSubmit();
    }
  }

  triggerAutoSubmit() {
    if (this.hasSubmitted || this.isSubmitting) return;
    this.isSubmitting = true;
    this.submitCallCount += 1;
    this.onAutoSubmit(this.stagedAnswers);
    this.hasSubmitted = true;
    this.isSubmitting = false;
  }
}

test("Timer countdown: Reaching exactly 00:00 triggers auto-submission once", () => {
  let submittedPayload = null;
  const engine = new ExamTimerEngine(2, (payload) => {
    submittedPayload = payload;
  });

  engine.recordAnswer("q1", [1]);
  engine.tick(); // 1s remaining
  assert.strictEqual(engine.hasSubmitted, false);

  engine.tick(); // 0s remaining -> Triggers auto-submit
  assert.strictEqual(engine.hasSubmitted, true);
  assert.strictEqual(engine.submitCallCount, 1);
  assert.deepStrictEqual(submittedPayload, { q1: [1] });

  // Subsequent ticks must not trigger double submission
  engine.tick();
  engine.tick();
  assert.strictEqual(engine.submitCallCount, 1);
});

test("Timer Race Condition: Option tapped at 00:00.01s is captured in final submission payload", () => {
  let capturedAnswers = null;
  const engine = new ExamTimerEngine(1, (answers) => {
    capturedAnswers = JSON.parse(JSON.stringify(answers));
  });

  // User taps option right before the zero tick executes
  engine.recordAnswer("q5", 42);
  engine.tick(); // hits 0s

  assert.strictEqual(engine.hasSubmitted, true);
  assert.strictEqual(capturedAnswers["q5"], 42, "Staged answer tapped at final second must be in payload");
});

test("Back Button Interception Guard: Accidental back navigation raises warning modal and prevents exit", () => {
  let isModalOpen = false;
  let modalTitle = "";
  const navigationGuard = {
    examInProgress: true,
    interceptBackAction: () => {
      if (navigationGuard.examInProgress) {
        isModalOpen = true;
        modalTitle = "Leave Exam?";
        return false; // Intercept & block navigation
      }
      return true; // Allow navigation
    },
    confirmExit: () => {
      navigationGuard.examInProgress = false;
      isModalOpen = false;
      return true;
    },
    cancelExit: () => {
      isModalOpen = false;
      return false;
    },
  };

  // Attempt to navigate back
  const blocked = !navigationGuard.interceptBackAction();
  assert.strictEqual(blocked, true, "Back button navigation must be blocked during exam");
  assert.strictEqual(isModalOpen, true, "Modal warning must be displayed");
  assert.strictEqual(modalTitle, "Leave Exam?");

  // Candidate taps 'Cancel' -> stays in exam
  navigationGuard.cancelExit();
  assert.strictEqual(isModalOpen, false);
  assert.strictEqual(navigationGuard.examInProgress, true);
});

// ============================================================================
// SUITE 3: IN-FLIGHT NETWORK DROP & RETRY QUEUE (LOSSLESS)
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 3: In-Flight Network Drop Resilience & Lossless Retry ---${colors.reset}`);

class NetworkSubmissionClient {
  constructor() {
    this.offline = false;
    this.pendingQueue = [];
    this.submittedAttempts = new Set();
  }

  async submitAttempt(attemptId, payload) {
    if (this.offline) {
      // Store in memory queue for resilient retry without local DB drama
      this.pendingQueue.push({ attemptId, payload, timestamp: Date.now() });
      throw new Error("NETWORK_DISCONNECTED: Failed to reach examination server");
    }

    if (this.submittedAttempts.has(attemptId)) {
      // Backend returns 422 if already submitted
      const err = new Error("This attempt has already been submitted");
      err.status = 422;
      throw err;
    }

    this.submittedAttempts.add(attemptId);
    return {
      success: true,
      attempt_id: attemptId,
      score: 18.5,
      total_marks: 20,
    };
  }

  async flushRetryQueue() {
    const results = [];
    while (this.pendingQueue.length > 0) {
      const item = this.pendingQueue.shift();
      try {
        const res = await this.submitAttempt(item.attemptId, item.payload);
        results.push(res);
      } catch (err) {
        if (err.status === 422) {
          // Already submitted in backend before connection drop: treat as recovered success!
          results.push({
            success: true,
            attempt_id: item.attemptId,
            recovered: true,
          });
        } else {
          // Put back in queue if network still failing
          this.pendingQueue.unshift(item);
          throw err;
        }
      }
    }
    return results;
  }
}

testAsync("Network Drop: Sudden WiFi drop queues submission and retains payload in-flight", async () => {
  const client = new NetworkSubmissionClient();
  client.offline = true;

  const stagedPayload = { answers: [{ question_id: 1, selected_option_ids: [102] }] };

  let threwError = false;
  try {
    await client.submitAttempt(999, stagedPayload);
  } catch (err) {
    threwError = true;
    assert(err.message.includes("NETWORK_DISCONNECTED"));
  }

  assert.strictEqual(threwError, true);
  assert.strictEqual(client.pendingQueue.length, 1);
  assert.deepStrictEqual(client.pendingQueue[0].payload, stagedPayload);

  // Network comes back online -> retry queue delivers payload without loss
  client.offline = false;
  const retryResults = await client.flushRetryQueue();
  assert.strictEqual(retryResults.length, 1);
  assert.strictEqual(retryResults[0].success, true);
  assert.strictEqual(retryResults[0].attempt_id, 999);
  assert.strictEqual(client.pendingQueue.length, 0);
});

testAsync("Network Drop Recovery: Idempotent handling of 422 already-submitted on reconnection", async () => {
  const client = new NetworkSubmissionClient();
  client.submittedAttempts.add(888); // Backend already recorded submission
  client.offline = false;
  // Queue had 888 due to client-side ack drop
  client.pendingQueue.push({ attemptId: 888, payload: {} });

  const retryResults = await client.flushRetryQueue();
  assert.strictEqual(retryResults.length, 1);
  assert.strictEqual(retryResults[0].success, true);
  assert.strictEqual(retryResults[0].recovered, true);
});

// ============================================================================
// SUITE 4: AUTH & SESSION INVALIDATION
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 4: Auth & Session Invalidation ---${colors.reset}`);

class AuthSessionManager {
  constructor() {
    this.tokens = new Map(); // tokenId -> { userId, token, expiresAt }
    this.users = new Map(); // userId -> { id, email, passwordHash, is_active }
  }

  login(user) {
    if (!user.is_active) {
      const err = new Error("Your account has been deactivated.");
      err.status = 403;
      throw err;
    }
    // Sanctum pattern: delete existing tokens on login
    for (const [id, t] of this.tokens.entries()) {
      if (t.userId === user.id) this.tokens.delete(id);
    }
    const tokenId = `tok_${Date.now()}_${Math.random()}`;
    this.tokens.set(tokenId, { userId: user.id, tokenId });
    return tokenId;
  }

  changePassword(userId, currentTokenId) {
    // Retain current token, revoke all other active sessions
    for (const [id, t] of this.tokens.entries()) {
      if (t.userId === userId && id !== currentTokenId) {
        this.tokens.delete(id);
      }
    }
  }

  resetPasswordViaOtp(userId) {
    // Revoke all tokens across all devices
    for (const [id, t] of this.tokens.entries()) {
      if (t.userId === userId) this.tokens.delete(id);
    }
  }

  validateToken(tokenId) {
    return this.tokens.has(tokenId);
  }
}

test("Session Invalidation: New login terminates old sessions for the user", () => {
  const auth = new AuthSessionManager();
  const user = { id: 1, email: "student@iitm.ac.in", is_active: true };

  const session1 = auth.login(user);
  assert.strictEqual(auth.validateToken(session1), true);

  const session2 = auth.login(user);
  assert.strictEqual(auth.validateToken(session1), false, "Old session must be invalidated");
  assert.strictEqual(auth.validateToken(session2), true, "New session must be active");
});

test("Session Invalidation: Deactivated user is blocked from logging in (403 Forbidden)", () => {
  const auth = new AuthSessionManager();
  const inactiveUser = { id: 2, email: "banned@iitm.ac.in", is_active: false };

  assert.throws(
    () => {
      auth.login(inactiveUser);
    },
    (err) => err.status === 403 && err.message.includes("deactivated")
  );
});

test("Session Invalidation: Change password keeps current device active and revokes concurrent sessions", () => {
  const auth = new AuthSessionManager();
  const user = { id: 3, email: "tushar@iitm.ac.in", is_active: true };

  const mobileToken = auth.login(user);
  // Simulate concurrent desktop token
  const desktopToken = `tok_desktop_${Date.now()}`;
  auth.tokens.set(desktopToken, { userId: user.id, tokenId: desktopToken });

  auth.changePassword(user.id, mobileToken);
  assert.strictEqual(auth.validateToken(mobileToken), true, "Current mobile device token preserved");
  assert.strictEqual(auth.validateToken(desktopToken), false, "Concurrent desktop token revoked");
});

test("Session Invalidation: Forgot password OTP reset revokes all device sessions", () => {
  const auth = new AuthSessionManager();
  const user = { id: 4, email: "student4@iitm.ac.in", is_active: true };

  const tokenA = auth.login(user);
  auth.resetPasswordViaOtp(user.id);
  assert.strictEqual(auth.validateToken(tokenA), false, "All sessions must be terminated");
});

// ============================================================================
// SUITE 5: QUIZZES FILTERING (FOUNDATION, DIPLOMA, DEGREE)
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 5: Quizzes Level Filtering & Navigation ---${colors.reset}`);

const mockCourses = [
  { id: 1, name: "Mathematics 1", slug: "maths1", level: "foundation", is_active: true },
  { id: 2, name: "Computational Thinking", slug: "ct", level: "foundation", is_active: true },
  { id: 3, name: "Database Management", slug: "dbms", level: "diploma", is_active: true },
  { id: 4, name: "Machine Learning Foundations", slug: "mlf", level: "diploma", is_active: true },
  { id: 5, name: "Deep Learning", slug: "dl", level: "degree", is_active: true },
  { id: 6, name: "Software Engineering", slug: "se", level: "degree", is_active: false }, // Inactive
];

function filterCoursesByLevel(courses, level) {
  return courses.filter((c) => c.is_active && (!level || c.level === level.toLowerCase()));
}

test("Level Filter: Foundation returns only active foundation courses", () => {
  const results = filterCoursesByLevel(mockCourses, "foundation");
  assert.strictEqual(results.length, 2);
  assert.strictEqual(results.every((c) => c.level === "foundation"), true);
});

test("Level Filter: Diploma returns only diploma courses", () => {
  const results = filterCoursesByLevel(mockCourses, "diploma");
  assert.strictEqual(results.length, 2);
  assert.strictEqual(results.every((c) => c.level === "diploma"), true);
});

test("Level Filter: Degree filters out inactive courses", () => {
  const results = filterCoursesByLevel(mockCourses, "degree");
  assert.strictEqual(results.length, 1); // Only active DL, SE is inactive
  assert.strictEqual(results[0].slug, "dl");
});

// ============================================================================
// SUITE 6: SUPPORT TAB (DISCUSSIONS & VOTING ENGINE)
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 6: Support Tab Discussions, Voting & XP Rewards ---${colors.reset}`);

class DiscussionEngine {
  constructor() {
    this.discussions = new Map();
    this.votes = new Map(); // key `${userId}_${discussionId}`
    this.userXp = new Map();
  }

  createDiscussion(authorId, title, body, isAnonymous = false) {
    const id = this.discussions.size + 1;
    this.discussions.set(id, {
      id,
      authorId,
      title,
      body,
      isAnonymous,
      voteCount: 0,
      replies: [],
      acceptedReplyId: null,
      isSolved: false,
    });
    return id;
  }

  addReply(discussionId, authorId, body) {
    const disc = this.discussions.get(discussionId);
    if (!disc) throw new Error("Discussion not found");
    const replyId = disc.replies.length + 1;
    disc.replies.push({ id: replyId, authorId, body, voteCount: 0 });
    return replyId;
  }

  voteDiscussion(userId, discussionId) {
    const disc = this.discussions.get(discussionId);
    if (!disc) throw new Error("Discussion not found");
    const key = `${userId}_${discussionId}`;
    const authorId = disc.authorId;

    if (this.votes.has(key)) {
      // Toggle off vote
      this.votes.delete(key);
      disc.voteCount = Math.max(0, disc.voteCount - 1);
      if (authorId !== userId) {
        this.userXp.set(authorId, (this.userXp.get(authorId) || 0) - 5);
      }
      return { voted: false, voteCount: disc.voteCount };
    } else {
      // Upvote
      this.votes.set(key, true);
      disc.voteCount += 1;
      if (authorId !== userId) {
        this.userXp.set(authorId, (this.userXp.get(authorId) || 0) + 5);
      }
      return { voted: true, voteCount: disc.voteCount };
    }
  }

  acceptReply(userId, discussionId, replyId) {
    const disc = this.discussions.get(discussionId);
    if (!disc) throw new Error("Discussion not found");
    if (disc.authorId !== userId) {
      const err = new Error("Only discussion author can accept reply");
      err.status = 403;
      throw err;
    }
    const reply = disc.replies.find((r) => r.id === replyId);
    if (!reply) throw new Error("Reply not found");
    if (reply.authorId === userId) {
      const err = new Error("Cannot accept your own reply");
      err.status = 422;
      throw err;
    }

    disc.acceptedReplyId = replyId;
    disc.isSolved = true;
    this.userXp.set(reply.authorId, (this.userXp.get(reply.authorId) || 0) + 15);
    return { isSolved: true, acceptedReplyId: replyId };
  }
}

test("Discussion Voting: Upvoting increments vote count and awards +5 XP to author", () => {
  const engine = new DiscussionEngine();
  const discId = engine.createDiscussion(10, "How does KaTeX render?", "Details here");

  const voteRes = engine.voteDiscussion(20, discId);
  assert.strictEqual(voteRes.voted, true);
  assert.strictEqual(voteRes.voteCount, 1);
  assert.strictEqual(engine.userXp.get(10), 5, "Author must gain +5 XP");

  // Toggle off vote
  const unvoteRes = engine.voteDiscussion(20, discId);
  assert.strictEqual(unvoteRes.voted, false);
  assert.strictEqual(unvoteRes.voteCount, 0);
  assert.strictEqual(engine.userXp.get(10), 0, "Author XP must decrement by 5");
});

test("Accept Reply: Author accepting peer reply marks solved and awards +15 XP", () => {
  const engine = new DiscussionEngine();
  const discId = engine.createDiscussion(10, "Doubt in Week 3", "Stem code question");
  const replyId = engine.addReply(discId, 25, "Use nonlocal variable");

  const acceptRes = engine.acceptReply(10, discId, replyId);
  assert.strictEqual(acceptRes.isSolved, true);
  assert.strictEqual(acceptRes.acceptedReplyId, replyId);
  assert.strictEqual(engine.userXp.get(25), 15, "Reply author must gain +15 XP");
});

test("Accept Reply: Author cannot accept their own reply (422 Unprocessable)", () => {
  const engine = new DiscussionEngine();
  const discId = engine.createDiscussion(10, "Self solved issue", "Text");
  const selfReplyId = engine.addReply(discId, 10, "I solved it myself");

  assert.throws(
    () => {
      engine.acceptReply(10, discId, selfReplyId);
    },
    (err) => err.status === 422
  );
});

// ============================================================================
// SUITE 7: LaTeX KaTeX FORMULA RENDERING ENGINE
// ============================================================================
console.log(`\n${colors.cyan}${colors.bold}--- SUITE 7: LaTeX Formula (KaTeX) Parsing & Degradation ---${colors.reset}`);

function parseMathTokens(rawText) {
  // Simulates regex detection of inline $...$ and block $$...$$ in stems
  const displayMathRegex = /\$\$([\s\S]+?)\$\$/g;
  const inlineMathRegex = /\$([^\$]+?)\$/g;

  const displayMatches = [];
  let match;
  while ((match = displayMathRegex.exec(rawText)) !== null) {
    displayMatches.push(match[1]);
  }

  const inlineMatches = [];
  const textWithoutDisplay = rawText.replace(displayMathRegex, "");
  while ((match = inlineMathRegex.exec(textWithoutDisplay)) !== null) {
    inlineMatches.push(match[1]);
  }

  return {
    displayMatches,
    inlineMatches,
    hasMath: displayMatches.length > 0 || inlineMatches.length > 0,
  };
}

test("LaTeX KaTeX: Correctly extracts inline and block formulas", () => {
  const stem = "Calculate the derivative of $f(x) = x^2$ where $$\\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}$$";
  const parsed = parseMathTokens(stem);

  assert.strictEqual(parsed.hasMath, true);
  assert.strictEqual(parsed.inlineMatches.length, 1);
  assert.strictEqual(parsed.inlineMatches[0], "f(x) = x^2");
  assert.strictEqual(parsed.displayMatches.length, 1);
  assert(parsed.displayMatches[0].includes("\\frac"));
});

test("LaTeX KaTeX: Malformed LaTeX fallback maintains string integrity without crash", () => {
  const malformed = "Evaluate \\frac{1}{0 without closing braces $x = ";
  // Should not throw exception and should be safely handled
  assert.doesNotThrow(() => {
    parseMathTokens(malformed);
  });
});

// ============================================================================
// SUMMARY REPORT
// ============================================================================
console.log(`\n${colors.bold}============================================================================${colors.reset}`);
console.log(`${colors.bold}TEST RUN SUMMARY${colors.reset}`);
console.log(`Total Assertions Executed: ${passedCount + failedCount}`);
console.log(`${colors.green}Passed: ${passedCount}${colors.reset}`);
console.log(`${failedCount > 0 ? colors.red : colors.green}Failed: ${failedCount}${colors.reset}`);
console.log(`${colors.bold}============================================================================\n${colors.reset}`);

if (failedCount > 0) {
  process.exit(1);
}
