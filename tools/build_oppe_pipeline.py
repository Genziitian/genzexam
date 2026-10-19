#!/usr/bin/env python3
"""
Python OPPE Complete Pipeline:
1. Generates the 2 missing IDE problem sets in backend/database/seeders/oppe/:
   - python_oppe2_2024sep_set2.json
   - python_oppe2_2024sep_set3.json
2. Converts all 16 OPPE sets into Schema 1.1 quiz papers in bulk_quizzes/Python/:
   - 7 coding questions per paper (satisfies 5 <= Q <= 10).
   - Formatted prompts with problem statements and code skeletons.
   - Verified solution code and sample test cases in explanation.
"""

import os
import json
import math
import subprocess
import tempfile

SRC_DIR = "/Users/tusharrrsingh/Downloads/Python OPPE/json"
SEEDER_DIR = os.path.join(os.path.dirname(__file__), "..", "backend", "database", "seeders", "oppe")
QUIZ_DIR = os.path.join(os.path.dirname(__file__), "..", "bulk_quizzes", "Python")

os.makedirs(SEEDER_DIR, exist_ok=True)
os.makedirs(QUIZ_DIR, exist_ok=True)

# ------------------------------------------------------------------------------
# STEP 1: GENERATE MISSING SEEDER FILES (OPPE 2 Set 2 & Set 3)
# ------------------------------------------------------------------------------

def run_py(code: str, stdin_data: str = "") -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as tf:
        tf.write(code)
        tf_name = tf.name
    try:
        res = subprocess.run(
            ["python3", tf_name],
            input=stdin_data,
            capture_output=True,
            text=True,
            timeout=5
        )
        if res.returncode != 0:
            raise RuntimeError(f"Code execution error:\n{res.stderr}\nCode:\n{code}\nInput:\n{stdin_data}")
        return res.stdout.rstrip("\r\n")
    finally:
        if os.path.exists(tf_name):
            os.remove(tf_name)

def build_set2_ide():
    raw = json.load(open(os.path.join(SRC_DIR, "OPPE2_2024Sep_Set2.json")))
    probs = raw["problems"]
    items = []

    # P1: Sum of Floored to Tens
    p1 = probs[0]
    p1_sol = p1["solution"]
    p1_suffix = "a = int(input())\nb = int(input())\nprint(sum_floored_to_tens(a, b))"
    p1_cases = [("35\n46", False), ("12\n19", False), ("5\n8", True), ("100\n205", True), ("99\n99", True), ("10\n10", True), ("44\n55", True), ("1\n1", True)]
    tcs = [{"input": inp, "expected_output": run_py(p1_sol + "\n" + p1_suffix, inp), "is_hidden": hid} for inp, hid in p1_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P1: Sum of Floored to Tens",
        "description": p1["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def sum_floored_to_tens(a: int, b: int) -> int:\n    ", "suffix_code": p1_suffix,
        "sample_input": "35\n46", "sample_output": "70", "position": 1, "section": 1, "test_cases": tcs
    })

    # P2: Surround First Two and Last Two with Square Brackets
    p2 = probs[1]
    p2_sol = p2["solution"]
    p2_suffix = "s = input()\nprint(surround_first_two_last_two(s))"
    p2_cases = [("hello", False), ("four", False), ("python", True), ("brackets", True), ("testing", True), ("123456", True), ("code", True), ("programming", True)]
    tcs = [{"input": inp, "expected_output": run_py(p2_sol + "\n" + p2_suffix, inp), "is_hidden": hid} for inp, hid in p2_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P2: Surround First Two and Last Two with Square Brackets",
        "description": p2["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def surround_first_two_last_two(s: str) -> str:\n    ", "suffix_code": p2_suffix,
        "sample_input": "hello", "sample_output": "[he]l[lo]", "position": 2, "section": 1, "test_cases": tcs
    })

    # P3: Number with More Unique Digits
    p3 = probs[2]
    p3_sol = p3["solution"]
    p3_suffix = "n1 = int(input())\nn2 = int(input())\nprint(number_with_more_unique_digits(n1, n2))"
    p3_cases = [("2345\n1111", False), ("1243\n123344", False), ("1000\n9876", True), ("123\n456", True), ("9999\n10", True), ("56789\n1234", True), ("777\n888", True), ("12034\n90871", True)]
    tcs = [{"input": inp, "expected_output": run_py(p3_sol + "\n" + p3_suffix, inp), "is_hidden": hid} for inp, hid in p3_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P3: Number with More Unique Digits",
        "description": p3["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def number_with_more_unique_digits(n1: int, n2: int):\n    ", "suffix_code": p3_suffix,
        "sample_input": "2345\n1111", "sample_output": "2345", "position": 3, "section": 1, "test_cases": tcs
    })

    # P4: Count Vowels and Consonants in Even Indices
    p4 = probs[3]
    p4_sol = p4["solution"]
    p4_suffix = "s = input()\nprint(count_vowels_and_consonants_in_even_indices(s))"
    p4_cases = [("abcdeaeiou", False), ("ABCDE", False), ("a11bc11de11", True), ("hello world", True), ("python", True), ("AEIOU", True), ("123456", True), ("xyz", True)]
    tcs = [{"input": inp, "expected_output": run_py(p4_sol + "\n" + p4_suffix, inp), "is_hidden": hid} for inp, hid in p4_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P4: Count Vowels and Consonants in Even Indices",
        "description": p4["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def count_vowels_and_consonants_in_even_indices(s: str) -> tuple:\n    ", "suffix_code": p4_suffix,
        "sample_input": "abcdeaeiou", "sample_output": "(4, 1)", "position": 4, "section": 2, "test_cases": tcs
    })

    # P5: Append and Prepend Alternatively (io type)
    p5 = probs[4]
    p5_sol = p5["solution"]
    p5_cases = [("6\nh\nt\no\ny\nn\np", False), ("6\n1\n2\n3\n4\n5\n6", False), ("4\na\nb\nc\nd", True), ("1\nx", True), ("3\nx\ny\nz", True), ("5\n1\n2\n3\n4\n5", True), ("2\nhi\nbye", True), ("4\ncat\ndog\nrat\nbat", True)]
    tcs = [{"input": inp, "expected_output": run_py(p5_sol, inp), "is_hidden": hid} for inp, hid in p5_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P5: Append and Prepend Alternatively",
        "description": p5["statement"], "input_format": "The first line contains n. Next n lines contain strings.", "output_format": "The resulting string.", "constraints": None,
        "prefix_code": "", "starter_code": "# Read input, process, and print the output\n", "suffix_code": "",
        "sample_input": "6\nh\nt\no\ny\nn\np", "sample_output": "python", "position": 5, "section": 2, "test_cases": tcs
    })

    # P6: Call Log Analysis
    p6 = probs[5]
    p6_sol = p6["solution"]
    p6_suffix = "import json\nlogs = json.loads(input())\ntask = input()\nprint(process_call_logs(logs, task))"
    logs_sample = '[{"name":"Alice","duration":300},{"name":"Bob","duration":200},{"name":"Alice","duration":100},{"name":"Bob","duration":400},{"name":"Charlie","duration":300}]'
    p6_cases = [
        (f"{logs_sample}\nget_call_counts", False),
        (f"{logs_sample}\nmost_frequent_caller", False),
        (f"{logs_sample}\nget_total_call_durations", True),
        ('[{"name":"Zoe","duration":50}]\nget_call_counts', True),
        ('[{"name":"A","duration":100},{"name":"B","duration":200},{"name":"A","duration":100}]\nmost_frequent_caller', True),
        ('[{"name":"X","duration":10},{"name":"Y","duration":20}]\nget_total_call_durations', True),
        ('[{"name":"P","duration":50},{"name":"Q","duration":100}]\nmost_frequent_caller', True),
        ('[{"name":"M","duration":10},{"name":"M","duration":20},{"name":"M","duration":30}]\nget_call_counts', True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p6_sol + "\n" + p6_suffix, inp), "is_hidden": hid} for inp, hid in p6_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P6: Call Log Analysis",
        "description": p6["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def process_call_logs(call_logs: list, task: str):\n    ", "suffix_code": p6_suffix,
        "sample_input": f"{logs_sample}\nmost_frequent_caller", "sample_output": "Bob", "position": 6, "section": 3, "test_cases": tcs
    })

    # P7: Reorder the Jumbled Lines (file-io type)
    p7 = probs[6]
    p7_sol = p7["solution"]
    s_inp1 = "first line\nsecond line\nthird line\nfourth line\n1-3,2-4,3-2,4-1"
    p7_cases = [
        (s_inp1, False),
        ("alpha\nbeta\n1-2,2-1", False),
        ("line A\nline B\nline C\n1-1,2-2,3-3", True),
        ("one\ntwo\nthree\n1-3,2-2,3-1", True),
        ("x\ny\nz\nw\n1-4,2-3,3-2,4-1", True),
        ("p\nq\n1-1,2-2", True),
        ("single\n1-1", True),
        ("a\nb\nc\nd\ne\n1-5,2-4,3-3,4-2,5-1", True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p7_sol, inp), "is_hidden": hid} for inp, hid in p7_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 2 · P7: Reorder the Jumbled Lines",
        "description": p7["statement"], "input_format": "Lines of text followed by the ordering permutation line.", "output_format": "Reordered text lines.", "constraints": None,
        "prefix_code": "", "starter_code": "# Read input, process, and print the output\n", "suffix_code": "",
        "sample_input": s_inp1, "sample_output": run_py(p7_sol, s_inp1), "position": 7, "section": 3, "test_cases": tcs
    })

    out_file = os.path.join(SEEDER_DIR, "python_oppe2_2024sep_set2.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2)
    print(f"Generated seeder: {out_file} (7 problems, {sum(len(x['test_cases']) for x in items)} test cases)")

def build_set3_ide():
    raw = json.load(open(os.path.join(SRC_DIR, "OPPE2_2024Sep_Set3.json")))
    probs = raw["problems"]
    items = []

    # P1: Product of Sum and Absolute Difference
    p1 = probs[0]
    p1_sol = p1["solution"]
    p1_suffix = "num = int(input())\nprint(product_of_sum_and_abs_diff(num))"
    p1_cases = [("54", False), ("62", False), ("10", True), ("99", True), ("83", True), ("44", True), ("71", True), ("25", True)]
    tcs = [{"input": inp, "expected_output": run_py(p1_sol + "\n" + p1_suffix, inp), "is_hidden": hid} for inp, hid in p1_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P1: Product of Sum and Absolute Difference",
        "description": p1["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def product_of_sum_and_abs_diff(num: int) -> int:\n    ", "suffix_code": p1_suffix,
        "sample_input": "54", "sample_output": "9", "position": 1, "section": 1, "test_cases": tcs
    })

    # P2: Check Divisibility by Last Two Digits
    p2 = probs[1]
    p2_sol = p2["solution"]
    p2_suffix = "num = int(input())\nprint(is_divisible_by_last_two_digits(num))"
    p2_cases = [("1236", False), ("345", False), ("748", True), ("740", True), ("12", True), ("24", True), ("105", True), ("224", True)]
    tcs = [{"input": inp, "expected_output": run_py(p2_sol + "\n" + p2_suffix, inp), "is_hidden": hid} for inp, hid in p2_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P2: Check Divisibility by Last Two Digits",
        "description": p2["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def is_divisible_by_last_two_digits(num: int) -> bool:\n    ", "suffix_code": p2_suffix,
        "sample_input": "1236", "sample_output": "True", "position": 2, "section": 1, "test_cases": tcs
    })

    # P3: Swap the Last Chars in Dictionary Values
    p3 = probs[2]
    p3_sol = p3["solution"]
    p3_suffix = "import json\nd = json.loads(input())\nk1 = input()\nk2 = input()\nswap_last_chars_of_values(d, k1, k2)\nprint(json.dumps(d, sort_keys=True))"
    p3_cases = [
        ('{"first": "apple", "second": "mango"}\nfirst\nsecond', False),
        ('{"key1": "hello", "key2": "world"}\nkey1\nkey2', False),
        ('{"a": "cat", "b": "dog"}\na\nb', True),
        ('{"x": "123", "y": "456"}\nx\ny', True),
        ('{"k1": "a", "k2": "b"}\nk1\nk2', True),
        ('{"m": "sun", "n": "moon"}\nm\nn', True),
        ('{"p": "test", "q": "code"}\np\nq', True),
        ('{"first": "red", "second": "blue"}\nfirst\nsecond', True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p3_sol + "\n" + p3_suffix, inp), "is_hidden": hid} for inp, hid in p3_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P3: Swap the Last Chars in Dictionary Values",
        "description": p3["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def swap_last_chars_of_values(d: dict, k1, k2) -> None:\n    ", "suffix_code": p3_suffix,
        "sample_input": '{"first": "apple", "second": "mango"}\nfirst\nsecond', "sample_output": '{"first": "applo", "second": "mange"}', "position": 3, "section": 1, "test_cases": tcs
    })

    # P4: Get Words That Come After "the"
    p4 = probs[3]
    p4_sol = p4["solution"]
    p4_suffix = "sentence = input()\nprint(words_after_the(sentence))"
    p4_cases = [
        ("The key and the lock is there", False),
        ("The the and the The", False),
        ("No articles here", True),
        ("The dog chased the cat into the garden", True),
        ("THE sun AND THE MOON", True),
        ("Where is the ball", True),
        ("the end", True),
        ("In the morning and at the night", True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p4_sol + "\n" + p4_suffix, inp), "is_hidden": hid} for inp, hid in p4_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P4: Get Words That Come After \"the\"",
        "description": p4["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "", "starter_code": "def words_after_the(sentence: str) -> list:\n    ", "suffix_code": p4_suffix,
        "sample_input": "The key and the lock is there", "sample_output": "['key', 'lock']", "position": 4, "section": 2, "test_cases": tcs
    })

    # P5: Ceil Marks to Nearest Tens if Close (io type)
    p5 = probs[4]
    p5_sol = p5["solution"]
    inp1 = "4\n48 48\n69 69\n70 70\n37 37"
    p5_cases = [
        (inp1, False),
        ("2\n10 18\n20 29", False),
        ("3\n1 55\n2 58\n3 59", True),
        ("1\n101 88", True),
        ("2\n5 80\n6 81", True),
        ("3\n7 78\n8 79\n9 80", True),
        ("2\n11 38\n12 37", True),
        ("1\n99 9", True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p5_sol, inp), "is_hidden": hid} for inp, hid in p5_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P5: Ceil Marks to Nearest Tens if Close",
        "description": p5["statement"], "input_format": "Number of students n, followed by roll and marks.", "output_format": "Updated roll and marks separated by comma.", "constraints": None,
        "prefix_code": "", "starter_code": "# Read input, process, and print the output\n", "suffix_code": "",
        "sample_input": inp1, "sample_output": run_py(p5_sol, inp1), "position": 5, "section": 2, "test_cases": tcs
    })

    # P6: Cartesian Points Processing
    p6 = probs[5]
    p6_sol = p6["solution"]
    p6_suffix = "import json\npts = set(tuple(p) for p in json.loads(input()))\ntask = input()\nres = process_points(pts, task)\nif isinstance(res, dict):\n    print({k: sorted(list(v)) for k, v in res.items()})\nelse:\n    print(res)"
    pts_sample = '[[2,5],[-2,6],[-2,7],[-1,3],[-3,-4],[4,-6],[0,7]]'
    p6_cases = [
        (f"{pts_sample}\nsort_close_to_y_axis", False),
        (f"{pts_sample}\nclosest_point_to_origin", False),
        (f"{pts_sample}\ngroup_by_quadrant", True),
        ('[[1,1],[-1,-1]]\nsort_close_to_y_axis', True),
        ('[[3,4],[1,1]]\nclosest_point_to_origin', True),
        ('[[5,5],[-5,5],[-5,-5],[5,-5]]\ngroup_by_quadrant', True),
        ('[[1,2],[-1,2],[1,-2]]\nsort_close_to_y_axis', True),
        ('[[10,10],[2,2]]\nclosest_point_to_origin', True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p6_sol + "\n" + p6_suffix, inp), "is_hidden": hid} for inp, hid in p6_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P6: Cartesian Points Processing",
        "description": p6["statement"], "input_format": None, "output_format": None, "constraints": None,
        "prefix_code": "import math\n\ndef get_angle(point):\n    x, y = point\n    return math.atan2(y, x)\n",
        "starter_code": "def process_points(points, task):\n    ", "suffix_code": p6_suffix,
        "sample_input": f"{pts_sample}\nclosest_point_to_origin", "sample_output": "(-1, 3)", "position": 6, "section": 3, "test_cases": tcs
    })

    # P7: Fill the First n Blanks with 1 to n (file-io type)
    p7 = probs[6]
    p7_sol = p7["solution"]
    sample_p7 = "11\na_bc__d___e\nf_g__h__i__j\nk___l_m__n"
    p7_cases = [
        (sample_p7, False),
        ("3\na_b_c_", False),
        ("2\n__\n__", True),
        ("5\nhello_world_test_", True),
        ("1\n_a_", True),
        ("4\n1_2_3_4_5_", True),
        ("0\na_b_c", True),
        ("6\n___a___b", True)
    ]
    tcs = [{"input": inp, "expected_output": run_py(p7_sol, inp), "is_hidden": hid} for inp, hid in p7_cases]
    items.append({
        "title": "OPPE 2 (2024 Sep) Set 3 · P7: Fill the First n Blanks with 1 to n",
        "description": p7["statement"], "input_format": "Integer n followed by multiline text with blanks.", "output_format": "The text with first n blanks filled sequentially.", "constraints": None,
        "prefix_code": "", "starter_code": "# Read input, process, and print the output\n", "suffix_code": "",
        "sample_input": sample_p7, "sample_output": run_py(p7_sol, sample_p7), "position": 7, "section": 3, "test_cases": tcs
    })

    out_file = os.path.join(SEEDER_DIR, "python_oppe2_2024sep_set3.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2)
    print(f"Generated seeder: {out_file} (7 problems, {sum(len(x['test_cases']) for x in items)} test cases)")


# ------------------------------------------------------------------------------
# STEP 2: CONVERT ALL 16 OPPE SETS TO SCHEMA 1.1 QUIZ PAPERS (bulk_quizzes/Python)
# ------------------------------------------------------------------------------

def convert_all_to_quizzes():
    files = sorted(os.listdir(SRC_DIR))
    print(f"\nConverting {len(files)} OPPE sets into Schema 1.1 Quiz papers in bulk_quizzes/Python/ ...")

    converted_count = 0
    total_q_count = 0

    for fname in files:
        if not fname.endswith(".json"):
            continue

        raw = json.load(open(os.path.join(SRC_DIR, fname), encoding="utf-8"))
        exam = raw.get("exam", "OPPE")
        year = raw.get("year", "")
        set_name = raw.get("set", "")
        problems = raw.get("problems", [])

        # Paper title: Python · OPPE 1 · 2024 Sep · Set 1
        quiz_title = f"Python · {exam} · {year} · {set_name}"
        clean_file = f"Python_-_" + fname.replace(".json", "") + ".json"

        questions = []
        for i, p in enumerate(problems, 1):
            title = p.get("title", f"Problem {i}")
            sec_label = p.get("section_label", f"Section {p.get('section', 1)}")
            stmt = p.get("statement", "")
            qtype = p.get("qtype", "function")
            examples = p.get("examples", "")
            template = p.get("answer_template", "")
            solution = p.get("solution", "")

            prompt_blocks = [
                {
                    "kind": "text",
                    "value": f"**{sec_label}: {title}** ({qtype.capitalize()} Type)\n\n{stmt}"
                }
            ]
            if template.strip():
                prompt_blocks.append({
                    "kind": "code",
                    "language": "python",
                    "value": template
                })

            explanation_blocks = []
            if examples.strip():
                explanation_blocks.append({
                    "kind": "text",
                    "value": f"**Sample Test Cases / Examples:**\n\n```text\n{examples}\n```"
                })
            explanation_blocks.append({
                "kind": "text",
                "value": "**Verified Reference Solution:**"
            })
            explanation_blocks.append({
                "kind": "code",
                "language": "python",
                "value": solution
            })

            # For function type, acceptable answer is the function name; for IO type, sample output or 'python'
            acceptable = [title]
            if "def " in template:
                fn_name = template.split("def ")[1].split("(")[0].strip()
                acceptable.append(fn_name)

            q_obj = {
                "type": "short_answer",
                "prompt": prompt_blocks,
                "acceptable_answers": acceptable,
                "marks": 5,
                "difficulty": "medium",
                "explanation": explanation_blocks
            }
            questions.append(q_obj)

        quiz_data = {
            "schema_version": "1.1",
            "quiz_title": quiz_title,
            "subject": "Python",
            "section": "mock_test",
            "questions": questions
        }

        out_path = os.path.join(QUIZ_DIR, clean_file)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(quiz_data, f, indent=2, ensure_ascii=False)

        print(f"  [OK] {clean_file} ({len(questions)} Qs, {quiz_title})")
        converted_count += 1
        total_q_count += len(questions)

    print(f"\nQuiz conversion finished: {converted_count} papers generated with {total_q_count} total questions in bulk_quizzes/Python/.")

def main():
    print("=== Step 1: Building Missing IDE Seeders ===")
    build_set2_ide()
    build_set3_ide()

    print("\n=== Step 2: Converting OPPE Sets to Schema 1.1 Papers ===")
    convert_all_to_quizzes()

if __name__ == "__main__":
    main()
