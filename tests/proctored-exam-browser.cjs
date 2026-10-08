"use strict";
// Run against tests/support/exam-browser-server.php with a fresh temporary fixture.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");
const base = process.env.EXAM_TEST_URL || "http://127.0.0.1:8137";
assert.match(base, /^http:\/\/(127\.0\.0\.1|localhost):\d+$/);
const tokens = JSON.parse(
  fs.readFileSync(path.join(process.env.EXAM_TEST_DIR, "tokens.json")),
);
const root = path.resolve(__dirname, "..");
(async () => {
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.CHROME_PATH
      ? { executablePath: process.env.CHROME_PATH }
      : {}),
  });
  const errors = [];
  async function pageFor(role) {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 1000 },
    });
    await context.addInitScript(
      (t) => localStorage.setItem("lab_token", t),
      tokens[role],
    );
    const page = await context.newPage();
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("dialog", (d) => d.accept());
    await page.goto(`${base}/exams`);
    return page;
  }
  async function click(p, action) {
    await p.locator(`[data-action="${action}"]`).first().click();
  }
  async function goToQuestion(p, questions, questionId) {
    const index = questions.findIndex((question) => question.id === questionId);
    assert.notEqual(index, -1, `Question ${questionId} is missing from the template.`);
    await p.locator(`[data-room-go="${index}"]`).click();
    await p
      .locator(`.ep-question[data-question-id="${questionId}"]`)
      .waitFor({ state: "visible" });
  }
  async function saveAnswerAndWait(p, change) {
    const saved = p.waitForResponse((response) => {
      const url = new URL(response.url());
      return (
        url.pathname.endsWith("/answers") &&
        response.request().method() === "PATCH" &&
        response.ok()
      );
    });
    await change();
    await saved;
  }
  async function api(role, suffix, body, method = "POST") {
    const r = await fetch(`${base}/public/api/exam-platform${suffix}`, {
      method,
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${tokens[role]}`,
        "Content-Type": "application/json",
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const data = await r.json();
    assert.ok(r.ok, JSON.stringify(data));
    return data;
  }
  const mobileContext = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1" });
  await mobileContext.addInitScript((t) => localStorage.setItem("lab_token", t), tokens.student);
  const mobilePage = await mobileContext.newPage();
  await mobilePage.goto(`${base}/exams`);
  await mobilePage.getByRole("heading", { name: "Use a laptop or desktop" }).waitFor();
  assert.equal(await mobilePage.locator(".ep-question").count(), 0);
  await mobileContext.close();
  const manager = await pageFor("manager");
  try {
    await click(manager, "new");
    await manager.locator("[name=title]").fill("Browser math & statistics");
    await manager.locator("[name=duration_minutes]").fill("10");
    await manager.locator("[name=max_warnings]").fill("100");
    await manager
      .getByRole("button", { name: "Save draft", exact: true })
      .click();
    await manager.getByRole("heading", { name: "Configure exam" }).waitFor();
    const template = JSON.parse(
      fs.readFileSync(
        path.join(root, "templates/proctored-exam-template.json"),
      ),
    );
    await manager.locator("#ep-import-json").fill(JSON.stringify(template));
    await click(manager, "preview-import");
    await manager.locator(".ep-preview .katex").first().waitFor();
    assert.equal(
      await manager.locator(".ep-preview-q").count(),
      template.questions.length,
    );
    await click(manager, "import");
    await manager
      .locator("#ep-toast")
      .filter({ hasText: "Questions imported" })
      .waitFor();
    await manager.locator("#ep-enrollment-list").fill("student@example.test");
    await click(manager, "save-enrollments");
    await manager
      .locator("#ep-toast")
      .filter({ hasText: "enrollment saved" })
      .waitFor();
    await click(manager, "publish");
    await manager
      .locator(".saas-title")
      .filter({ hasText: "Browser math & statistics" })
      .waitFor();
    const { exams } = await api("manager", "/exams", null, "GET");
    const id = exams.find((e) => e.title === "Browser math & statistics").id;
    const student = await pageFor("student");
    await click(student, "open");
    await student.waitForTimeout(500);
    assert.equal(
      await student.locator(".ep-student-detail").count(),
      1,
      `Candidate exam detail did not render: ${await student.locator("#ep-content").innerText()}`,
    );
    await student
      .getByText("This exam has not started yet", { exact: true })
      .waitFor();
    assert.equal(await student.locator("[data-action=join]").count(), 0);
    assert.equal(await student.locator('[data-action="refresh-state"]').count(), 1);
    assert.equal(await student.locator(".ep-question").count(), 0);
    await click(manager, "start");
    await manager.locator(".saas-status-pill.live").first().waitFor();
    await student.reload();
    await click(student, "open");
    await click(student, "join");
    await click(student, "onboard-step-2");
    await click(student, "onboard-step-3");
    await click(student, "take-selfie");
    await click(student, "onboard-step-4");
    await student.locator("#ep-cb-agree").check();
    await click(student, "join-confirm");
    await student.locator(".ep-question").first().waitFor();
    assert.equal(
      await student.locator(".ep-question").count(),
      template.questions.length,
    );
    assert.ok((await student.locator(".ep-question .katex").count()) > 10);
    assert.ok((await student.locator(".ep-question table").count()) > 0);
    await goToQuestion(student, template.questions, "diagram-identification");
    const diagram = student.locator(
      '.ep-question[data-question-id="diagram-identification"] img',
    );
    await diagram.scrollIntoViewIfNeeded();
    await diagram.evaluate((img) => img.decode());
    assert.ok((await diagram.evaluate((img) => img.naturalWidth)) > 0);
    assert.equal(
      await student.evaluate(() => {
        const div = document.createElement("div");
        div.innerHTML = ExamRichContent.render(
          "<img src=x onerror=alert(1)> $\\href{javascript:alert(1)}{bad}$",
        );
        ExamRichContent.typeset(div);
        return div.querySelectorAll("img,script,a[href^=javascript]").length;
      }),
      0,
    );
    await goToQuestion(student, template.questions, "algebra-single");
    await student.locator('[data-answer="algebra-single"][value="2"]').check();
    await goToQuestion(student, template.questions, "mean-number");
    await saveAnswerAndWait(student, () =>
      student.locator('[data-answer-text="mean-number"]').fill("7"),
    );
    let state = await api("student", `/exams/${id}/state`, null, "GET");
    assert.equal(state.session.answers["algebra-single"], 2);
    assert.equal(state.session.answers["mean-number"], 7);
    assert.ok(
      state.exam.questions.every(
        (q) =>
          !Object.hasOwn(q, "correct_answer") &&
          !Object.hasOwn(q, "explanation"),
      ),
    );
    // Simulate a network interruption for answer writes, then recover without editing again.
    await student.route("**/answers", (route) => route.abort("failed"));
    const failedSave = student.waitForRequestFailed((request) =>
      new URL(request.url()).pathname.endsWith("/answers"),
    );
    await student.locator('[data-answer-text="mean-number"]').fill("8");
    await failedSave;
    await student.unroute("**/answers");
    await saveAnswerAndWait(student, async () => student.waitForTimeout(5100));
    assert.equal(
      (await api("student", `/exams/${id}/state`, null, "GET")).session.answers[
        "mean-number"
      ],
      8,
    );
    // Simultaneous session update must not erase a different answer.
    state = await api("student", `/exams/${id}/state`, null, "GET");
    await api(
      "student",
      `/exams/${id}/answers`,
      { answers: { "algebra-single": 1 }, revision: state.session.revision },
      "PATCH",
    );
    await saveAnswerAndWait(student, () =>
      student.locator('[data-answer-text="mean-number"]').fill("7"),
    );
    state = await api("student", `/exams/${id}/state`, null, "GET");
    assert.equal(state.session.answers["algebra-single"], 1);
    assert.equal(state.session.answers["mean-number"], 7);
    // Pause freezes countdown and prevents edits. Resume preserves answers.
    await click(manager, "pause");
    await student.locator(".ep-status.paused").waitFor({ timeout: 15000 });
    const paused = await student.locator("#ep-countdown").textContent();
    await student.waitForTimeout(1200);
    assert.equal(await student.locator("#ep-countdown").textContent(), paused);
    assert.equal(
      await student.locator('[data-answer-text="mean-number"]').isDisabled(),
      true,
    );
    await click(manager, "resume");
    await student.locator(".ep-status.live").waitFor({ timeout: 15000 });
    await click(manager, "refresh-state");
    await click(manager, "lock");
    await student
      .getByText("Your session is locked.", { exact: false })
      .waitFor({ timeout: 15000 });
    await click(manager, "unlock");
    await student
      .locator('[data-answer-text="mean-number"]:enabled')
      .waitFor({ timeout: 15000 });
    // Refresh recovers server-saved answers and active-room monitoring.
    await student.goto(`${base}/exams/${id}`);
    await student.locator(".ep-question").first().waitFor();
    assert.equal(
      await student.locator('[data-answer-text="mean-number"]').inputValue(),
      "7",
    );
    await goToQuestion(student, template.questions, "algebra-single");
    await saveAnswerAndWait(student, () =>
      student.locator('[data-answer="algebra-single"][value="2"]').check(),
    );
    await goToQuestion(student, template.questions, "diagram-identification");
    await student
      .locator('.ep-question[data-question-id="diagram-identification"] img')
      .evaluate((img) => img.decode());
    await student.screenshot({
      path: path.join(process.env.EXAM_TEST_DIR, "candidate-room.png"),
      fullPage: true,
    });
    await student.setViewportSize({ width: 390, height: 844 });
    assert.ok(
      await student.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth + 1,
      ),
    );
    await student.screenshot({
      path: path.join(process.env.EXAM_TEST_DIR, "candidate-mobile.png"),
      fullPage: true,
    });
    await student.setViewportSize({ width: 1440, height: 1000 });
    await click(student, "submit-exam");
    await student.getByText("SUBMISSION RECEIVED", { exact: true }).waitFor();
    assert.equal(await student.locator(".ep-result-score").count(), 0);
    await click(manager, "end");
    await click(manager, "publish-results");
    await student.locator(".ep-result-score").waitFor({ timeout: 15000 });
    await student
      .getByRole("heading", { name: "Answer review", exact: true })
      .waitFor();
    const csv = await fetch(
      `${base}/public/api/exam-platform/exams/${id}/export`,
      {
        headers: {
          Authorization: `Bearer ${tokens.manager}`,
          Accept: "text/csv",
        },
      },
    );
    assert.equal(csv.status, 200);
    assert.match(await csv.text(), /student@example.test/);
    await click(manager, "audit");
    await manager
      .locator("#ep-audit")
      .filter({ hasText: "exam.action.publish_results" })
      .waitFor();
    await manager.screenshot({
      path: path.join(process.env.EXAM_TEST_DIR, "manager-results.png"),
      fullPage: true,
    });
    assert.deepEqual(errors, []);
    console.log(
      `PASS: real API + browser manager creation/import/roster/publish/start, candidate math rendering, save recovery/conflicts, pause/resume/lock/refresh/submit/results, CSV, audit (${template.questions.length} rich questions).`,
    );
  } catch (e) {
    await manager.screenshot({
      path: path.join(process.env.EXAM_TEST_DIR, "failure.png"),
      fullPage: true,
    });
    throw e;
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
