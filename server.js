#!/usr/bin/env node
"use strict";
// Local static preview only. Exam operations require the authenticated Laravel API.
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const root = __dirname;
const port = Number(process.argv[2] || process.env.PORT || 3000);
const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".webmanifest": "application/manifest+json",
};
const rootFiles = new Set(
  "index.html exams.html paper-room.html paper-room.js paper-room.css landing.html papers.html paper-pricing.html manager-sales.html manager-sales.js manager-sales.css exam-platform.js exam-rich-content.js exam-platform.css app-enhancements.js storefront-runtime.js storefront-dashboard.css papers.js papers.css paper-pricing.js paper-pricing.css icons.svg site.webmanifest favicon.ico favicon-16x16.png favicon-32x32.png apple-touch-icon.png android-chrome-192x192.png android-chrome-512x512.png".split(
    " ",
  ),
);
const appRoutes =
  /^\/(login|register|forgot-password|reset-password|dashboard|admin|exams?|courses|quizzes|profile|leaderboard|discussions)(\/[^.]*)?\/?$/;
function handler(req, res) {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader("X-Frame-Options", "SAMEORIGIN");
  res.setHeader("Cache-Control", "no-store");
  let url;
  try {
    url = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
  } catch {
    res.writeHead(400);
    return res.end("Bad path");
  }
  if (/^\/(public\/)?api(?:\/|$)/.test(url)) {
    res.writeHead(503, { "Content-Type": "application/json" });
    return res.end(
      JSON.stringify({
        message:
          "The authenticated Laravel API must be running. This server only previews public pages.",
      }),
    );
  }
  if (!["GET", "HEAD"].includes(req.method)) {
    res.writeHead(405, { Allow: "GET, HEAD" });
    return res.end();
  }
  if (
    url
      .split("/")
      .some((segment) => segment.startsWith(".") || segment.includes("\\")) ||
    url.includes("\0")
  ) {
    res.writeHead(404);
    return res.end();
  }
  let file = url.slice(1);
  if (url === "/") file = "landing.html";
  else if (/^\/papers\/?$/.test(url)) file = "papers.html";
  else if (/^\/manager\/sales\/?$/.test(url)) file = "manager-sales.html";
  else if (/^\/paper-pricing\/?$/.test(url)) file = "paper-pricing.html";
  else if (/^\/paper\/\d+\/?$/.test(url)) file = "paper-room.html";
  else if (/^\/exams?(\/[^.]*)?\/?$/.test(url)) file = "exams.html";
  else if (appRoutes.test(url)) file = "index.html";
  const ext = path.extname(file).toLowerCase();
  if (
    !(
      rootFiles.has(file) ||
      (file.startsWith("assets/") &&
        types[ext] &&
        !file.endsWith("package.json")) ||
      /^templates\/[\w-]+\.json$/.test(file)
    )
  ) {
    res.writeHead(404);
    return res.end();
  }
  const full = path.resolve(root, file);
  try {
    const real = fs.realpathSync(full);
    if (!real.startsWith(root + path.sep) || !fs.statSync(real).isFile())
      throw new Error("not public");
    res.writeHead(200, {
      "Content-Type": types[ext] || "application/octet-stream",
    });
    if (req.method === "HEAD") return res.end();
    fs.createReadStream(real)
      .on("error", () => res.destroy())
      .pipe(res);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
}
if (require.main === module)
  http
    .createServer(handler)
    .listen(port, "127.0.0.1", () =>
      console.log(
        `Static preview: http://127.0.0.1:${port}; exams require Laravel.`,
      ),
    );
module.exports = { handler };
