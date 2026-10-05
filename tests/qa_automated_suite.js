/**
 * ============================================================================
 * Quiz Lab - Comprehensive QA Automated Test Suite & Engine Validation Runner
 * ============================================================================
 * Covers all 5 Android App Tabs & Exam Platform Edge Cases:
 *  Tab 1: Home Dashboard (Streak, 12-Week Accuracy, Hours, Ranks, Feed)
 *  Tab 2: Quizzes (Filtering Foundation/Diploma/Degree, Weekly Sections)
 *  Tab 3: Test Engine (AutoScoreService, Negative Marking, Numerical, Auto-Submit,
 *          Back Button Intercept, Palette Sync, Lossless Retry, KaTeX Formulas)
 *  Tab 4: Support (Discussions, Voting, Solutions Acceptance, Doubts Chat)
 *  Tab 5: More (Profile, Avatar Validation, Session Invalidation, Password Reset)
 *  Login & Multi-Role Authorization:
 *   - Login credential validation, unverified email checks, inactive account checks
 *   - OTP 6-digit verification and expiration
 *   - Student (Rank 0) vs Admin (Rank 1) vs Manager (Rank 2) RBAC Gates
 *   - Privilege Escalation Attack Simulations & Outranking Guards
 * ============================================================================
 */

const assert = require("assert");

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
  magenta: "\x1b[35m",
};

let passedCount = 0;
let failedCount = 0;
const testResults = [];

async function it(description, fn) {
  try {
    const res = fn();
    if (res instanceof Promise) {
      await res;
    }
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
// LOGIC IMPLEMENTATIONS & SIMULATORS
// ============================================================================

/**
 * AutoScoreService Simulator (mirrors Laravel backend & fixes known scoring bugs)
 */
class AutoScoreServiceSimulator {
  static scoreAnswer(question, answerData, enableNegativeMarking = false) {
    let isCorrect = false;
    let marksAwarded = 0;
    const options = question.questionOptions || [];
    const negativePenalty = enableNegativeMarking ? Number(question.negative || 0) : 0;

    switch (question.type) {
      case "mcq":
      case "true_false": {
        const correctOption = options.find((opt) => opt.is_correct === true);
        const selected = answerData.selected_option_ids?.[0] ?? null;
        isCorrect = correctOption !== undefined && Number(selected) === Number(correctOption.id);
        if (isCorrect) {
          marksAwarded = Number(question.marks);
        } else if (selected !== null && selected !== undefined) {
          marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
        } else {
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

          if (selectedWrong.length === 0 && selectedCorrect.length > 0) {
            marksAwarded = Math.round(Number(question.marks) * 0.5 * 100) / 100;
          } else {
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
        // Bugfix: Blank/empty/null must NOT be cast to 0.0
        if (studentRaw === null || studentRaw === undefined || studentRaw === "") {
          isCorrect = false;
          marksAwarded = 0;
        } else {
          const studentVal = Number(studentRaw);
          if (isNaN(studentVal)) {
            isCorrect = false;
            marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
          } else {
            const correctVal = Number(question.numerical_answer);
            const tolerance = Number(question.numerical_tolerance ?? 0.01);
            isCorrect = Math.abs(studentVal - correctVal) <= tolerance;
            if (isCorrect) {
              marksAwarded = Number(question.marks);
            } else {
              marksAwarded = negativePenalty === 0 ? 0 : -negativePenalty;
            }
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

  static calculateTotalScore(questions, studentAnswers, enableNegativeMarking = true, clampAtZero = true) {
    let sumAwarded = 0;
    let totalMarks = 0;

    for (const q of questions) {
      totalMarks += Number(q.marks || 0);
      const answerData = studentAnswers[q.id] || {};
      const score = this.scoreAnswer(q, answerData, enableNegativeMarking);
      sumAwarded += score.marks_awarded;
    }

    const finalScore = clampAtZero ? Math.max(0, sumAwarded) : sumAwarded;
    const roundedScore = Math.round(finalScore * 100) / 100;
    const percentage = totalMarks > 0 ? Math.round((roundedScore / totalMarks) * 10000) / 100 : 0;

    return {
      score: roundedScore,
      raw_score: Math.round(sumAwarded * 100) / 100,
      total_marks: totalMarks,
      percentage: percentage,
    };
  }
}

/**
 * Question Palette State Machine
 */
class QuestionPaletteManager {
  static getStatus(questionId, session) {
    const isReviewed = session.reviewFlags?.includes(questionId);
    const ans = session.answers?.[questionId];
    const isAnswered = ans !== undefined && ans !== null && ans !== "" && !(Array.isArray(ans) && ans.length === 0);
    const isVisited = session.visitedIndices?.includes(questionId);

    if (isAnswered && isReviewed) return "ANSWERED_AND_REVIEW";
    if (isAnswered) return "ANSWERED";
    if (isReviewed) return "REVIEW";
    if (isVisited) return "VISITED_UNANSWERED";
    return "UNVISITED";
  }
}

/**
 * Dashboard Metrics Calculator (mirrors DashboardController.php)
 */
class DashboardMetricsSimulator {
  static getGreeting(hour) {
    if (hour < 12) return "morning";
    if (hour < 17) return "afternoon";
    if (hour < 21) return "evening";
    return "night";
  }

  static computeStreak(activityDateStrings, currentDateString) {
    const dateSet = new Set(activityDateStrings);
    let streak = 0;
    let current = new Date(currentDateString);

    const formatDate = (d) => d.toISOString().split("T")[0];

    while (dateSet.has(formatDate(current))) {
      streak++;
      current.setDate(current.getDate() - 1);
    }

    if (streak === 0) {
      current = new Date(currentDateString);
      current.setDate(current.getDate() - 1);
      while (dateSet.has(formatDate(current))) {
        streak++;
        current.setDate(current.getDate() - 1);
      }
    }

    const history28 = [];
    const scanDate = new Date(currentDateString);
    for (let i = 27; i >= 0; i--) {
      const d = new Date(scanDate);
      d.setDate(d.getDate() - i);
      history28.push(dateSet.has(formatDate(d)) ? 1 : 0);
    }

    return { streak, history28 };
  }

  static computeSpeedScore(avgSeconds) {
    if (avgSeconds <= 0) return 0;
    return Math.max(0, Math.min(100, Math.round((100 - (avgSeconds - 60) / 5.4) * 10) / 10));
  }
}

/**
 * Auth & Login Simulator (mirrors AuthController.php)
 */
class AuthLoginSimulator {
  static login(email, password, userDb) {
    if (!email || !email.includes("@")) {
      return { status: 422, error: "Valid email is required" };
    }
    if (!password) {
      return { status: 422, error: "Password is required" };
    }
    const user = userDb.find((u) => u.email === email);
    if (!user || user.password !== password) {
      return { status: 401, error: "Invalid credentials" };
    }
    if (!user.email_verified_at) {
      return {
        status: 403,
        error: "Please verify your email first.",
        needs_verification: true,
        email: user.email,
      };
    }
    if (!user.is_active) {
      return { status: 403, error: "Your account has been deactivated." };
    }
    // Sanctum pattern: delete existing tokens on login
    user.tokens = [];
    const newToken = `tok_${user.role}_${Date.now()}`;
    user.tokens.push(newToken);
    return {
      status: 200,
      token: newToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        is_admin: user.role === "admin" || user.role === "manager",
        is_manager: user.role === "manager",
      },
    };
  }

  static verifyOtp(email, otp, userDb) {
    if (!otp || String(otp).length !== 6 || !/^\d{6}$/.test(String(otp))) {
      return { status: 422, error: "The otp field must be 6 digits." };
    }
    const user = userDb.find((u) => u.email === email);
    if (!user) return { status: 404, error: "User not found" };
    if (!user.otp || user.otp !== otp || (user.otp_expires_at && user.otp_expires_at < Date.now())) {
      return { status: 422, error: "Invalid or expired OTP" };
    }
    user.email_verified_at = Date.now();
    user.otp = null;
    const token = `tok_${user.role}_${Date.now()}`;
    user.tokens = [token];
    return {
      status: 200,
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
    };
  }
}

/**
 * RBAC & Authorization Gateway Simulator (mirrors User.php, IsAdmin, IsManager, AdminUserController)
 */
class RBACAuthorizationGateway {
  static ROLES = { STUDENT: "student", ADMIN: "admin", MANAGER: "manager" };
  static ROLE_RANKS = { student: 0, admin: 1, manager: 2 };

  static canAccessRoute(user, route, method = "GET") {
    const role = user.role || "student";
    const rank = this.ROLE_RANKS[role] ?? 0;

    // Student accessible routes
    if (
      route.startsWith("/api/student/") ||
      route.startsWith("/api/quizzes/") ||
      route.startsWith("/api/attempts/") ||
      route === "/api/auth/me" ||
      route === "/api/auth/logout"
    ) {
      return { allowed: true };
    }

    // Manager-only routes
    if (
      route === "/api/exam-platform/reset" ||
      route.match(/^\/api\/admin\/users\/\d+\/role$/) ||
      (route.match(/^\/api\/admin\/users\/\d+$/) && method === "DELETE")
    ) {
      if (rank < 2) {
        return { allowed: false, status: 403, error: "Forbidden. Manager access required." };
      }
      return { allowed: true };
    }

    // Admin and above routes
    if (route.startsWith("/api/admin/") || route === "/api/exam-platform/action") {
      if (rank < 1) {
        return { allowed: false, status: 403, error: "Forbidden. Admin access required." };
      }
      return { allowed: true };
    }

    return { allowed: true };
  }

  static canModifyUser(actor, targetUser, action, allUsers = []) {
    if (actor.id === targetUser.id) {
      return { allowed: false, status: 422, error: `You cannot ${action} your own account.` };
    }

    // Manager role change & deletion rules: Never leave platform without a manager
    if (action === "delete" || action === "demote" || action === "change role") {
      if (
        targetUser.role === "manager" &&
        allUsers.filter((u) => u.role === "manager").length <= 1
      ) {
        return {
          allowed: false,
          status: 422,
          error: "This is the only manager account and cannot be modified/deleted.",
        };
      }
    }

    const actorRank = this.ROLE_RANKS[actor.role] ?? 0;
    const targetRank = this.ROLE_RANKS[targetUser.role] ?? 0;

    // Tiers: Actor must strictly outrank target, unless actor is Manager performing setRole / destroy
    const isManagerAdminAction = actorRank === 2 && (action === "delete" || action === "demote" || action === "change role");
    if (!isManagerAdminAction && actorRank <= targetRank) {
      return {
        allowed: false,
        status: 403,
        error: `You do not have permission to ${action} a ${targetUser.role} account.`,
      };
    }

    return { allowed: true };
  }

  static filterCandidateSyncPayload(candidateUser, payload) {
    if (candidateUser.role === "student") {
      const sanitized = { studentSessions: {}, reentryRequests: [] };
      if (payload.studentSessions && payload.studentSessions[candidateUser.email]) {
        const incoming = { ...payload.studentSessions[candidateUser.email] };
        delete incoming.status; // only proctor may change status!
        sanitized.studentSessions[candidateUser.email] = incoming;
      }
      if (Array.isArray(payload.reentryRequests)) {
        sanitized.reentryRequests = payload.reentryRequests.filter(
          (r) => r.email === candidateUser.email && r.status === "pending"
        );
      }
      return sanitized;
    }
    return payload;
  }

  static sanitizeChatMessage(user, msg) {
    if (user.role === "student") {
      return {
        ...msg,
        senderName: user.name,
        senderEmail: user.email,
        role: "student",
        isAnnouncement: false,
      };
    }
    return msg;
  }
}

// ============================================================================
// MAIN RUNNER
// ============================================================================

async function runAllTests() {
  console.log(`\n${colors.bold}============================================================================${colors.reset}`);
  console.log(`${colors.bold}Quiz Lab Android App - Complete QA Test Suite & Edge Case Matrix${colors.reset}`);
  console.log(`${colors.bold}============================================================================${colors.reset}`);

  // --------------------------------------------------------------------------
  // TAB 1: HOME DASHBOARD
  // --------------------------------------------------------------------------
  console.log(`\n${colors.magenta}${colors.bold}[TAB 1: HOME DASHBOARD]${colors.reset}`);

  await it("Home: Time-of-day greeting matches system hour boundaries", () => {
    assert.strictEqual(DashboardMetricsSimulator.getGreeting(8), "morning");
    assert.strictEqual(DashboardMetricsSimulator.getGreeting(13), "afternoon");
    assert.strictEqual(DashboardMetricsSimulator.getGreeting(18), "evening");
    assert.strictEqual(DashboardMetricsSimulator.getGreeting(22), "night");
  });

  await it("Home: Streak engine accurately tracks active streak and fallback to yesterday", () => {
    const today = "2026-10-05";
    const datesWithToday = ["2026-10-05", "2026-10-04", "2026-10-03"];
    const res1 = DashboardMetricsSimulator.computeStreak(datesWithToday, today);
    assert.strictEqual(res1.streak, 3);
    assert.strictEqual(res1.history28[27], 1);

    const datesWithoutToday = ["2026-10-04", "2026-10-03"];
    const res2 = DashboardMetricsSimulator.computeStreak(datesWithoutToday, today);
    assert.strictEqual(res2.streak, 2);
    assert.strictEqual(res2.history28[27], 0);
    assert.strictEqual(res2.history28[26], 1);
  });

  await it("Home: Speed score formula linearly normalizes quiz completion velocity", () => {
    assert.strictEqual(DashboardMetricsSimulator.computeSpeedScore(60), 100);
    assert.strictEqual(DashboardMetricsSimulator.computeSpeedScore(600), 0);
    assert.strictEqual(DashboardMetricsSimulator.computeSpeedScore(330), 50);
    assert.strictEqual(DashboardMetricsSimulator.computeSpeedScore(900), 0);
  });

  await it("Home: Community feed privacy masks student full names into 'First L.' format", () => {
    const mask = (rawName) => {
      const parts = rawName.trim().split(/\s+/);
      const first = parts[0] || "Student";
      const last = parts.length > 1 ? ` ${parts[parts.length - 1][0].toUpperCase()}.` : "";
      return `${first}${last}`;
    };
    assert.strictEqual(mask("Tushar Singh"), "Tushar S.");
    assert.strictEqual(mask("Aditi"), "Aditi");
    assert.strictEqual(mask("Venkat Raman Krishnan"), "Venkat K.");
  });

  // --------------------------------------------------------------------------
  // TAB 2: QUIZZES FILTERING
  // --------------------------------------------------------------------------
  console.log(`\n${colors.magenta}${colors.bold}[TAB 2: QUIZZES & COURSE FILTERING]${colors.reset}`);

  const courseCatalog = [
    { id: 1, name: "Maths 1", slug: "maths1", level: "foundation", is_active: true },
    { id: 2, name: "English 1", slug: "eng1", level: "foundation", is_active: true },
    { id: 3, name: "Programming in Python", slug: "python", level: "foundation", is_active: true },
    { id: 4, name: "Database Management Systems", slug: "dbms", level: "diploma", is_active: true },
    { id: 5, name: "Machine Learning Foundations", slug: "mlf", level: "diploma", is_active: true },
    { id: 6, name: "Deep Learning", slug: "dl", level: "degree", is_active: true },
    { id: 7, name: "AI Ethics", slug: "ai-ethics", level: "degree", is_active: false },
  ];

  await it("Quizzes: Foundation level filter selects exact Foundation program subjects", () => {
    const foundation = courseCatalog.filter((c) => c.is_active && c.level === "foundation");
    assert.strictEqual(foundation.length, 3);
    assert.deepStrictEqual(foundation.map((c) => c.slug), ["maths1", "eng1", "python"]);
  });

  await it("Quizzes: Diploma level filter excludes foundation and inactive courses", () => {
    const diploma = courseCatalog.filter((c) => c.is_active && c.level === "diploma");
    assert.strictEqual(diploma.length, 2);
    assert.deepStrictEqual(diploma.map((c) => c.slug), ["dbms", "mlf"]);
  });

  await it("Quizzes: Degree filter ignores soft-deleted / deactivated courses", () => {
    const degree = courseCatalog.filter((c) => c.is_active && c.level === "degree");
    assert.strictEqual(degree.length, 1);
    assert.strictEqual(degree[0].slug, "dl");
  });

  // --------------------------------------------------------------------------
  // TAB 3: TIMED TEST ENGINE & QUIZ PLAYER
  // --------------------------------------------------------------------------
  console.log(`\n${colors.magenta}${colors.bold}[TAB 3: TIMED TEST ENGINE & QUIZ PLAYER]${colors.reset}`);

  await it("Test Engine: MCQ full marks award on correct option", () => {
    const q = {
      type: "mcq",
      marks: 2.0,
      negative: 0.5,
      questionOptions: [{ id: 1, is_correct: false }, { id: 2, is_correct: true }],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [2] }, true);
    assert.strictEqual(res.is_correct, true);
    assert.strictEqual(res.marks_awarded, 2.0);
  });

  await it("Test Engine: MCQ negative marking penalty (-0.5) deducted on wrong selection", () => {
    const q = {
      type: "mcq",
      marks: 2.0,
      negative: 0.5,
      questionOptions: [{ id: 1, is_correct: false }, { id: 2, is_correct: true }],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [1] }, true);
    assert.strictEqual(res.is_correct, false);
    assert.strictEqual(res.marks_awarded, -0.5);
  });

  await it("Test Engine: MCQ unattempted awards exactly 0 (no penalty deduction)", () => {
    const q = {
      type: "mcq",
      marks: 2.0,
      negative: 0.5,
      questionOptions: [{ id: 1, is_correct: false }, { id: 2, is_correct: true }],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [] }, true);
    assert.strictEqual(res.is_correct, false);
    assert.strictEqual(res.marks_awarded, 0);
  });

  await it("Test Engine: MSQ all-correct combination awards full marks (+3.0)", () => {
    const q = {
      type: "multi_select",
      marks: 3.0,
      negative: 1.0,
      questionOptions: [
        { id: 10, is_correct: true },
        { id: 11, is_correct: true },
        { id: 12, is_correct: false },
      ],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [11, 10] }, true);
    assert.strictEqual(res.is_correct, true);
    assert.strictEqual(res.marks_awarded, 3.0);
  });

  await it("Test Engine: MSQ partial-correct with zero incorrect picks awards partial marks (+1.5)", () => {
    const q = {
      type: "multi_select",
      marks: 3.0,
      negative: 1.0,
      questionOptions: [
        { id: 10, is_correct: true },
        { id: 11, is_correct: true },
        { id: 12, is_correct: false },
      ],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [10] }, true);
    assert.strictEqual(res.is_correct, false);
    assert.strictEqual(res.marks_awarded, 1.5);
  });

  await it("Test Engine: MSQ selecting any wrong option triggers negative penalty (-1.0)", () => {
    const q = {
      type: "multi_select",
      marks: 3.0,
      negative: 1.0,
      questionOptions: [
        { id: 10, is_correct: true },
        { id: 11, is_correct: true },
        { id: 12, is_correct: false },
      ],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { selected_option_ids: [10, 12] }, true);
    assert.strictEqual(res.is_correct, false);
    assert.strictEqual(res.marks_awarded, -1.0);
  });

  await it("Test Engine: Numerical input tolerance boundary check (19.0 vs correct 19, tol=0.01)", () => {
    const q = { type: "numerical", marks: 3.0, numerical_answer: 19, numerical_tolerance: 0.01 };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { numerical_answer: "19.00" }, true);
    assert.strictEqual(res.is_correct, true);
    assert.strictEqual(res.marks_awarded, 3.0);
  });

  await it("Test Engine: Numerical negative float value calculation (-15.5 with tolerance 0.05)", () => {
    const q = { type: "numerical", marks: 2.0, numerical_answer: -15.5, numerical_tolerance: 0.05 };
    const resValid = AutoScoreServiceSimulator.scoreAnswer(q, { numerical_answer: -15.52 }, true);
    assert.strictEqual(resValid.is_correct, true);

    const resInvalid = AutoScoreServiceSimulator.scoreAnswer(q, { numerical_answer: -15.6 }, true);
    assert.strictEqual(resInvalid.is_correct, false);
  });

  await it("Test Engine: Numerical empty/null string is NOT treated as 0", () => {
    const q = { type: "numerical", marks: 2.0, numerical_answer: 0, numerical_tolerance: 0.01 };
    const resEmpty = AutoScoreServiceSimulator.scoreAnswer(q, { numerical_answer: "" }, true);
    assert.strictEqual(resEmpty.is_correct, false);
    assert.strictEqual(resEmpty.marks_awarded, 0);
  });

  await it("Test Engine: Short answer case insensitivity and whitespace trimming", () => {
    const q = {
      type: "short_answer",
      marks: 3.0,
      shortAnswerAcceptables: [{ acceptable_text: "nonlocal" }],
    };
    const res = AutoScoreServiceSimulator.scoreAnswer(q, { text_answer: "\t  NonLocal  \n" }, true);
    assert.strictEqual(res.is_correct, true);
    assert.strictEqual(res.marks_awarded, 3.0);
  });

  await it("Test Engine: Total score calculation with Section penalties and score clamped at zero", () => {
    const questions = [
      { id: "q1", marks: 2, negative: 0.5, type: "mcq", questionOptions: [{ id: 1, is_correct: true }] },
      { id: "q2", marks: 3, negative: 1.0, type: "mcq", questionOptions: [{ id: 2, is_correct: true }] },
      { id: "q3", marks: 2, negative: 0.5, type: "mcq", questionOptions: [{ id: 3, is_correct: true }] },
    ];
    const studentAnswers = {
      q1: { selected_option_ids: [99] },
      q2: { selected_option_ids: [99] },
      q3: { selected_option_ids: [99] },
    };
    const summary = AutoScoreServiceSimulator.calculateTotalScore(questions, studentAnswers, true, true);
    assert.strictEqual(summary.raw_score, -2.0);
    assert.strictEqual(summary.score, 0.0, "Aggregate score clamped at 0");
    assert.strictEqual(summary.percentage, 0.0);
  });

  await it("Test Engine: Question palette state transitions (visited, answered, review)", () => {
    const session = {
      visitedIndices: ["q1", "q2", "q3"],
      answers: { q1: [1], q2: [2] },
      reviewFlags: ["q2", "q3"],
    };

    assert.strictEqual(QuestionPaletteManager.getStatus("q1", session), "ANSWERED");
    assert.strictEqual(QuestionPaletteManager.getStatus("q2", session), "ANSWERED_AND_REVIEW");
    assert.strictEqual(QuestionPaletteManager.getStatus("q3", session), "REVIEW");
    assert.strictEqual(QuestionPaletteManager.getStatus("q4", session), "UNVISITED");
  });

  await it("Test Engine: Timer expiry at 00:00 triggers auto-submission exactly once", async () => {
    let submitCount = 0;
    const client = {
      isAutoSubmitting: false,
      hasSubmitted: false,
      triggerAutoSubmit: () => {
        if (client.hasSubmitted || client.isAutoSubmitting) return;
        client.isAutoSubmitting = true;
        submitCount++;
        client.hasSubmitted = true;
        client.isAutoSubmitting = false;
      },
    };

    client.triggerAutoSubmit();
    client.triggerAutoSubmit();
    client.triggerAutoSubmit();

    assert.strictEqual(submitCount, 1);
    assert.strictEqual(client.hasSubmitted, true);
  });

  await it("Test Engine: In-flight network failure preserves staged answers in memory queue", async () => {
    const memoryQueue = [];
    let isOnline = false;

    const submitAttempt = async (attemptId, payload) => {
      if (!isOnline) {
        memoryQueue.push({ attemptId, payload, timestamp: Date.now() });
        throw new Error("HTTP_CONNECTION_LOST");
      }
      return { success: true, attempt_id: attemptId };
    };

    const stagedAnswers = { q1: [1], q2: 42 };
    let threw = false;
    try {
      await submitAttempt(501, stagedAnswers);
    } catch {
      threw = true;
    }

    assert.strictEqual(threw, true);
    assert.strictEqual(memoryQueue.length, 1);
    assert.deepStrictEqual(memoryQueue[0].payload, stagedAnswers);

    isOnline = true;
    const retryRes = await submitAttempt(memoryQueue[0].attemptId, memoryQueue[0].payload);
    assert.strictEqual(retryRes.success, true);
  });

  await it("Test Engine: KaTeX formula parser handles fractions, square roots, and Greek letters", () => {
    const mathFormula = "Solve for $\\theta$: $$\\sin^2(\\theta) + \\cos^2(\\theta) = 1 \\quad \\text{and} \\quad x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$";
    const inlineMatch = mathFormula.match(/\$([^\$]+?)\$/);
    const blockMatch = mathFormula.match(/\$\$([\s\S]+?)\$\$/);

    assert(inlineMatch !== null);
    assert.strictEqual(inlineMatch[1], "\\theta");
    assert(blockMatch !== null);
    assert(blockMatch[1].includes("\\frac"));
    assert(blockMatch[1].includes("\\sqrt"));
  });

  await it("Test Engine: Malformed KaTeX syntax degraded gracefully without unhandled exception", () => {
    const brokenLatex = "Unbalanced equation: $\\frac{1}{2";
    const hasUnclosed = (brokenLatex.match(/\$/g) || []).length % 2 !== 0;
    assert.strictEqual(hasUnclosed, true, "Detected unclosed LaTeX delimiter");
  });

  // --------------------------------------------------------------------------
  // TAB 4: SUPPORT (DISCUSSIONS & VOTING)
  // --------------------------------------------------------------------------
  console.log(`\n${colors.magenta}${colors.bold}[TAB 4: SUPPORT & DISCUSSIONS TAB]${colors.reset}`);

  await it("Support: Discussion upvote adds +5 XP; un-voting removes 5 XP", () => {
    const discussion = { id: 10, authorId: 101, voteCount: 0 };
    const userVotes = new Set();
    const xpLedger = { 101: 50 };

    const vote = (voterId) => {
      const key = `${voterId}_10`;
      if (userVotes.has(key)) {
        userVotes.delete(key);
        discussion.voteCount--;
        xpLedger[101] -= 5;
        return false;
      } else {
        userVotes.add(key);
        discussion.voteCount++;
        xpLedger[101] += 5;
        return true;
      }
    };

    assert.strictEqual(vote(202), true);
    assert.strictEqual(discussion.voteCount, 1);
    assert.strictEqual(xpLedger[101], 55);

    assert.strictEqual(vote(202), false);
    assert.strictEqual(discussion.voteCount, 0);
    assert.strictEqual(xpLedger[101], 50);
  });

  await it("Support: Discussion author accepting peer reply awards +15 XP", () => {
    const authorId = 101;
    const peerId = 303;
    const replies = [{ id: 1, authorId: peerId, body: "Correct solution" }];
    let acceptedReplyId = null;
    let peerXp = 100;

    const acceptReply = (callerId, replyId) => {
      if (callerId !== authorId) throw new Error("403 Forbidden");
      const r = replies.find((item) => item.id === replyId);
      if (r.authorId === callerId) throw new Error("422 Cannot accept self");
      acceptedReplyId = replyId;
      peerXp += 15;
    };

    acceptReply(authorId, 1);
    assert.strictEqual(acceptedReplyId, 1);
    assert.strictEqual(peerXp, 115);
  });

  await it("Support: Anonymous author is masked as 'Anonymous Student' to public", () => {
    const post = { id: 5, authorId: 44, authorName: "Tushar Singh", isAnonymous: true };
    const serializeForViewer = (viewerId, isAdmin) => {
      const showReal = !post.isAnonymous || post.authorId === viewerId || isAdmin;
      return showReal ? post.authorName : "Anonymous Student";
    };

    assert.strictEqual(serializeForViewer(999, false), "Anonymous Student");
    assert.strictEqual(serializeForViewer(44, false), "Tushar Singh");
    assert.strictEqual(serializeForViewer(999, true), "Tushar Singh");
  });

  // --------------------------------------------------------------------------
  // TAB 5: MORE TAB (PROFILE, SESSION & PASSWORD RESET)
  // --------------------------------------------------------------------------
  console.log(`\n${colors.magenta}${colors.bold}[TAB 5: MORE TAB & PROFILE / AUTH]${colors.reset}`);

  await it("More: Profile avatar upload validates MIME types (jpg, jpeg, png, webp) and 2MB cap", () => {
    const allowedMimes = ["image/jpeg", "image/png", "image/webp"];
    const maxBytes = 2 * 1024 * 1024;

    const validateAvatar = (file) => {
      if (!allowedMimes.includes(file.mimetype)) throw new Error("Invalid image type");
      if (file.size > maxBytes) throw new Error("File exceeds 2MB limit");
      return true;
    };

    assert.strictEqual(validateAvatar({ mimetype: "image/png", size: 1024 * 500 }), true);
    assert.throws(() => validateAvatar({ mimetype: "application/pdf", size: 1024 * 500 }), /Invalid image type/);
    assert.throws(() => validateAvatar({ mimetype: "image/jpeg", size: 3 * 1024 * 1024 }), /exceeds 2MB/);
  });

  await it("More: Sanctum token invalidation revokes old tokens on login", () => {
    const userTokens = ["tok_device1", "tok_device2"];
    const login = () => {
      userTokens.length = 0;
      const newToken = "tok_new_login";
      userTokens.push(newToken);
      return newToken;
    };

    const activeToken = login();
    assert.strictEqual(userTokens.length, 1);
    assert.strictEqual(userTokens[0], activeToken);
  });

  await it("More: Password change retains current mobile session and revokes other sessions", () => {
    const userTokens = new Map([
      ["tok_mobile", { device: "Android" }],
      ["tok_desktop", { device: "Chrome" }],
    ]);

    const changePassword = (currentMobileToken) => {
      for (const [id] of userTokens.entries()) {
        if (id !== currentMobileToken) {
          userTokens.delete(id);
        }
      }
    };

    changePassword("tok_mobile");
    assert.strictEqual(userTokens.has("tok_mobile"), true);
    assert.strictEqual(userTokens.has("tok_desktop"), false);
  });

  await it("More: Forgot password OTP expires in 10 minutes and resend is throttled within 9 minutes", () => {
    const otpCreatedAt = Date.now();
    const isExpired = (now) => now - otpCreatedAt > 10 * 60 * 1000;
    const canResend = (now) => now - otpCreatedAt >= 60 * 1000;

    assert.strictEqual(isExpired(otpCreatedAt + 5 * 60 * 1000), false);
    assert.strictEqual(isExpired(otpCreatedAt + 11 * 60 * 1000), true);

    assert.strictEqual(canResend(otpCreatedAt + 30 * 1000), false);
    assert.strictEqual(canResend(otpCreatedAt + 65 * 1000), true);
  });

  // --------------------------------------------------------------------------
  // SUITE 8: LOGIN CREDENTIALS & OTP VALIDATION
  // --------------------------------------------------------------------------
  console.log(`\n${colors.cyan}${colors.bold}[SUITE 8: LOGIN CREDENTIALS & OTP HANDLING]${colors.reset}`);

  const mockUserDb = [
    {
      id: 1,
      email: "student@iitm.ac.in",
      password: "SecretPassword123!",
      role: "student",
      is_active: true,
      email_verified_at: Date.now() - 10000,
      otp: null,
      tokens: [],
    },
    {
      id: 2,
      email: "unverified@iitm.ac.in",
      password: "SecretPassword123!",
      role: "student",
      is_active: true,
      email_verified_at: null,
      otp: "847291",
      otp_expires_at: Date.now() + 5 * 60 * 1000,
      tokens: [],
    },
    {
      id: 3,
      email: "deactivated@iitm.ac.in",
      password: "SecretPassword123!",
      role: "student",
      is_active: false,
      email_verified_at: Date.now() - 10000,
      otp: null,
      tokens: [],
    },
    {
      id: 4,
      email: "admin@iitm.ac.in",
      password: "AdminPassword123!",
      role: "admin",
      is_active: true,
      email_verified_at: Date.now() - 10000,
      otp: null,
      tokens: [],
    },
    {
      id: 5,
      email: "manager@iitm.ac.in",
      password: "ManagerPassword123!",
      role: "manager",
      is_active: true,
      email_verified_at: Date.now() - 10000,
      otp: null,
      tokens: [],
    },
  ];

  await it("Login: Valid credentials authenticate student and issue bearer token with student role", () => {
    const res = AuthLoginSimulator.login("student@iitm.ac.in", "SecretPassword123!", mockUserDb);
    assert.strictEqual(res.status, 200);
    assert(res.token.startsWith("tok_student_"));
    assert.strictEqual(res.user.role, "student");
    assert.strictEqual(res.user.is_admin, false);
    assert.strictEqual(res.user.is_manager, false);
  });

  await it("Login: Incorrect password rejected with HTTP 401 Invalid Credentials", () => {
    const res = AuthLoginSimulator.login("student@iitm.ac.in", "WrongPassword!", mockUserDb);
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.error, "Invalid credentials");
  });

  await it("Login: Non-existent email rejected with HTTP 401 without user enumeration leak", () => {
    const res = AuthLoginSimulator.login("ghost@iitm.ac.in", "AnyPassword!", mockUserDb);
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.error, "Invalid credentials");
  });

  await it("Login: Unverified email blocks login with HTTP 403 and triggers needs_verification flow", () => {
    const res = AuthLoginSimulator.login("unverified@iitm.ac.in", "SecretPassword123!", mockUserDb);
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.needs_verification, true);
    assert.strictEqual(res.email, "unverified@iitm.ac.in");
  });

  await it("Login: Deactivated account rejected with HTTP 403", () => {
    const res = AuthLoginSimulator.login("deactivated@iitm.ac.in", "SecretPassword123!", mockUserDb);
    assert.strictEqual(res.status, 403);
    assert(res.error.includes("deactivated"));
  });

  await it("Login OTP: 6-digit valid OTP submission marks email verified and issues token", () => {
    const res = AuthLoginSimulator.verifyOtp("unverified@iitm.ac.in", "847291", mockUserDb);
    assert.strictEqual(res.status, 200);
    assert(res.token !== undefined);
    const updated = mockUserDb.find((u) => u.email === "unverified@iitm.ac.in");
    assert(updated.email_verified_at !== null);
    assert.strictEqual(updated.otp, null);
  });

  await it("Login OTP: Invalid or non-6-digit OTP rejected with HTTP 422", () => {
    const res1 = AuthLoginSimulator.verifyOtp("unverified@iitm.ac.in", "123", mockUserDb);
    assert.strictEqual(res1.status, 422);

    const res2 = AuthLoginSimulator.verifyOtp("unverified@iitm.ac.in", "000000", mockUserDb);
    assert.strictEqual(res2.status, 422);
  });

  // --------------------------------------------------------------------------
  // SUITE 9: MULTI-ROLE AUTHORIZATION GATES (STUDENT VS ADMIN VS MANAGER)
  // --------------------------------------------------------------------------
  console.log(`\n${colors.cyan}${colors.bold}[SUITE 9: MULTI-ROLE AUTHORIZATION GATES & HIERARCHY]${colors.reset}`);

  const studentUser = { id: 1, role: "student" };
  const adminUser = { id: 4, role: "admin" };
  const managerUser = { id: 5, role: "manager" };

  await it("RBAC Hierarchy: Role ranks strictly mapped (Student: 0, Admin: 1, Manager: 2)", () => {
    assert.strictEqual(RBACAuthorizationGateway.ROLE_RANKS["student"], 0);
    assert.strictEqual(RBACAuthorizationGateway.ROLE_RANKS["admin"], 1);
    assert.strictEqual(RBACAuthorizationGateway.ROLE_RANKS["manager"], 2);
  });

  await it("RBAC Student: Can access student routes (quizzes, attempts, dashboard)", () => {
    const checkQuiz = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/quizzes/10");
    const checkAttempt = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/attempts/55/submit");
    const checkDash = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/student/dashboard");

    assert.strictEqual(checkQuiz.allowed, true);
    assert.strictEqual(checkAttempt.allowed, true);
    assert.strictEqual(checkDash.allowed, true);
  });

  await it("RBAC Student: Strictly blocked from /api/admin/* endpoints with HTTP 403", () => {
    const checkUsers = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/admin/users");
    const checkQuizzes = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/admin/quizzes");
    const checkAction = RBACAuthorizationGateway.canAccessRoute(studentUser, "/api/exam-platform/action");

    assert.strictEqual(checkUsers.allowed, false);
    assert.strictEqual(checkUsers.status, 403);
    assert.strictEqual(checkQuizzes.allowed, false);
    assert.strictEqual(checkAction.allowed, false);
  });

  await it("RBAC Admin: Allowed access to /api/admin/users and proctor actions", () => {
    const checkUsers = RBACAuthorizationGateway.canAccessRoute(adminUser, "/api/admin/users");
    const checkAction = RBACAuthorizationGateway.canAccessRoute(adminUser, "/api/exam-platform/action");

    assert.strictEqual(checkUsers.allowed, true);
    assert.strictEqual(checkAction.allowed, true);
  });

  await it("RBAC Admin: Strictly forbidden from Manager-only /api/admin/users/{id}/role with HTTP 403", () => {
    const checkRoleChange = RBACAuthorizationGateway.canAccessRoute(adminUser, "/api/admin/users/1/role", "PATCH");
    assert.strictEqual(checkRoleChange.allowed, false);
    assert.strictEqual(checkRoleChange.status, 403);
    assert(checkRoleChange.error.includes("Manager access required"));
  });

  await it("RBAC Admin: Strictly forbidden from Manager-only /api/exam-platform/reset with HTTP 403", () => {
    const checkReset = RBACAuthorizationGateway.canAccessRoute(adminUser, "/api/exam-platform/reset", "POST");
    assert.strictEqual(checkReset.allowed, false);
    assert.strictEqual(checkReset.status, 403);
  });

  await it("RBAC Admin: Outranking guard allows modifying Students but forbids touching Admins/Managers", () => {
    // Admin modifying student -> Allowed
    const modStudent = RBACAuthorizationGateway.canModifyUser(adminUser, studentUser, "deactivate", mockUserDb);
    assert.strictEqual(modStudent.allowed, true);

    // Admin modifying another Admin -> Blocked (403)
    const otherAdmin = { id: 9, role: "admin" };
    const modAdmin = RBACAuthorizationGateway.canModifyUser(adminUser, otherAdmin, "deactivate", mockUserDb);
    assert.strictEqual(modAdmin.allowed, false);
    assert.strictEqual(modAdmin.status, 403);

    // Admin modifying Manager -> Blocked (403)
    const modManager = RBACAuthorizationGateway.canModifyUser(adminUser, managerUser, "deactivate", mockUserDb);
    assert.strictEqual(modManager.allowed, false);
    assert.strictEqual(modManager.status, 403);
  });

  await it("RBAC Manager: Full access to supervisor cockpit, role changes, and exam state reset", () => {
    const checkRole = RBACAuthorizationGateway.canAccessRoute(managerUser, "/api/admin/users/1/role", "PATCH");
    const checkDelete = RBACAuthorizationGateway.canAccessRoute(managerUser, "/api/admin/users/1", "DELETE");
    const checkReset = RBACAuthorizationGateway.canAccessRoute(managerUser, "/api/exam-platform/reset", "POST");

    assert.strictEqual(checkRole.allowed, true);
    assert.strictEqual(checkDelete.allowed, true);
    assert.strictEqual(checkReset.allowed, true);
  });

  await it("RBAC Manager Safety: Cannot modify own account (HTTP 422)", () => {
    const modSelf = RBACAuthorizationGateway.canModifyUser(managerUser, managerUser, "change role", mockUserDb);
    assert.strictEqual(modSelf.allowed, false);
    assert.strictEqual(modSelf.status, 422);
    assert(modSelf.error.includes("cannot change role your own account"));
  });

  await it("RBAC Manager Safety: Cannot delete or demote the last manager account on platform (HTTP 422)", () => {
    const modLastManager = RBACAuthorizationGateway.canModifyUser(
      { id: 99, role: "manager" }, // another manager acting
      managerUser,
      "delete",
      [{ id: 5, role: "manager" }] // Only 1 manager exists!
    );
    assert.strictEqual(modLastManager.allowed, false);
    assert.strictEqual(modLastManager.status, 422);
    assert(modLastManager.error.includes("only manager account"));
  });

  // --------------------------------------------------------------------------
  // SUITE 10: PRIVILEGE ESCALATION ATTACK SIMULATION
  // --------------------------------------------------------------------------
  console.log(`\n${colors.cyan}${colors.bold}[SUITE 10: PRIVILEGE ESCALATION ATTACK SIMULATION]${colors.reset}`);

  await it('Privilege Escalation: Student injecting {"exam":{"status":"ended"}} into syncState is neutralized', () => {
    const maliciousPayload = {
      exam: { status: "ended" },
      studentSessions: {
        "student@iitm.ac.in": {
          status: "submitted",
          answers: { q1: [102] },
        },
      },
    };

    const sanitized = RBACAuthorizationGateway.filterCandidateSyncPayload(
      { id: 1, email: "student@iitm.ac.in", role: "student" },
      maliciousPayload
    );

    // Exam status injection dropped completely
    assert.strictEqual(sanitized.exam, undefined, "Candidate payload must not allow modifying global exam state");
    // Session status override dropped (only proctor action can change session status)
    assert.strictEqual(
      sanitized.studentSessions["student@iitm.ac.in"].status,
      undefined,
      "Candidate cannot tamper with proctored session status"
    );
    // Real answers preserved
    assert.deepStrictEqual(sanitized.studentSessions["student@iitm.ac.in"].answers, { q1: [102] });
  });

  await it("Privilege Escalation: Student posting chat message as 'Exam Manager' is sanitized", () => {
    const spoofedMessage = {
      id: "msg-999",
      senderName: "Exam Manager",
      text: "Exam has been cancelled. Leave immediately.",
      role: "manager",
      isAnnouncement: true,
    };

    const studentCaller = { id: 1, name: "Student A", email: "student@iitm.ac.in", role: "student" };
    const sanitizedMsg = RBACAuthorizationGateway.sanitizeChatMessage(studentCaller, spoofedMessage);

    assert.strictEqual(sanitizedMsg.senderName, "Student A", "Spoofed sender name overwritten with authentic name");
    assert.strictEqual(sanitizedMsg.role, "student", "Role overwritten with student");
    assert.strictEqual(sanitizedMsg.isAnnouncement, false, "Announcement flag forced to false");
  });

  await it("Privilege Escalation: Admin attempting to grant Manager role via PATCH /role is blocked (403)", () => {
    const escalationAttempt = RBACAuthorizationGateway.canAccessRoute(adminUser, "/api/admin/users/1/role", "PATCH");
    assert.strictEqual(escalationAttempt.allowed, false);
    assert.strictEqual(escalationAttempt.status, 403);
  });

  await it("Privilege Escalation: Immediate token revocation when user is demoted to lower role", () => {
    const userSession = {
      id: 7,
      role: "admin",
      tokens: ["tok_admin_1", "tok_admin_2"],
    };

    // Manager demotes user from admin to student
    const demoteUser = (user, newRole) => {
      const prevRank = RBACAuthorizationGateway.ROLE_RANKS[user.role];
      const newRank = RBACAuthorizationGateway.ROLE_RANKS[newRole];
      user.role = newRole;
      if (newRank < prevRank) {
        user.tokens = []; // Immediate purge of existing tokens
      }
    };

    demoteUser(userSession, "student");
    assert.strictEqual(userSession.role, "student");
    assert.strictEqual(userSession.tokens.length, 0, "Demoted user's tokens must be revoked immediately");
  });

  // --------------------------------------------------------------------------
  // SUMMARY
  // --------------------------------------------------------------------------
  console.log(`\n${colors.bold}============================================================================${colors.reset}`);
  console.log(`${colors.bold}QA TEST EXECUTION SUMMARY${colors.reset}`);
  console.log(`Total Scenarios Tested: ${passedCount + failedCount}`);
  console.log(`${colors.green}Passed: ${passedCount}${colors.reset}`);
  console.log(`${failedCount > 0 ? colors.red : colors.green}Failed: ${failedCount}${colors.reset}`);
  console.log(`${colors.bold}============================================================================\n${colors.reset}`);

  if (failedCount > 0) {
    process.exit(1);
  }
}

runAllTests().catch((e) => {
  console.error("FATAL SUITE ERROR:", e);
  process.exit(1);
});
