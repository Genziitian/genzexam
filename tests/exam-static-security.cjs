"use strict";
const assert = require("node:assert/strict");
const http = require("node:http");
const { handler } = require("../server.js");
(async () => {
  const server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const path of [
      "/backend/.env",
      "/backend/composer.json",
      "/.git/config",
      "/data/exam-platform-state.json",
      "/tests/support/exam-browser-server.php",
      "/mobile/lib/main.dart",
      "/server.js",
      "/serve.py",
      "/assets/vendor/katex/package.json",
      "/assets/%2e%2e/backend/.env",
    ])
      assert.equal((await fetch(base + path)).status, 404, path);
    for (const path of ["/api/state", "/public/api/exam-platform/state"])
      assert.equal((await fetch(base + path)).status, 503, path);
    const exam = await fetch(base + "/exams");
    assert.equal(exam.status, 200);
    assert.match(await exam.text(), /Content-Security-Policy/);
    assert.equal(exam.headers.get("x-content-type-options"), "nosniff");
    assert.equal(
      (await fetch(base + "/exam-platform.js", { method: "POST" })).status,
      405,
    );
    assert.equal(
      (await fetch(base + "/templates/proctored-exam-template.json")).status,
      200,
    );
    assert.equal(
      (await fetch(base + "/assets/vendor/katex/katex.min.js")).status,
      200,
    );
    console.log(
      "PASS: private files blocked, local demo API disabled, dedicated exam route and security headers.",
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
