"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.resolve(__dirname, "..");
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");
const mixed = 'Read $\\nabla f$\n![Matrix](<https://lab.genziitian.in/assets/exam-examples/matrix(1).png>)\n```python\nprint("\\n")\n```\nWhat is the answer?';
const sandbox = { window: {}, URL };
vm.runInNewContext(read("exam-rich-content.js"), sandbox);
const bundle = read("assets/index-fad00dd6r.js");
const cg = bundle.slice(bundle.indexOf("function cg("), bundle.indexOf("function lg("));
const hookCalls = [];
sandbox.v = {
  useMemo(fn) { hookCalls.push("memo"); return fn(); },
  useRef() { hookCalls.push("ref"); return { current: null }; },
  useEffect() { hookCalls.push("effect"); },
};
sandbox.F = { jsx(type, props) { return { type, props }; } };
for (const name of ["ag", "Zh", "Yh", "eg"]) sandbox[name] = (text) => text;
sandbox.Xh = () => true;
vm.runInNewContext(cg + ";this.RichText=cg;", sandbox);
const imageResult = sandbox.RichText({ content: mixed });
assert.match(imageResult.props.dangerouslySetInnerHTML.__html, /src="https:\/\/lab.genziitian.in\/assets\/exam-examples\/matrix\(1\).png"/);
assert.match(imageResult.props.dangerouslySetInnerHTML.__html, /data-exam-tex="\\nabla f"/);
assert.match(imageResult.props.dangerouslySetInnerHTML.__html, /print\(&quot;\\n&quot;\)/);
const pureCode = 'Intro\n```python\nprint("\\n")\n```\nWhat is printed?';
const codeResult = sandbox.RichText({ content: pureCode });
assert.match(codeResult.props.dangerouslySetInnerHTML.__html, /print\(&quot;\\n&quot;\)/);
hookCalls.splice(0, 3);
const firstHooks = [...hookCalls];
hookCalls.length = 0;
sandbox.RichText({ content: "Ordinary question" });
assert.deepEqual(hookCalls, firstHooks, "Changing between image and plain content keeps React hooks stable.");

const paper = read("paper-room.js");
const contentSection = paper.slice(paper.indexOf("  function clean("), paper.indexOf("  /* ---------------------------- answers"));
vm.runInNewContext(contentSection + ";this.clean=clean;this.optionHtml=optionHtml;this.stemHtml=stemHtml;", sandbox);
assert.equal(sandbox.clean(mixed), mixed, "HTML cleanup preserves angle-form crop URLs and code escapes.");
const option = sandbox.optionHtml({ option_type: "text", option_text: mixed + '\nif (a) { return b; }' });
assert.match(option, /<img /, "Code-like image options stay rich content.");
assert.match(option, /language-python/);
const procedure = 'Before\n```pseudocode\nStep 1: Read A\nStep 2: Stop\n```\n![Matrix](</uploads/a.png>)\nWhat is A?';
const prompt = sandbox.stemHtml({ stem: procedure });
assert.ok(prompt.indexOf('language-pseudocode') < prompt.indexOf('<img '));
assert.ok(prompt.indexOf('<img ') < prompt.indexOf('What is A?'), "Question outro stays after the crop.");

const exams = read("exam-platform.js");
const paperText = exams.slice(exams.indexOf("  function paperText("), exams.indexOf("  function paperImage("));
vm.runInNewContext(paperText + ";this.paperText=paperText;", sandbox);
assert.equal(sandbox.paperText(mixed), mixed, "Copying a paper to an exam keeps its crop URLs.");
assert.match(exams, /if \(!code && stem && !\/```\|!/);
console.log("Question crop web checks passed: mixed content, image options, React hooks, and exam copies.");
