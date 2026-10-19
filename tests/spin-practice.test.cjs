const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const bundle = fs.readFileSync(path.join(root, "assets", "index-fad00dd6r.js"), "utf8");
const appEnhancements = fs.readFileSync(path.join(root, "app-enhancements.js"), "utf8");
const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");
const servePy = fs.readFileSync(path.join(root, "serve.py"), "utf8");
const serverJs = fs.readFileSync(path.join(root, "server.js"), "utf8");
const dashboardCss = fs.readFileSync(path.join(root, "storefront-dashboard.css"), "utf8");
const darkCss = fs.readFileSync(path.join(root, "ql-dark-app.css"), "utf8");
const apiRoutes = fs.readFileSync(path.join(root, "backend", "routes", "api.php"), "utf8");
const controllerPath = path.join(root, "backend", "app", "Http", "Controllers", "StudentSpinPracticeController.php");

// 1. Bundle verification
assert.ok(
  bundle.includes('{to:`/try-practice`,label:`Test yourself`,Icon:ec}'),
  "React navigation items list (_c) must include /try-practice tab"
);
assert.ok(
  bundle.includes('path:`/try-practice`,element:(0,F.jsx)(`div`,{id:`ql-try-practice`})'),
  "React router must include /try-practice route with #ql-try-practice container"
);
assert.ok(
  bundle.includes('e===`/try-practice`?`Test yourself`'),
  "React route title lookup must handle /try-practice"
);

// 2. App enhancements verification
assert.ok(
  appEnhancements.includes("function syncTryPracticeNav()"),
  "app-enhancements.js must define syncTryPracticeNav"
);
assert.ok(
  appEnhancements.includes("function fillTryPractice()"),
  "app-enhancements.js must define fillTryPractice"
);
assert.ok(
  appEnhancements.includes("ql-spin-canvas"),
  "app-enhancements.js must create and control the spin wheel canvas"
);
assert.ok(
  appEnhancements.includes("ql-spin-week-min") && appEnhancements.includes("ql-spin-week-max"),
  "app-enhancements.js must support week 1-12 range sliders"
);
assert.ok(
  appEnhancements.includes("courseSelect.reportValidity()"),
  "app-enhancements.js must validate course selection before spinning"
);
assert.ok(
  appEnhancements.includes("/student/spin-practice"),
  "app-enhancements.js must call the /student/spin-practice API"
);
assert.ok(
  appEnhancements.includes("fillTryPractice();") && appEnhancements.includes("syncTryPracticeNav();"),
  "app-enhancements.js run() function must execute fillTryPractice and syncTryPracticeNav"
);

const spinSource = appEnhancements.slice(appEnhancements.indexOf('  function fillTryPractice() {'), appEnhancements.indexOf('   * Practice: paid papers'));
assert.ok(spinSource.includes('Generate 10 random question'), 'Use the requested concise subtitle');
assert.ok(!spinSource.includes('ql-spin-preset-btn'), 'Week preset buttons are removed');
assert.ok(!spinSource.includes('ql-spin-time-btn') && !spinSource.includes('time_limit_minutes:'), 'Time is chosen in the paper room');
assert.ok(spinSource.includes('value="quiz1"') && spinSource.includes('value="mock_test"'), 'Expose individual paper types for multiple selection');

// 3. Backend & API routes verification
assert.ok(
  fs.existsSync(controllerPath),
  "StudentSpinPracticeController.php must exist"
);
assert.ok(
  apiRoutes.includes("StudentSpinPracticeController::class, 'generate'"),
  "api.php must register the POST /student/spin-practice route"
);

// 4. Server routes verification
assert.ok(
  servePy.includes("try-practice|spin-practice"),
  "serve.py must match try-practice in APP_ROUTES"
);
assert.ok(
  serverJs.includes("try-practice|spin-practice"),
  "server.js must match try-practice in appRoutes"
);

// 5. Styles & Dark mode
assert.ok(
  dashboardCss.includes(".ql-spin-container") && dashboardCss.includes(".ql-wheel-stage"),
  "storefront-dashboard.css must include .ql-spin-container and .ql-wheel-stage"
);
assert.ok(
  darkCss.includes(":root[data-theme=dark] .ql-spin-wheel-card") || darkCss.includes(":root[data-theme=dark] .ql-spin-custom-card"),
  "ql-dark-app.css must include dark mode styling for spin practice"
);

// 6. Cache busters
assert.ok(
  /\/assets\/index-fad00dd6r\.js\?v=2026101[89][a-z0-9_-]*/.test(indexHtml),
  "index.html must reference refreshed bundle query parameter"
);
assert.ok(
  /\/app-enhancements\.js\?v=2026101[89][a-z0-9_-]*/.test(indexHtml),
  "index.html must reference refreshed app-enhancements.js query parameter"
);

console.log("PASS: Spin wheel Test yourself, customization sliders, API routes, and styles verified successfully.");
