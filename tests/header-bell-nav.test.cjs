const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const bundle = fs.readFileSync(path.join(root, "assets", "index-fad00dd6r.js"), "utf8");
const appEnhancements = fs.readFileSync(path.join(root, "app-enhancements.js"), "utf8");
const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");

// 1. Bundle verification
assert.ok(
  bundle.includes('Ln,{to:`/practice`,className:`flex items-center gap-1.5 rounded-lg bg-brand px-3.5 py-1.5 text-[12px] font-semibold text-white shadow-sm transition-all hover:bg-brand-dark hover:shadow`,children:[(0,F.jsx)(lc,{}),`Daily challenge`]'),
  "Daily challenge must route to /practice in React bundle"
);
assert.ok(
  bundle.includes('button`,{type:`button`,`data-ql-bell`:`1`,`aria-label`:`Notifications and announcements`,className:`ql-bell-btn relative flex h-8 w-8'),
  "Header bell button must have data-ql-bell and ql-bell-btn class in React bundle"
);

// 2. App enhancements verification
assert.ok(
  appEnhancements.includes("function toggleBellNotifications(bell)"),
  "app-enhancements.js must define toggleBellNotifications"
);
assert.ok(
  appEnhancements.includes("function syncBellNotifications()"),
  "app-enhancements.js must define syncBellNotifications"
);
assert.ok(
  appEnhancements.includes("location.assign(\"/practice\")"),
  "app-enhancements.js must route clicks on Daily challenge to /practice"
);
assert.ok(
  appEnhancements.includes("toggleBellNotifications(bell)"),
  "app-enhancements.js must open bell popover on bell click"
);

// 3. Cache busters
assert.ok(
  indexHtml.includes('/assets/index-fad00dd6r.js?v=20261018a'),
  "index.html must reference refreshed bundle query parameter"
);
assert.ok(
  indexHtml.includes('/app-enhancements.js?v=20261018b'),
  "index.html must reference refreshed app-enhancements.js query parameter"
);

console.log("PASS: Header bell notifications popover and Daily challenge -> /practice navigation checks.");
