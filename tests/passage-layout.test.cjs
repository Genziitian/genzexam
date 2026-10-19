"use strict";
const assert = require("node:assert/strict");

function cleanPassageHeading(text) {
  return String(text || "").trim()
    .replace(/^(?:📖\s*)?Passage\s*(?:\/|\:)\s*(?:Context\s*:?)?\s*/i, "")
    .replace(/^Comprehension\s*(?:Type\s*Question)?\s*:\s*/i, "")
    .trim();
}

function splitEmbeddedPassage(q) {
  if (!q) return null;

  // 1. Array prompt with multiple blocks
  if (Array.isArray(q.prompt) && q.prompt.length >= 2) {
    const b0 = String((q.prompt[0] && (q.prompt[0].value || q.prompt[0].text)) || "").trim();
    if (/(?:passage|context|comprehension|subquestions?)/i.test(b0) || /^(?:📖\s*)?passage\b/i.test(b0) || /Q\d+[–-]\s*Q\d+/i.test(b0)) {
      let qIndex = q.prompt.length - 1;
      const passBlocks = q.prompt.slice(0, qIndex).map((b, i) => {
        if (i === 0 && b && b.value) {
          return { ...b, value: cleanPassageHeading(b.value) };
        }
        return b;
      });
      const qBlocks = q.prompt.slice(qIndex);
      return {
        passageBlocks: passBlocks,
        promptBlocks: qBlocks,
      };
    }
  }

  // 2. String text in stem or prompt
  const stemText = String(
    q.stem != null
      ? q.stem
      : q.question_stem != null
        ? q.question_stem
        : Array.isArray(q.prompt)
          ? q.prompt.map(b => (b && typeof b === "object" ? (b.value || b.text || "") : String(b || ""))).join("\n\n")
          : typeof q.prompt === "string"
            ? q.prompt
            : ""
  ).trim();

  if (!stemText) return null;

  // Pattern A: Explicit Question: or Subquestion:
  const qSplit = stemText.match(/^([\s\S]*?)\n+(?:Question|Subquestion)\s*:\s*\n*([\s\S]+)$/i);
  if (qSplit && /passage|context|comprehension/i.test(qSplit[1])) {
    return {
      passageText: cleanPassageHeading(qSplit[1]),
      promptText: qSplit[2].trim(),
    };
  }

  // Pattern B: 'Based on the above ... answer ...'
  const bSplit = stemText.match(/^([\s\S]*?(?:Based on the above [^\n]*?,?\s*answer the [^\n]*?subquestions\.?|answer the (?:given|following) subquestions\.?))\s*\n+([\s\S]+)$/i);
  if (bSplit && /passage|context|comprehension/i.test(bSplit[1])) {
    return {
      passageText: cleanPassageHeading(bSplit[1]),
      promptText: bSplit[2].trim(),
    };
  }

  // Pattern C: Starts with Passage / Context or Comprehension
  if (/^(?:📖\s*)?Passage\s*(?:\/|\:)\s*(?:Context\s*:?)?|^Comprehension\s*(?:Type\s*Question)?\s*:\s*/i.test(stemText)) {
    const cleaned = cleanPassageHeading(stemText);
    const paras = cleaned.split(/\n{2,}/);
    if (paras.length >= 2) {
      const last = paras[paras.length - 1].trim();
      if (/\?$/.test(last) || /^(?:What|Find|Calculate|Which|Choose|Determine|How|If|The value of|Enter the)\b/i.test(last)) {
        return {
          passageText: paras.slice(0, -1).join("\n\n").trim(),
          promptText: last,
        };
      }
    }
  }

  return null;
}

const t1 = splitEmbeddedPassage({ stem: "Passage / Context:\nRead the story...\n\nQuestion:\nWhat did he say?" });
assert.ok(t1);
assert.equal(t1.passageText, "Read the story...");
assert.equal(t1.promptText, "What did he say?");

const t2 = splitEmbeddedPassage({ prompt: [{ kind: "text", value: "📖 Passage / Context\nA box of chocolates... answer the given subquestions." }, { kind: "text", value: "What is the PMF?" }] });
assert.ok(t2);
assert.equal(t2.promptBlocks[0].value, "What is the PMF?");

const t3 = splitEmbeddedPassage({ stem: "Just a regular math question $x^2 + 1 = 0$. What is $x$?" });
assert.equal(t3, null);

console.log("Passage splitting basic checks passed.");

function parsePassageScope(text) {
  const m = String(text || "").match(/(?:Questions?|Q)\s*(\d+)\s*(?:to|–|-)\s*(?:Q\s*)?(\d+)/i);
  if (m) {
    const start = parseInt(m[1], 10);
    const end = parseInt(m[2], 10);
    if (end >= start) return end - start + 1;
  }
  return null;
}

function isPassageOnly(q) {
  if (!q) return false;
  if (q.type === "comprehension" || q.type === "passage") return true;
  const noAnswers = (!q.options || !q.options.length) && q.numerical_answer == null && (!q.acceptable_answers || !q.acceptable_answers.length);
  const stem = String(q.stem || q.question_stem || "").trim();
  if (noAnswers && Number(q.marks || 0) === 0 && (/^(?:📖\s*)?passage\b/i.test(stem) || /^comprehension\b/i.test(stem))) {
    return true;
  }
  return false;
}

function prepareQuizQuestions(quiz) {
  if (!quiz || !Array.isArray(quiz.questions)) return [];
  let activePassage = null;
  const processed = [];
  for (const q of quiz.questions) {
    if (isPassageOnly(q)) {
      const stem = String(q.stem || q.question_stem || "");
      activePassage = {
        id: q.id,
        html: stem,
        scopeCount: parsePassageScope(stem),
      };
      continue;
    }
    const split = splitEmbeddedPassage(q);
    if (split) {
      q._passageHtml = split.passageText || split.passageBlocks;
      q._promptHtml = split.promptText || split.promptBlocks;
      activePassage = { id: q.id, html: q._passageHtml, scopeCount: null };
    } else if (activePassage) {
      q._passageHtml = activePassage.html;
      q._promptHtml = q.stem || q.question_stem;
      if (activePassage.scopeCount != null) {
        activePassage.scopeCount--;
        if (activePassage.scopeCount <= 0) activePassage = null;
      }
    } else {
      q._passageHtml = null;
      q._promptHtml = q.stem || q.question_stem;
    }
    processed.push(q);
  }
  quiz.rawQuestions = quiz.questions;
  quiz.questions = processed;
  return processed;
}

// Test with quiz containing a standalone comprehension question
const mockQuiz = {
  title: "Mock Comprehension Quiz",
  questions: [
    { id: 1, type: "comprehension", stem: "Questions 1 to 2. Dataset of 100 students...", marks: 0 },
    { id: 2, type: "mcq", stem: "What is the average marks?", marks: 2, options: [{ id: 1, option_text: "50" }] },
    { id: 3, type: "numerical", stem: "Find the median marks.", marks: 2 },
    { id: 4, type: "mcq", stem: "Normal standalone question about geometry.", marks: 1, options: [{ id: 2, option_text: "180" }] },
  ]
};

const result = prepareQuizQuestions(mockQuiz);
assert.equal(mockQuiz.questions.length, 3, "Comprehension question is NOT counted as a question.");
assert.equal(mockQuiz.questions[0].id, 2, "First question is question id 2");
assert.ok(mockQuiz.questions[0]._passageHtml, "Question 1 has passage attached");
assert.ok(mockQuiz.questions[1]._passageHtml, "Question 2 has passage attached");
assert.equal(mockQuiz.questions[2]._passageHtml, null, "Question 3 is out of scope and has no passage");

console.log("All passage-layout tests passed successfully.");

