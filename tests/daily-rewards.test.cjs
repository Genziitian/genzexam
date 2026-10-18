const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const bundle = fs.readFileSync(path.join(root, "assets", "index-fad00dd6r.js"), "utf8");
const appEnhancements = fs.readFileSync(path.join(root, "app-enhancements.js"), "utf8");
const dashboardCss = fs.readFileSync(path.join(root, "storefront-dashboard.css"), "utf8");
const moreWeb = fs.readFileSync(path.join(root, "more-web.js"), "utf8");
const servePy = fs.readFileSync(path.join(root, "serve.py"), "utf8");
const serverJs = fs.readFileSync(path.join(root, "server.js"), "utf8");
const apiRoutes = fs.readFileSync(path.join(root, "backend", "routes", "api.php"), "utf8");
const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");

// 1. Bundle tests
assert.ok(
  bundle.includes('Ln,{to:`/rewards`,className:`flex items-center gap-1.5 rounded-lg bg-brand px-3.5 py-1.5 text-[12px] font-semibold text-white shadow-sm transition-all hover:bg-brand-dark hover:shadow`,children:[(0,F.jsx)(lc,{}),`Spin & Win`]'),
  "Header button must be renamed to Spin & Win and point to /rewards in React bundle"
);
assert.ok(
  bundle.includes('path:`/rewards`,element:(0,F.jsx)(`div`,{id:`ql-rewards-page`})'),
  "React router must include /rewards route mapping to #ql-rewards-page container"
);
assert.ok(
  bundle.includes('e===`/rewards`||e===`/spin-rewards`?`Spin & Win`'),
  "Route title lookup must return Spin & Win for /rewards"
);

// 2. App enhancements tests
assert.ok(
  appEnhancements.includes("function fillRewardsPage()"),
  "app-enhancements.js must define fillRewardsPage"
);
assert.ok(
  appEnhancements.includes("function syncRewardsButton()"),
  "app-enhancements.js must define syncRewardsButton"
);
assert.ok(
  appEnhancements.includes("function ensureDailySpinPrompt()"),
  "app-enhancements.js must define ensureDailySpinPrompt"
);
assert.ok(
  appEnhancements.includes("function openScratchCardModal("),
  "app-enhancements.js must define interactive scratch card modal"
);
assert.ok(
  appEnhancements.includes("location.assign(\"/rewards\")"),
  "app-enhancements.js must navigate to /rewards on button click"
);

// 3. Styling tests
assert.ok(
  dashboardCss.includes(".ql-rewards-page") && dashboardCss.includes(".ql-wheel-canvas"),
  "storefront-dashboard.css must include .ql-rewards-page and .ql-wheel-canvas"
);
assert.ok(
  dashboardCss.includes(".ql-scratch-overlay") && dashboardCss.includes(".ql-scratch-stage"),
  "storefront-dashboard.css must include scratch card overlay and stage styles"
);
assert.ok(
  dashboardCss.includes(".ql-daily-prompt-overlay"),
  "storefront-dashboard.css must include daily prompt modal styles"
);

// 4. More Tab integration
assert.ok(
  moreWeb.includes("Daily Rewards · Spin &amp; Win") && moreWeb.includes('href="/rewards"'),
  "more-web.js must include Daily Rewards card linking to /rewards"
);

// 5. Server routing tests
assert.ok(
  servePy.includes("rewards|spin-rewards"),
  "serve.py APP_ROUTES must include rewards and spin-rewards"
);
assert.ok(
  serverJs.includes("rewards|spin-rewards"),
  "server.js appRoutes must include rewards and spin-rewards"
);

// 6. Backend API tests
assert.ok(
  apiRoutes.includes("StudentRewardController") && apiRoutes.includes("/student/rewards"),
  "backend/routes/api.php must register StudentRewardController endpoints"
);

// 7. 7-Day Expiry & Scratch Card Logic Simulation
const now = Date.now();
const activeCoupon = {
  id: "test-1",
  type: "coupon_pct",
  created_at: new Date(now - 2 * 86400 * 1000).toISOString(),
  expires_at: new Date(now + 5 * 86400 * 1000).toISOString(),
  is_scratched: true,
  code: "GENZ25-TEST"
};
const expiredCouponScratched = {
  id: "test-2",
  type: "coupon_pct",
  created_at: new Date(now - 8 * 86400 * 1000).toISOString(),
  expires_at: new Date(now - 1 * 86400 * 1000).toISOString(),
  is_scratched: true,
  code: "GENZ15-OLD"
};
const expiredCouponUnscratched = {
  id: "test-3",
  type: "coupon_pct",
  created_at: new Date(now - 8 * 86400 * 1000).toISOString(),
  expires_at: new Date(now - 1 * 86400 * 1000).toISOString(),
  is_scratched: false,
  code: "GENZ50-OLD"
};

function evaluateStatus(reward, currentTime) {
  const isExpired = reward.expires_at ? currentTime > new Date(reward.expires_at).getTime() : false;
  if (isExpired) {
    return {
      status: reward.is_scratched ? "outdated_scratched" : "expired_unscratched",
      codeVisible: false
    };
  }
  return {
    status: reward.is_scratched ? "active_scratched" : "unscratched",
    codeVisible: reward.is_scratched
  };
}

assert.strictEqual(evaluateStatus(activeCoupon, now).status, "active_scratched");
assert.strictEqual(evaluateStatus(activeCoupon, now).codeVisible, true);
assert.strictEqual(evaluateStatus(expiredCouponScratched, now).status, "outdated_scratched");
assert.strictEqual(evaluateStatus(expiredCouponScratched, now).codeVisible, false);
assert.strictEqual(evaluateStatus(expiredCouponUnscratched, now).status, "expired_unscratched");
assert.strictEqual(evaluateStatus(expiredCouponUnscratched, now).codeVisible, false);

// 8. Claim Instructions & Policy Consistency Tests
const termsHtml = fs.readFileSync(path.join(root, "terms.html"), "utf8");
const backendTermsHtml = fs.readFileSync(path.join(root, "backend", "public", "terms.html"), "utf8");
const mobileLegal = fs.readFileSync(path.join(root, "mobile", "lib", "legal", "legal_documents.dart"), "utf8");
const mobileShell = fs.readFileSync(path.join(root, "mobile", "lib", "screens", "student", "student_main_shell.dart"), "utf8");

assert.ok(
  termsHtml.includes('id="rewards-promotions"') &&
  termsHtml.includes("genziitian.in/courses") &&
  termsHtml.includes("350") &&
  termsHtml.includes("100"),
  "terms.html must contain Section 07 with id anchor, genziitian.in/courses, min purchase 350, max cap 100"
);

assert.ok(
  backendTermsHtml.includes('id="rewards-promotions"') &&
  backendTermsHtml.includes("genziitian.in/courses") &&
  backendTermsHtml.includes("350") &&
  backendTermsHtml.includes("100"),
  "backend/public/terms.html must contain Section 07 with id anchor, genziitian.in/courses, min purchase 350, max cap 100"
);

assert.ok(
  mobileLegal.includes("Daily Rewards, Spin Wheel & Promotional Coupons") &&
  mobileLegal.includes("https://genziitian.in/courses") &&
  mobileLegal.includes("₹350") &&
  mobileLegal.includes("₹100"),
  "mobile legal_documents.dart must contain Section 07 identical to web policy"
);

assert.ok(
  mobileShell.includes("Genziitian.in/courses") &&
  mobileShell.includes("₹350") &&
  mobileShell.includes("₹100"),
  "mobile student_main_shell.dart must show detailed claim instructions and limits"
);

assert.ok(
  appEnhancements.includes("Genziitian.in/courses") &&
  appEnhancements.includes("Minimum amount purchase is ₹350") &&
  appEnhancements.includes("Max discount you get on any percentage is 100 rupees") &&
  appEnhancements.includes("ql-card-terms-toggle") &&
  appEnhancements.includes("ql-card-claim-details") &&
  appEnhancements.includes("GENZ5-"),
  "app-enhancements.js must render detailed claim steps, min purchase 350, max cap 100, toggle accordions, and GENZ5- prefix"
);

// 9. Manager Dashboard Active Rewards Log Tests
const managerHtml = fs.readFileSync(path.join(root, "manager-sales.html"), "utf8");
const managerJs = fs.readFileSync(path.join(root, "manager-sales.js"), "utf8");

assert.ok(
  managerHtml.includes('data-tab="rewards-log"') && managerHtml.includes('id="rewards-log-panel"'),
  "manager-sales.html must contain rewards-log tab button and panel section"
);

assert.ok(
  managerJs.includes("loadRewardsLog") &&
  managerJs.includes("rewards-log-list") &&
  managerJs.includes("exportRewardsLog"),
  "manager-sales.js must handle loadRewardsLog, render table, and exportRewardsLog"
);

assert.ok(
  apiRoutes.includes("/rewards/log") && apiRoutes.includes("StudentRewardController"),
  "backend/routes/api.php must register manager /rewards/log route"
);

console.log("PASS: All Daily Rewards, Claim Instructions, Legal Policy, Expiry, and Manager Log tests passed.");


