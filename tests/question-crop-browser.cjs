"use strict";
// Local rendering check using the shipped React component and original PDF crops.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require("playwright");
const { handler } = require("../server.js");
const root = path.resolve(__dirname, "..");
const source = JSON.parse(fs.readFileSync(path.join(root, "bulk_quizzes/Mathematics 2/Mathematics_2_-_Graded_Assignment_-_Week_1_-_May_2024.json")));
function markdown(blocks) {
  return blocks.map((block) => block.kind === "image"
    ? `![${block.alt}](<${block.url || block.asset}>)`
    : block.kind === "code" ? `\`\`\`${block.language || "text"}\n${block.value}\n\`\`\`` : block.value).join("\n\n");
}
let question = {
  stem: markdown(source.questions[0].prompt),
  options: source.questions[0].options.map((blocks) => ({ option_text: markdown(blocks) })),
  explanation: markdown(source.questions[0].explanation),
};
let apiQuiz = null;
if (process.env.CROP_API_FIXTURE) {
  const api = JSON.parse(fs.readFileSync(process.env.CROP_API_FIXTURE));
  apiQuiz = api.quiz || api;
  // Attempt APIs correctly omit explanations; use the source solution for the result-renderer check.
  question = { ...(api.quiz || api).questions[0], explanation: question.explanation };
}
const initial = JSON.stringify(question).replace(/</g, "\\u003c");
let bundle = fs.readFileSync(path.join(root, "assets/index-fad00dd6r.js"), "utf8");
const start = "(0,y.createRoot)(document.getElementById(`root`)).render(";
const position = bundle.lastIndexOf(start);
assert.ok(position > 0, "Shipped React entry point is present.");
bundle = bundle.slice(0, position) + `
const cropFixture=${initial};
const pureCodeFixture=${JSON.stringify('```python\nprint("\\n")\n```')};
function CropFixture(){
 const [plain,setPlain]=v.useState(false),[choice,setChoice]=v.useState(-1);
 return F.jsxs("main",{style:{maxWidth:"720px",margin:"auto",padding:"16px"},children:[
  F.jsx("h1",{children:"Original Mathematics 2 question"}),
  F.jsx("button",{id:"toggle",onClick:()=>setPlain(!plain),children:"Toggle image content"}),
  F.jsx(cg,{content:plain?"Plain text question":cropFixture.stem}),
  F.jsx("section",{id:"options",children:cropFixture.options.map((option,i)=>F.jsx("button",{type:"button","data-option":i,"aria-pressed":choice===i,onClick:()=>setChoice(i),style:{display:"block",maxWidth:"100%",width:"100%",textAlign:"left",margin:"12px 0",padding:"12px",border:"1px solid #aaa"},children:F.jsx(cg,{content:option.option_text})},i))}),
  F.jsx("section",{id:"explanation",children:F.jsx(cg,{content:cropFixture.explanation})}),
  F.jsx("section",{id:"pure-code",children:F.jsx(cg,{content:pureCodeFixture})})
 ]});
}
(0,y.createRoot)(document.getElementById("root")).render(F.jsx(v.StrictMode,{children:F.jsx(CropFixture,{})}));`;
const html = '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/assets/index-8e7e8831.css"><link rel="stylesheet" href="/exam-platform.css"><link rel="stylesheet" href="/assets/vendor/katex/katex.min.css"><script src="/assets/vendor/katex/katex.min.js"></script><script src="/exam-rich-content.js"></script></head><body><div id="root"></div><script type="module" src="/crop-test.js"></script></body></html>';
(async () => {
  const server = http.createServer((req, res) => {
    if (req.url === "/crop-test") { res.setHeader("Content-Type", "text/html"); return res.end(html); }
    if (req.url === "/crop-test.js") { res.setHeader("Content-Type", "text/javascript"); return res.end(bundle); }
    return handler(req, res);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  let browser;
  try {
    browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
    const page = await browser.newPage();
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const base = `http://127.0.0.1:${server.address().port}`;
    for (const viewport of [{ width: 1440, height: 1100 }, { width: 390, height: 844 }]) {
      await page.setViewportSize(viewport);
      await page.goto(base + "/crop-test");
      await page.locator("main .exam-rich-image img").first().waitFor();
      await page.waitForFunction(() => [...document.querySelectorAll(".exam-rich-image img")].every((img) => img.complete && img.naturalWidth > 0));
      assert.equal(await page.locator(".exam-rich-image img").count(), 2);
      assert.ok(await page.locator(".exam-rich-image img").first().getAttribute("alt"));
      assert.ok(await page.locator("#explanation .katex").count() > 0, "Math typesetting survives mixed image content.");
      assert.equal((await page.locator("#pure-code code").textContent()).trim(), 'print("\\n")', "Pure fenced code preserves literal escapes.");
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), "Crops fit the viewport.");
      await page.locator('[data-option="0"] img').click();
      assert.equal(await page.locator('[data-option="0"]').getAttribute("aria-pressed"), "true", "Image options remain selectable.");
      await page.locator("#toggle").click();
      assert.equal(await page.locator(".exam-rich-image img").count(), 1);
      await page.locator("#toggle").click();
      assert.equal(await page.locator(".exam-rich-image img").count(), 2);
      if (process.env.CROP_SCREENSHOT_DIR) {
        fs.mkdirSync(process.env.CROP_SCREENSHOT_DIR, { recursive: true });
        await page.screenshot({ path: path.join(process.env.CROP_SCREENSHOT_DIR, `question-crops-${viewport.width}.png`), fullPage: true });
      }
    }
    if (apiQuiz) {
      for (const viewport of [{ width: 1440, height: 1100 }, { width: 390, height: 844 }]) {
        const context = await browser.newContext({ viewport });
        await context.addInitScript(() => {
          localStorage.setItem("lab_token", "local-crop-browser-fixture");
          localStorage.setItem("lab_user", JSON.stringify({ name: "Local test" }));
        });
        const room = await context.newPage();
        room.on("pageerror", (error) => errors.push(error.message));
        await room.route("https://labapi.genziitian.in/**", (route) => {
          const url = new URL(route.request().url());
          const body = url.pathname === `/public/api/quizzes/${apiQuiz.id}` ? apiQuiz
            : url.pathname === `/public/api/quizzes/${apiQuiz.id}/attempts` ? { attempt_id: 7001 }
            : { message: "Local browser fixture has no handler for this route." };
          return route.fulfill({ status: 200, contentType: "application/json", headers: { "Access-Control-Allow-Origin": "*" }, body: JSON.stringify(body) });
        });
        await room.goto(`${base}/paper/${apiQuiz.id}`);
        await room.locator('[data-action="start"]').click();
        await room.locator('.pr-option img').first().waitFor();
        await room.waitForFunction(() => [...document.querySelectorAll(".exam-rich-image img")].every((img) => img.complete && img.naturalWidth > 0));
        assert.equal(await room.locator(".exam-rich-image img").count(), 2);
        const option = room.locator('label').filter({ has: room.locator('.pr-option img') }).first();
        await option.locator("img").click();
        assert.equal(await option.locator('input').isChecked(), true);
        assert.ok(await room.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), "Paper room crops fit the viewport.");
        if (process.env.CROP_SCREENSHOT_DIR) await room.screenshot({ path: path.join(process.env.CROP_SCREENSHOT_DIR, `paper-room-crops-${viewport.width}.png`), fullPage: true });
        await context.close();
      }
    }
    assert.deepEqual(errors, []);
    console.log("Question crop browser checks passed: desktop/mobile sizing, image selection, math, and React content changes.");
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
