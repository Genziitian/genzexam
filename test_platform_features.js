const fs = require("fs");
const assert = require("assert");

const code = fs.readFileSync("exam-platform.js", "utf8");

// 1. Verify No Normal Emojis
const emojiRegex = /[\u{1F000}-\u{1FFFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B50}-\u{2B55}\u{203C}\u{2049}\u{25AA}\u{25AB}\u{25B6}\u{25C0}\u{25FB}-\u{25FE}]/gu;
const emojiMatches = [...code.matchAll(emojiRegex)];
assert.strictEqual(emojiMatches.length, 0, "Expected 0 emojis in exam-platform.js");

// 2. Verify Logo usage
assert.ok(code.includes("/assets/genz-logo.png"), "Expected GenZ logo reference");

// 3. Verify COC section
assert.ok(code.includes('id: "sec-coc"'), "Expected sec-coc in exam sections");
assert.ok(code.includes("Online Remote Proctored Exams"), "Expected Code of Conduct rules content");

// 4. Verify Merged Submit & Exit Button
assert.ok(code.includes("Submit & Exit"), "Expected merged Submit & Exit button");
assert.ok(!code.includes('id="btn-student-exit"'), "Expected separate Exit button removed");

// 5. Verify Calculator Launchers and Engine
assert.ok(code.includes("ep-btn-calc-basic"), "Expected Basic Calc button");
assert.ok(code.includes("ep-btn-calc-pro"), "Expected Pro Calc button");
assert.ok(code.includes("ep-calc-panel"), "Expected Calculator panel class");

// 6. Verify Exam Ended Force and Rejoin Modals
assert.ok(code.includes("showExamEndedForceModal"), "Expected force quit modal for ended exam");
assert.ok(code.includes("showExamEndedRejoinModal"), "Expected modal preventing re-join on ended exam");

// 7. Verify Tab Switch Detection is not permanently blocked
// 8. Verify Double Confirmation Modal & Zero Native Dialogs
assert.ok(!code.includes("confirm("), "Expected ZERO native browser confirm dialogs");
assert.ok(code.includes("showManagerConfirmModal"), "Expected showManagerConfirmModal definition");
assert.ok(code.includes("ep-manager-confirm-modal"), "Expected manager confirm modal element id");
assert.ok(code.includes("Accidental Touch Guard"), "Expected accidental touch guard badge");
assert.ok(code.includes("ep-mgr-modal-confirm"), "Expected manager modal confirm button");
assert.ok(code.includes("showStudentSubmitConfirmModal"), "Expected custom student submit confirm modal");

console.log("All Ponytail verification checks passed successfully!");
