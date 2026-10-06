# Proctored exam question JSON

Managers can prepare an exam as JSON and import its `questions` array. Use [`templates/proctored-exam-template.json`](../templates/proctored-exam-template.json) as a complete example. A valid payload can also include `schema_version`, `title`, `duration_minutes`, and `instructions`; the importer consumes only the question objects. Enter the title, duration and instructions in the draft setup form; importing does not change exam metadata.

## Import behavior

- Every question is validated before an exam is saved. If one row or content block is invalid, the import is rejected with errors keyed by question row and field. No partial question set is returned.
- The `questions` array must be a JSON array containing 1–500 questions and be no larger than 5 MB. IDs are optional; missing IDs are assigned `q1`, `q2`, and so on. Supplied IDs must be unique, no longer than 100 characters, and use only letters, numbers, underscores, or hyphens.
- Question content is bounded. A prompt or explanation can contain at most 100 rich-content blocks, and each text/code/math value can contain at most 20,000 characters.
- Question type aliases `mcq` and `multi_select` are accepted and normalized to `mcq_single` and `mcq_multi`. Other supported types are `true_false`, `numerical`, `short_answer`, and `comprehension`.
- Marks default to 1; negative marking defaults to 0. Scored questions require marks greater than 0 and at most 10,000. Comprehension blocks always have zero marks and carry no answer key.

## Question fields

Each question needs a non-empty `prompt` and a `type`. `section` and `difficulty` (`easy`, `medium`, or `hard`) are optional.

| Type | Required answer fields | Scoring |
| --- | --- | --- |
| `mcq_single` | `options` (2–20 entries), `correct_answer` (zero-based index) | Exact option match |
| `mcq_multi` | `options` (2–20 entries), `correct_answers` (one or more distinct zero-based indices) | Exact set match; duplicates are invalid |
| `true_false` | `correct_answer` (`true` or `false`) | Exact boolean match |
| `numerical` | `numerical_answer`; optional `numerical_tolerance` (defaults to 0.01) | Absolute error must be within tolerance |
| `short_answer` | `acceptable_answers` (one or more non-empty strings) | Trimmed, case-insensitive exact text match |
| `comprehension` | Passage content in `prompt` | Context only; never scored |

An unattempted question earns zero. A wrong attempted answer loses its `negative` amount, with the exam total floored at zero. Negative marking is independent per question.

## Rich content blocks

`prompt`, `explanation`, and each MCQ option can be plain text or an array of blocks. Plain strings become text blocks. The importer accepts these forms:

```json
[
  { "kind": "text", "value": "Find the mean of $x_1,\\ldots,x_n$." },
  { "kind": "code", "language": "python", "value": "print(sum(values) / len(values))" },
  { "kind": "math", "display": true, "value": "\\bar{x}=\\frac{1}{n}\\sum_{i=1}^{n}x_i" },
  { "kind": "image", "url": "/uploads/diagram.png", "alt": "A labeled diagram", "caption": "Normal curve centered at $\\mu$." },
  { "kind": "table", "caption": "Sample values", "headers": ["Group", "Value"], "rows": [["A", "4"], ["B", "7"]] }
]
```

- **Text:** supports `**bold**`, `*italic*`, `` `inline code` ``, and LaTeX delimited by `$...$`, `$$...$$`, `\\(...\\)`, or `\\[...\\]`.
- **Math:** use a `math` block for a formula that should be rendered by itself or where delimiters are inconvenient. KaTeX renders math with HTML trust disabled. Fractions, exponents, subscripts, Greek letters, matrices, aligned derivations, cases, sums, integrals, probability notation, and equations in statistical tables use ordinary LaTeX.
- **Code:** `language` is a short syntax-highlighting hint such as `python`, `java`, `cpp`, `sql`, or `pseudocode`; source is displayed as text and never executed.
- **Image:** provide an HTTPS URL or an app-relative path beginning `/storage/`, `/uploads/`, or `/assets/exam-examples/`. For compatibility with the existing template, a simple `asset` filename is treated as `/uploads/<filename>`. `data:`, `javascript:`, `file:`, SVG URLs, protocol-relative URLs, and `..` path traversal are rejected. Include meaningful `alt` text for diagrams.
- **Table:** provide 1–30 string headers and rows with exactly the same number of cells; there can be at most 500 rows. Tables are rendered with headers and horizontal scrolling on narrow screens.

Raw HTML is not a content format. It is escaped and displayed as text. Use the block structures above instead of HTML markup. Avoid putting sensitive personal data in prompts or diagrams.

## JSON escaping reminders

JSON strings use double quotes. Escape a quote as `\"`, a backslash as `\\`, and a line break as `\n`. Thus a LaTeX command is written with a doubled slash, for example `"value": "\\frac{a}{b}"`. Keep each question as one JSON object and commas between adjacent fields and array entries.

## Import checklist

1. Copy the template and edit the title, duration, instructions, and questions.
2. Confirm each single-answer key is a zero-based index and each multi-answer key is an array of zero-based indices.
3. Preview equations, matrices, tables, code, and image alt text before scheduling the exam.
4. Submit the complete file. Fix every row/field error returned by validation and import again.
5. Keep the original source file as the review copy for the assessment.
