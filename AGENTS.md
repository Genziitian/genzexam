# Quiz Lab Question Paper Rules

This document establishes the mandatory rules for extracting, structuring, supplementing, and storing question papers in the Quiz Lab / Genz IITian ecosystem. Any AI agent, developer, or automated pipeline modifying or adding questions MUST adhere strictly to these rules.

---

## 1. Paper Size Constraints ($5 \le Q \le 10$)
- **Minimum 5 Questions**: Every question paper (JSON file) MUST contain at least 5 questions.
- **Target Count**: Aim for **8 to 10 questions** per paper whenever possible.
- **Maximum 10 Questions**: Under NO circumstance may a paper contain more than 10 questions.
- **Handling Papers with > 10 Questions**:
  - Automatically split the paper into balanced parts:
    - 11 to 14 questions $\to$ **Part 1** and **Part 2** (e.g., $14 \to 7 + 7$, $12 \to 6 + 6$).
    - 15 to 20 questions $\to$ **Part 1** and **Part 2** (e.g., $16 \to 8 + 8$, $18 \to 9 + 9$).
    - 21+ questions $\to$ **Part 1, Part 2, Part 3**, etc.
  - Suffix titles and filenames accordingly (e.g., `... · Part 1`, `..._part1.json`).
- **Handling Papers with < 5 Questions**:
  - **NEVER** save a paper with fewer than 5 questions.
  - If a source paper has $< 5$ questions, merge it with other fragmented papers of the same subject and section (e.g., `Mathematics 1 · End Term · Combined PYQ`).
  - If the pooled questions are still $< 5$, supplement with high-quality, syllabus-aligned questions from the subject pool until the paper reaches at least 5 questions.

---

## 2. Question Quality & "Making Sense" Guarantee
Before saving or pushing any question, verify that it is 100% self-contained and makes logical sense to a student:
- **No Orphan Questions**: Questions referring to "the passage above", "the dataset below", or "the following pseudocode" MUST have that passage, dataset context, or pseudocode attached directly to their prompt.
- **Never Drop the Question Prompt**: Trailing inquiry sentences (e.g., *"What will X represent at the end of execution?"*, *"The value of A is _ _ _ _ ?"*, *"Choose the correct fragment:"*) must NEVER be lost or truncated.
- **Dataset Context**: In subjects like Computational Thinking or Statistics, ensure the referenced dataset description or sample cards are present in the comprehension passage or prompt.
- **Explanations**: Include the rationale or step-by-step solution in `explanation` whenever available in the source booklet.

---

## 3. Formatting Multi-Step Procedures & Pseudocode
- **Step-by-Step Procedures**:
  - In questions with procedural steps (`Step 1: ... Step 2: ...` or `Step 1. ... Step 2. ...`), **NEVER** leave them mashed together in a single continuous paragraph.
  - Separate the steps line-by-line and place them in a dedicated code block:
    ```json
    {
      "kind": "code",
      "language": "pseudocode",
      "value": "Step 1: Arrange all cards in a single pile called Pile 1\nStep 2: Maintain three variables A, B, C and initialize them to 0\nStep 3: ..."
    }
    ```
  - Question intro text precedes the code block (`kind: "text"`).
  - Trailing question/prompt follows the code block (`kind: "text"`).
- **Code & Pseudocode in Options**:
  - When options are code blocks (e.g. Python code snippets or pseudocode fragments), format them with `kind: "code"` (e.g. `language: "python"` or `language: "pseudocode"`).
  - Regular text options must use `kind: "text"`.

---

## 4. Schema Version 1.1 Specification
All JSON papers must follow the schema:
```json
{
  "schema_version": "1.1",
  "quiz_title": "<Subject> · <Section/Exam> · <Date/Paper>",
  "subject": "<Subject Name>",
  "section": "quiz1 | quiz2 | endterm | practice | practice_graded | mock_test",
  "questions": [
    {
      "type": "mcq_single | mcq_multi | numerical | short_answer",
      "prompt": [
        { "kind": "text", "value": "..." },
        { "kind": "code", "language": "python | pseudocode | text", "value": "..." }
      ],
      "options": [
        [ { "kind": "text", "value": "Option text" } ]
      ],
      "correct_answer": 0,
      "marks": 2,
      "difficulty": "easy | medium | hard",
      "explanation": [
        { "kind": "text", "value": "Detailed step-by-step solution..." }
      ]
    }
  ]
}
```

### Type-Specific Requirements:
1. `mcq_single`:
   - `options`: Array of option arrays (at least 2 options).
   - `correct_answer`: 0-indexed integer corresponding to the correct option index.
2. `mcq_multi`:
   - `options`: Array of option arrays (at least 2 options).
   - `correct_answers`: Array of 0-indexed integers of all correct options (e.g., `[0, 2]`).
3. `numerical`:
   - `numerical_answer`: Floating-point or integer number (e.g., `42` or `3.14`).
   - `numerical_tolerance`: Number (default `0.01`).
4. `short_answer`:
   - `acceptable_answers`: Non-empty array of acceptable string answers (e.g., `["42", "42.0"]`).

---

## 5. Directory Storage Conventions
- Base directory: `bulk_quizzes/<Subject Name>/`
  - Examples:
    - `bulk_quizzes/Mathematics 1/`
    - `bulk_quizzes/Mathematics 2/`
    - `bulk_quizzes/Computational Thinking/`
    - `bulk_quizzes/Python/`
    - `bulk_quizzes/English 1/`
    - `bulk_quizzes/English 2/`
- Diploma courses:
  - `bulk_quizzes/Diploma/<Subject Name>/`
- Clean filenames:
  - Use URL/filesystem-safe filenames matching the quiz title:
    `Mathematics_1_-_Quiz_1_-_Feb_2024_-_QDD2_part1.json`
