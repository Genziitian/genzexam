const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const source = fs.readFileSync(
  path.join(__dirname, "..", "exam-rich-content.js"),
  "utf8",
);
const calls = [];
const sandbox = {
  window: {
    katex: {
      renderToString(tex, options) {
        calls.push({ tex, options });
        if (tex.includes("unsupported")) throw new Error("unsupported math");
        return '<span class="katex">safe-rendered</span>';
      },
    },
  },
  URL,
  console,
};
vm.runInNewContext(source, sandbox, { filename: "exam-rich-content.js" });
const content = sandbox.window.ExamRichContent;
assert.ok(content, "Renderer API is exposed on window.");

const html = content.render([
  { kind: "text", value: "<img src=x onerror=alert(1)> **safe** and $x^2$" },
  { kind: "code", language: "python", value: "<script>alert(1)</script>" },
  { kind: "text", value: "```js\n<script>alert(2)</script>\n```" },
  { kind: "image", url: "javascript:alert(1)", alt: "bad" },
  { kind: "image", url: "/uploads/%2e%2e/private.png", alt: "bad" },
  { kind: "image", url: "https://example.test/image.svg", alt: "bad" },
  {
    kind: "image",
    url: "/assets/exam-examples/normal-curve.png",
    alt: "curve",
  },
  { kind: "table", headers: ["<b>H</b>"], rows: [["<script>x</script>"]] },
]);
assert.equal(
  (html.match(/<script/g) || []).length,
  0,
  "Raw script tags stay escaped.",
);
assert.equal(
  (html.match(/<img src=x/g) || []).length,
  0,
  "Raw HTML image tags stay escaped.",
);
assert.match(html, /&lt;img src=x onerror=alert\(1\)&gt;/);
assert.match(html, /<strong>safe<\/strong>/);
assert.match(html, /language-js/);
assert.match(html, /Image unavailable/g);
assert.match(html, /src="\/assets\/exam-examples\/normal-curve.png"/);
assert.match(html, /&lt;script&gt;x&lt;\/script&gt;/);

const mixed = content.render(
  'Read $x^2$ before ![Matrix A](</uploads/matrix(1).png>)\n' +
    '```pseudocode\nStep 1: Read A\nStep 2: Stop\n```\n' +
    'Then choose ![Graph \\[B\\]](/uploads/graph.png) after the procedure.',
);
const matrix = mixed.indexOf('src="/uploads/matrix(1).png"');
const code = mixed.indexOf('language-pseudocode');
const graph = mixed.indexOf('src="/uploads/graph.png"');
assert.ok(matrix > mixed.indexOf('data-exam-tex="x^2"'));
assert.ok(code > matrix && graph > code, "Mixed prompt order is preserved.");
assert.match(mixed, /alt="Graph \[B\]"/);
assert.match(mixed, /Step 1: Read A\nStep 2: Stop/);
assert.match(content.render('![Option A](</uploads/choice.png>)'), /<img.*alt="Option A"/);
const literal = content.render(
  '`![inline code](/uploads/no.png)`\n```text\n![fenced code](/uploads/no.png)\n```\n$![math](/uploads/no.png)$',
);
assert.equal((literal.match(/<img /g) || []).length, 0, "Images stay literal inside code and math.");
for (const url of ['javascript:alert', 'data:image/png;base64,AA', 'file:///tmp/a.png', '/uploads/../private.png', 'https://example.test/a.svg']) {
  assert.match(content.render(`![unsafe](<${url}>)`), /Image unavailable/);
}
assert.match(content.render('![&quot; <script>](</uploads/choice.png>)'), /alt="&amp;quot; &lt;script&gt;"/);
assert.match(content.render([{ kind: 'image', url: '/uploads/choice.png' }]), /alt="Question image"/);

const root = {
  elements: [
    {
      tex: "x^2",
      display: "true",
      attributes: {},
      classList: { add() {}, remove() {} },
      set innerHTML(value) {
        this.output = value;
      },
      getAttribute(name) {
        return name === "data-exam-tex" ? this.tex : this.display;
      },
      set textContent(value) {
        this.output = value;
      },
    },
    {
      tex: "unsupported\\badmacro",
      display: "false",
      attributes: {},
      classList: {
        add(name) {
          this.fallback = name;
        },
        remove() {},
      },
      set innerHTML(value) {
        this.output = value;
      },
      getAttribute(name) {
        return name === "data-exam-tex" ? this.tex : this.display;
      },
      set textContent(value) {
        this.output = value;
      },
    },
  ],
  querySelectorAll(selector) {
    assert.equal(selector, ".exam-math[data-exam-tex]");
    return this.elements;
  },
};
content.typeset(root);
assert.ok(root.elements[0].output.includes("safe-rendered"));
assert.equal(
  calls[0].options.trust,
  false,
  "KaTeX trust must remain disabled.",
);
assert.equal(calls[0].options.maxExpand, 1000, "Macro expansion is bounded.");
assert.equal(calls[0].options.displayMode, true);
assert.equal(
  root.elements[1].output,
  "$unsupported\\badmacro$",
  "Failed math remains visible to the user.",
);
assert.equal(root.elements[1].classList.fallback, "exam-math-fallback");

console.log("ExamRichContent checks passed.");
