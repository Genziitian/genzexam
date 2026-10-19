# Prompt: extract IDE problems from a PDF

Copy the block below and give it to your AI together with the PDF.

```text
TASK
Read the attached PDF and convert EVERY coding problem in it into one JSON
array, saved to a file I name. Do not skip pages and never invent anything that
is not in the PDF. If the PDF has no selectable text (scanned or image pages),
render each page as an image and read it visually.

FOR EACH PROBLEM, DECIDE ITS TYPE
- Whole-program type: the student writes everything (reads input, prints
  output). Locked code is empty.
- Function / template type: the student completes only part of the code. Split
  the code shown in the PDF into three parts:
    prefix_code  = given code before the editable area (imports, helpers,
                   input reading). Shown grey and locked.
    starter_code = the part the student edits (e.g. a signature with an empty
                   body, or the blank lines).
    suffix_code  = given code after the editable area (calling the function,
                   printing the result). Shown grey and locked.
  If the PDF gives no driver code, write one in suffix_code that reads the
  arguments from stdin, calls the function and prints the result. The
  student's part must never read input or print anything itself.
  Copy given code exactly as printed, including indentation.

TITLE RULE (this decides where the question appears)
Start every title with the exam type the PDF belongs to: "GrPA", "Quiz 1", "OPPE 1", "OPPE 2" or "End Term".
Use "<type> (<session>) Set <n> · P<k>: <name>" for a numbered set, for example "OPPE 1 (2025 May) Set 2 · P3: Vowel count".
For a single question that is its own item (such as one GrPA), use the plain name, for example "GrPA 1 - Variables and Assignment", and set its week.

JSON FIELDS (one object per problem, in PDF order)
{
  "position": 1,
  "title": "<problem title>",
  "description": "full statement, plain text, \n for line breaks; keep notes, hints and examples",
  "input_format": "..." or null,
  "output_format": "..." or null,
  "constraints": "..." or null,
  "sample_input": "stdin text of the first example",
  "sample_output": "exact stdout of that example",
  "prefix_code": "", "starter_code": "", "suffix_code": "",
  "test_cases": [ {"input": "...", "expected_output": "...", "is_hidden": false} ]
}
Keep spaces, backslashes and blank lines that matter. Use proper JSON escaping.
No markdown or formatting that is not in the PDF.

TEST CASES (8 per problem)
- The first 2 are the PDF's own examples (is_hidden false).
- The other 6 are hidden (is_hidden true): edge cases (empty, minimum, maximum,
  negative, duplicates, ties) and typical cases.
- "input" is exactly what stdin receives, one value per line, matching how the
  driver code reads it.
- Never write expected_output by hand. Use the solution from the PDF (or write
  one), run prefix + solution + suffix in the problem's language on every
  input, and store the real output (trim only trailing newlines).

VERIFY BEFORE FINISHING
1. Each sample_output matches the output printed in the PDF.
2. Every test case runs without error, quickly.
3. The solution is NOT stored in the JSON.
4. The JSON parses, has one object per PDF problem, titles are unique.
5. Print a table: position | title | type | number of cases | OK/FAIL.

DELIVER
Save the JSON file, then report: problem count, anything unclear (blurry text,
missing examples) and what you assumed. Do not touch the database. If
something is ambiguous, ask me before guessing.
```
