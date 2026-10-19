#!/usr/bin/env python3
"""Checks every paper in docs/question-extraction/verified-batch-manifest.json before it is pushed.
Run from the project root:  python3 tools/validate_verified_papers.py
Exit code 1 if anything is wrong. Rules come from AGENTS.md (5-10 questions, schema 1.1, self-contained)."""
import json, os, re, subprocess, sys

MANIFEST = "docs/question-extraction/verified-batch-manifest.json"
TYPES = {"mcq_single", "mcq_multi", "numerical", "short_answer"}
SECTIONS = {"quiz1", "quiz2", "endterm", "practice", "practice_graded", "mock_test"}
IMG = re.compile(r"assets/exam-examples/question-crops/[^\"\\)\s<>]+")

tracked = set(subprocess.run(["git", "ls-files", "assets/exam-examples/question-crops"], capture_output=True, text=True).stdout.split("\n"))
errors, seen = [], set()

def bad(path, msg): errors.append(f"{path}: {msg}")

for entry in json.load(open(MANIFEST))["files"]:
    path, subject = entry["path"], entry["subject"]
    if os.path.dirname(path) != f"bulk_quizzes/{subject}": bad(path, f"folder does not match subject '{subject}'"); continue
    try: raw = open(path).read(); paper = json.loads(raw)
    except Exception as e: bad(path, f"cannot read/parse ({e})"); continue
    if paper.get("schema_version") != "1.1": bad(path, "schema_version must be 1.1")
    if paper.get("subject") != subject: bad(path, f"subject field is '{paper.get('subject')}', folder says '{subject}'")
    if paper.get("section") not in SECTIONS: bad(path, f"unknown section '{paper.get('section')}'")
    key = (subject, paper.get("quiz_title"))
    if not paper.get("quiz_title") or key in seen: bad(path, "missing or duplicate quiz_title in this subject")
    seen.add(key)
    qs = paper.get("questions") or []
    if not 5 <= len(qs) <= 10: bad(path, f"{len(qs)} questions (must be 5 to 10)")
    for i, q in enumerate(qs, 1):
        t = q.get("type")
        if t not in TYPES or not q.get("prompt"): bad(path, f"Q{i}: bad type or empty prompt"); continue
        n = len(q.get("options") or [])
        if t in ("mcq_single", "mcq_multi") and n < 2: bad(path, f"Q{i}: needs at least 2 options")
        if t == "mcq_single" and not (isinstance(q.get("correct_answer"), int) and 0 <= q["correct_answer"] < n): bad(path, f"Q{i}: correct_answer out of range")
        if t == "mcq_multi" and not (q.get("correct_answers") and all(isinstance(a, int) and 0 <= a < n for a in q["correct_answers"])): bad(path, f"Q{i}: correct_answers invalid")
        if t == "numerical" and not isinstance(q.get("numerical_answer"), (int, float)): bad(path, f"Q{i}: numerical_answer missing")
        if t == "short_answer" and not q.get("acceptable_answers"): bad(path, f"Q{i}: acceptable_answers missing")
    for img in set(IMG.findall(raw)):
        if not os.path.isfile(img): bad(path, f"image missing on disk: {img}")
        elif img not in tracked: bad(path, f"image not committed to git: {img}")

print(f"{len(errors)} problem(s)" if errors else "All verified papers are valid.")
for e in errors[:60]: print(" -", e)
sys.exit(1 if errors else 0)
