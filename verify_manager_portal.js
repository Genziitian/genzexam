const http = require("http");
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const BASE_URL = "http://localhost:3000";
const JS_FILE = path.join(__dirname, "exam-platform.js");

async function checkUrl(urlPath) {
  return new Promise((resolve, reject) => {
    http.get(`${BASE_URL}${urlPath}`, (res) => {
      let data = [];
      res.on("data", (chunk) => data.push(chunk));
      res.on("end", () => {
        resolve({
          path: urlPath,
          statusCode: res.statusCode,
          contentType: res.headers["content-type"],
          size: Buffer.concat(data).length
        });
      });
    }).on("error", (err) => reject(err));
  });
}

async function run() {
  console.log("=================================================");
  console.log("IITM BS Degree Assessment - Manager Portal Verifier");
  console.log("=================================================\n");

  // ----------------------------------------------------------------
  // 1. HTTP Server & Assets 200 OK Check
  // ----------------------------------------------------------------
  console.log("[SECTION 1] Checking Assets and JS Bundles on http://localhost:3000...");
  const assetPaths = [
    "/",
    "/index.html",
    "/exam-platform.js",
    "/exam-platform.css",
    "/assets/index-Bdi1qGGs.js",
    "/assets/index-BMttrsnx.css",
    "/assets/genz-logo.png",
    "/favicon.ico",
    "/favicon-16x16.png",
    "/favicon-32x32.png",
    "/apple-touch-icon.png",
    "/site.webmanifest"
  ];

  let assetFailures = 0;
  for (const p of assetPaths) {
    try {
      const res = await checkUrl(p);
      if (res.statusCode === 200) {
        console.log(`  ✓ 200 OK: ${p.padEnd(30)} [${res.size} bytes]`);
      } else {
        console.error(`  ✗ FAIL: ${p} returned HTTP ${res.statusCode}`);
        assetFailures++;
      }
    } catch (err) {
      console.error(`  ✗ FAIL: ${p} could not be reached: ${err.message}`);
      assetFailures++;
    }
  }
  assert.strictEqual(assetFailures, 0, "All assets must return HTTP 200 OK");
  console.log("✓ All 12 web assets and bundles verified cleanly with 200 OK.\n");

  // ----------------------------------------------------------------
  // 2. Static and Modal Architecture Verification
  // ----------------------------------------------------------------
  console.log("[SECTION 2] Verifying Manager Double Confirmation Modal Engine...");
  const code = fs.readFileSync(JS_FILE, "utf8");

  // Zero native confirm() calls
  const confirmMatches = code.match(/\bconfirm\s*\(/g);
  assert.strictEqual(confirmMatches, null, "Zero native browser confirm() dialogs allowed");
  console.log("  ✓ Zero native browser confirm() dialogs found");

  // Modal Function & IDs
  assert.ok(code.includes("function showManagerConfirmModal"), "showManagerConfirmModal must be defined");
  assert.ok(code.includes('id = "ep-manager-confirm-modal"'), "Modal container ID must be ep-manager-confirm-modal");
  assert.ok(code.includes("Accidental Touch Guard"), "Modal must display Accidental Touch Guard indicator");
  assert.ok(code.includes('id="ep-mgr-modal-confirm"'), "Modal must render Confirm button ep-mgr-modal-confirm");
  assert.ok(code.includes('id="ep-mgr-modal-cancel"'), "Modal must render Cancel button ep-mgr-modal-cancel");
  assert.ok(code.includes('id="ep-mgr-modal-check"'), "Modal must render Checkbox when requireCheckbox is set");
  assert.ok(code.includes("canConfirm = false"), "Modal must implement debounce accidental touch lock");
  console.log("  ✓ showManagerConfirmModal architectural elements verified (Touch Guard, Checkbox, 200ms lock, Cancel/Confirm)");

  // ----------------------------------------------------------------
  // 3. Verify Every Manager Action Triggers showManagerConfirmModal
  // ----------------------------------------------------------------
  console.log("\n[SECTION 3] Verifying Every Manager Action Handler Triggers showManagerConfirmModal...");

  const actions = [
    {
      name: "ep-mgr-toggle-type (Switch Mode)",
      pattern: /btnToggleType\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Switch Mode to/
    },
    {
      name: "ep-mgr-publish-results (Publish Results)",
      pattern: /btnPublish\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*willPublish/
    },
    {
      name: "ep-mgr-export-csv (Export CSV)",
      pattern: /btnExportCSV\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Export Candidate Records as CSV"/
    },
    {
      name: "ep-mgr-pause (Pause Examination)",
      pattern: /btnPause\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Pause Examination"/
    },
    {
      name: "ep-mgr-resume (Resume Examination)",
      pattern: /btnResume\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Resume Examination"/
    },
    {
      name: "ep-mgr-start (Start Live Examination)",
      pattern: /btnStart\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Start Live Examination"/
    },
    {
      name: "ep-mgr-ext-5, ep-mgr-ext-10, ep-mgr-ext-15 (Extend Time)",
      pattern: /\[5,\s*10,\s*15\]\.forEach\(\(mins\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Extend Exam Time/
    },
    {
      name: "ep-mgr-end (End Exam with explicit confirmation checkbox)",
      pattern: /btnEnd\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"End Live Examination"[\s\S]*?requireCheckbox:\s*true/
    },
    {
      name: "btn-mgr-lock-session (Lock Session)",
      pattern: /\.btn-mgr-lock-session"\)\.forEach\(\(btn\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Lock Session:/
    },
    {
      name: "btn-mgr-approve-reentry (Approve Re-entry from monitor table)",
      pattern: /\.btn-mgr-approve-reentry"\)\.forEach\(\(btn\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Approve Re-entry:/
    },
    {
      name: "btn-approve-request (Approve Request from queue)",
      pattern: /\.btn-approve-request"\)\.forEach\(\(btn\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Approve Candidate Re-entry`/
    },
    {
      name: "btn-reject-request (Reject Request from queue)",
      pattern: /\.btn-reject-request"\)\.forEach\(\(btn\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Reject Candidate Re-entry`/
    },
    {
      name: "btn-add-whitelist (Add Whitelist Email)",
      pattern: /btnAdd\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Add Candidate to Whitelist"/
    },
    {
      name: "btn-remove-whitelist (Remove Whitelist Email)",
      pattern: /\.btn-remove-whitelist"\)\.forEach\(\(btn\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*`Revoke Whitelist Access`/
    },
    {
      name: "ep-mgr-chat-send (Broadcast Announcement)",
      pattern: /btnSend\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Broadcast Announcement"/
    },
    {
      name: "ep-btn-reset-demo (Reset Platform with explicit confirmation checkbox)",
      pattern: /btnReset\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Reset Examination Platform"[\s\S]*?requireCheckbox:\s*true/
    },
    {
      name: "ep-btn-switch-role (Guard when in Manager View)",
      pattern: /btnSwitch\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?if\s*\(isManager\)\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Switch to Student View"/
    },
    {
      name: "ep-btn-back-login (Guard when in Manager View)",
      pattern: /btnBackLogin\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?if\s*\(isManager\)\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Return to Sign In Portal"/
    },
    {
      name: "ep-mgr-btn-broadcast-nav (Quickbar Switch to Broadcast Channel)",
      pattern: /btnBcast\.onclick\s*=\s*\(\)\s*=>\s*\{[\s\S]*?showManagerConfirmModal\(\{[\s\S]*?title:\s*"Switch to Broadcast Channel"/
    }
  ];

  for (const action of actions) {
    const matched = action.pattern.test(code);
    assert.ok(matched, `Action '${action.name}' must trigger showManagerConfirmModal`);
    console.log(`  ✓ Verified: ${action.name}`);
  }

  console.log(`\n✓ All ${actions.length} Manager actions verified to trigger showManagerConfirmModal with double confirmation protection.`);
  console.log("=================================================");
  console.log("Verification Summary: 100% PASSED (0 errors, 0 warnings)");
  console.log("=================================================");
}

run().catch((err) => {
  console.error("Verification failed:", err);
  process.exit(1);
});
