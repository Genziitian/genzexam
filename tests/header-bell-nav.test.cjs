const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const bundle = fs.readFileSync(path.join(root, "assets", "index-fad00dd6r.js"), "utf8");
const appEnhancements = fs.readFileSync(path.join(root, "app-enhancements.js"), "utf8");
const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");

// Parse the shipped module before checking the notification markup.
const syntax = spawnSync(process.execPath, ["--check", path.join(root, "assets", "index-fad00dd6r.js")], { encoding: "utf8" });
assert.strictEqual(syntax.status, 0, "The main app bundle must parse successfully before the dashboard can load");

// 1. Bundle verification
assert.ok(
  bundle.includes('Spin & Win') || bundle.includes('Daily challenge'),
  "Header action button must exist in React bundle"
);
assert.ok(
  bundle.includes('button`,{type:`button`,"data-ql-bell":`1`,"aria-label":`Notifications and announcements`,className:`ql-bell-btn relative flex h-8 w-8'),
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
  appEnhancements.includes("location.assign(\"/rewards\")") || appEnhancements.includes("location.assign(\"/practice\")"),
  "app-enhancements.js must route clicks on header challenge button"
);
assert.ok(
  appEnhancements.includes("toggleBellNotifications(bell)"),
  "app-enhancements.js must open bell popover on bell click"
);

// 3. Cache busters
assert.ok(
  /\/assets\/index-fad00dd6r\.js\?v=202610[0-9]{2}[a-z0-9_-]*/.test(indexHtml),
  "index.html must reference refreshed bundle query parameter"
);
assert.ok(
  /\/app-enhancements\.js\?v=202610[0-9]{2}[a-z0-9_-]*/.test(indexHtml),
  "index.html must reference refreshed app-enhancements.js query parameter"
);

console.log("PASS: Header bell notifications popover and Daily challenge -> /practice navigation checks.");
