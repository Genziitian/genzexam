#!/usr/bin/env python3
"""
Diploma Courses + Maths/Eng fix → Quiz Lab JSON Converter

Handles:
1. Combined IIT M Diploma exam PDFs (Quiz1/Quiz2/EndTerm) with multiple subjects per file
2. Maths PA PDFs with © or ⃝ option markers and (Ans: (a),(c)) answer format
3. English Graded PDFs with (True)/(False) inline answers and "Ans: c" format

Output: bulk_quizzes/Diploma/<Subject>/<Term>_<ExamType>_<Date>.json
        bulk_quizzes/<Subject (fixed)>/...json  (for maths/eng fixes)
"""

import os, re, json
import pypdf

OUT_ROOT  = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes')
DOWNLOADS = os.path.expanduser('~/Downloads')
DIPLOMA   = os.path.join(DOWNLOADS, 'Diploma Courses')

# ── Subject name normalisation ───────────────────────────────────────────────
SUBJECT_NORM = {
    'maths2': 'Mathematics 2',
    'maths 2': 'Mathematics 2',
    'maths1': 'Mathematics 1',
    'maths 1': 'Mathematics 1',
    'statistics2': 'Statistics 2',
    'statistics 2': 'Statistics 2',
    'statistics1': 'Statistics 1',
    'statistics 1': 'Statistics 1',
    'ct': 'Computational Thinking',
    'sem1 ct': 'Computational Thinking',
    'intro to python': 'Python Programming',
    'sem2 intro to python': 'Python Programming',
    'sem2 intro to python': 'Python Programming',
    'dbms': 'DBMS',
    'pdsa': 'PDSA',
    'appdev1': 'Modern Application Development 1',
    'appdev2': 'Modern Application Development 2',
    'mlf': 'Machine Learning Foundations',
    'mlt': 'Machine Learning Techniques',
    'mlp': 'Machine Learning Practice',
    'bdm': 'Business Data Management',
    'business analytics': 'Business Analytics',
    'system commands': 'System Commands',
    'java': 'Java',
}

def norm_subject(raw):
    key = raw.strip().lower()
    return SUBJECT_NORM.get(key, raw.strip().title())

# ── Helpers ───────────────────────────────────────────────────────────────────

def clean(s):
    return re.sub(r'\s+', ' ', str(s)).strip()

def text_block(val):
    return [{"kind": "text", "value": clean(val)}]

def safe_filename(s):
    return re.sub(r'[^\w\- ]', '_', s)[:80].strip()

def extract_pdf_text(path):
    reader = pypdf.PdfReader(path)
    return '\n'.join(page.extract_text() or '' for page in reader.pages)

# ── ① DIPLOMA COMBINED PDF PARSER ────────────────────────────────────────────
# Each PDF has sections: "Maths2\nSection Id : ..."
# Questions follow the same IIT M qualifier format

SKIP_RE = re.compile(
    r'^(Response Type|Evaluation Required|Show Word Count|'
    r'Answers Type|Text Areas|Sub-Section|Group|Question Label|'
    r'Question Shuffling|Question Numbers|Max\. Selectable|'
    r'Is Question Mandatory|Calculator|Response Time|Think Time|'
    r'Minimum Instruction|Is Section Default|Enable Mark|'
    r'Display Number|Group All|Section Negative|Section type|'
    r'Mandatory or Optional|Number of Questions|Section Marks)',
    re.I
)
OPT_ID_RE   = re.compile(r'^(\d{10,})\.\s*(.*)')
POSSIBLE_RE = re.compile(r'Possible Answers?\s*:', re.I)
MARKS_RE    = re.compile(r'Correct Marks\s*:\s*(\d+(?:\.\d+)?)', re.I)
Q_HEADER_RE = re.compile(
    r'Question Number\s*:\s*(\d+)\s+'
    r'Question Id\s*:\s*\S+\s+'
    r'Question Type\s*:\s*(MCQ|MSQ|SA|NAT)',
    re.I
)
COMP_RE = re.compile(r'Question Numbers\s*:\s*\((\d+)\s+to\s+(\d+)\)', re.I)

def parse_section_body(body_text):
    """Parse one subject-section from a combined diploma PDF."""
    questions = []
    blocks = re.split(r'(?=Question Number\s*:\s*\d+)', body_text)

    comp_stmt  = ''
    comp_range = (0, 0)

    for raw_block in blocks:
        m = Q_HEADER_RE.search(raw_block)
        if not m:
            # Comprehension block?
            if 'COMPREHENSION' in raw_block.upper():
                rm = COMP_RE.search(raw_block)
                if rm:
                    comp_range = (int(rm.group(1)), int(rm.group(2)))
                comp_lines = [
                    l.strip() for l in raw_block.splitlines()
                    if l.strip() and not SKIP_RE.match(l.strip())
                    and 'COMPREHENSION' not in l.upper()
                    and not re.match(r'Question Id', l)
                ]
                comp_stmt = clean(' '.join(comp_lines))
            continue

        q_num  = int(m.group(1))
        q_type = m.group(2).upper()

        marks_m = MARKS_RE.search(raw_block)
        marks = float(marks_m.group(1)) if marks_m else 1.0
        if marks == 0:
            continue  # skip instructions

        comp_prefix = comp_stmt if comp_range[0] <= q_num <= comp_range[1] else ''

        header_end = raw_block.find(m.group(0)) + len(m.group(0))
        body = raw_block[header_end:]
        body_lines = [l.strip() for l in body.splitlines() if l.strip()]

        stmt_lines   = []
        options      = []
        answer_lines = []
        in_possible  = False
        in_options   = False

        for ln in body_lines:
            if MARKS_RE.match(ln):
                continue
            if SKIP_RE.match(ln):
                in_possible = False
                continue
            if re.match(r'^Options\s*:', ln, re.I):
                in_options = True
                continue
            opt_m = OPT_ID_RE.match(ln)
            if opt_m:
                in_options = True
                t = opt_m.group(2).strip()
                if t:
                    options.append(t)
                continue
            if POSSIBLE_RE.match(ln):
                in_possible = True
                rest = re.sub(r'^Possible Answers?\s*:', '', ln, flags=re.I).strip()
                if rest:
                    answer_lines.append(rest)
                continue
            if in_possible:
                answer_lines.append(ln)
                continue
            if in_options:
                if options:
                    options[-1] = (options[-1] + ' ' + ln).strip()
                continue
            stmt_lines.append(ln)

        full_stmt = clean(' '.join(filter(None, [comp_prefix, ' '.join(stmt_lines)])))
        if not full_stmt:
            continue

        answer_raw = clean(' '.join(answer_lines))

        q = None
        if q_type in ('SA', 'NAT') and answer_raw:
            try:
                num = float(answer_raw)
                q = {
                    "type": "numerical",
                    "prompt": text_block(full_stmt),
                    "numerical_answer": num,
                    "numerical_tolerance": 0.01,
                    "marks": max(1, int(marks)),
                    "difficulty": "medium",
                }
            except ValueError:
                q = {
                    "type": "short_answer",
                    "prompt": text_block(full_stmt),
                    "acceptable_answers": [answer_raw],
                    "marks": max(1, int(marks)),
                    "difficulty": "medium",
                }
        elif q_type in ('MCQ', 'MSQ') and options:
            opt_blocks = [[{"kind": "text", "value": o}] for o in options]
            if q_type == 'MSQ':
                q = {
                    "type": "mcq_multi",
                    "prompt": text_block(full_stmt),
                    "options": opt_blocks,
                    "correct_answers": [0],
                    "marks": max(1, int(marks)),
                    "difficulty": "medium",
                }
            else:
                q = {
                    "type": "mcq_single",
                    "prompt": text_block(full_stmt),
                    "options": opt_blocks,
                    "correct_answer": 0,
                    "marks": max(1, int(marks)),
                    "difficulty": "medium",
                }
        # else: image-only MCQ → skip

        if q:
            questions.append(q)

    return questions


def split_and_parse_diploma_pdf(pdf_path, exam_type, term_label):
    """
    Split a combined diploma PDF into per-subject JSON outputs.
    Returns list of (subject, questions) tuples.
    """
    text = extract_pdf_text(pdf_path)

    # Split on section headers: "<SubjectName>\nSection Id : ..."
    # Pattern: a non-metadata line followed immediately by "Section Id"
    parts = re.split(r'\n([A-Za-z][A-Za-z\s\d\-&]{2,40})\nSection Id', text)

    results = []
    # parts[0] = preamble, then pairs of (subject_name, body)
    for i in range(1, len(parts), 2):
        raw_subj = parts[i].strip()
        body = parts[i + 1] if i + 1 < len(parts) else ''
        subject = norm_subject(raw_subj)
        questions = parse_section_body(body)
        if questions:
            results.append((subject, questions))

    return results


# ── ② MATHS PA FIX: © / ⃝ format ────────────────────────────────────────────

def parse_maths_circle_format(text, week, quiz_title):
    """
    Handle Maths PA PDFs where options use © or ⃝ symbols.
    Answer appears as: (Ans: (a), (c)) before the options,
    OR correct options have ✓ after them.
    """
    questions = []
    lines = text.splitlines()

    # Normalise circle symbols to a common marker
    CIRCLE = '©'
    TICK   = '✓'

    # Pattern: "N. question text" then options starting with © or ⃝
    q_pat   = re.compile(r'^(\d+)\.\s+(.+)')
    ans_pat = re.compile(r'\(?Ans(?:wer)?\s*:\s*(.+?)\)?$', re.I)
    num_pat = re.compile(r'^-?\d+(\.\d+)?$')

    i = 0
    while i < len(lines):
        ln = lines[i].strip()

        m = q_pat.match(ln)
        if not m:
            i += 1
            continue

        q_num = int(m.group(1))
        q_text_lines = [m.group(2).strip()]
        i += 1

        # Collect question text, look for (Ans: ...) inline or on next lines
        # Stop when we hit option lines (© / ⃝)
        pre_answer = None
        while i < len(lines):
            l2 = lines[i].strip()
            # Inline answer before options?
            am = ans_pat.search(l2)
            if am and ('©' not in l2 and '⃝' not in l2):
                pre_answer = am.group(1).strip()
                i += 1
                continue
            # Option line
            if l2.startswith('©') or l2.startswith('⃝'):
                break
            # Next question
            if q_pat.match(l2):
                break
            if l2 and l2.lower() not in ('solution:', 'solution'):
                q_text_lines.append(l2)
            i += 1

        full_stmt = clean(' '.join(q_text_lines))
        if not full_stmt:
            continue

        # Collect options (© or ⃝ prefixed lines)
        raw_options = []
        while i < len(lines):
            l2 = lines[i].strip()
            if l2.startswith('©') or l2.startswith('⃝'):
                opt_text = re.sub(r'^[©⃝]\s*', '', l2).strip()
                is_correct = TICK in opt_text
                opt_text = opt_text.replace(TICK, '').strip()
                raw_options.append({'text': opt_text, 'correct': is_correct})
                i += 1
            elif raw_options and l2 and not q_pat.match(l2) and not ans_pat.search(l2):
                # Continuation of last option
                raw_options[-1]['text'] = (raw_options[-1]['text'] + ' ' + l2).strip()
                i += 1
            else:
                break

        # Skip solution lines
        while i < len(lines):
            l2 = lines[i].strip()
            if l2.lower().startswith('solution'):
                i += 1
                # skip until next question or option
                while i < len(lines) and not q_pat.match(lines[i].strip()):
                    i += 1
                break
            break

        if not raw_options:
            # No options extracted — try as numerical/short_answer
            if pre_answer:
                try:
                    num = float(pre_answer.replace(',', ''))
                    questions.append({
                        "type": "numerical",
                        "prompt": text_block(full_stmt),
                        "numerical_answer": num,
                        "numerical_tolerance": 0.01,
                        "marks": 2,
                        "difficulty": "medium",
                    })
                except ValueError:
                    questions.append({
                        "type": "short_answer",
                        "prompt": text_block(full_stmt),
                        "acceptable_answers": [pre_answer],
                        "marks": 2,
                        "difficulty": "medium",
                    })
            continue

        opt_blocks = [[{"kind": "text", "value": o['text']}] for o in raw_options if o['text']]
        correct_indices = [idx for idx, o in enumerate(raw_options) if o['correct']]

        # If no ✓ markers, use (Ans: ...) to determine correct
        if not correct_indices and pre_answer:
            # parse letters from "(a), (c)" or "a, c" or "b"
            letters = re.findall(r'[a-e]', pre_answer.lower())
            letter_map = {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4}
            correct_indices = [letter_map[l] for l in letters if l in letter_map and letter_map[l] < len(opt_blocks)]

        if not correct_indices:
            correct_indices = [0]  # fallback

        if len(correct_indices) > 1:
            q = {
                "type": "mcq_multi",
                "prompt": text_block(full_stmt),
                "options": opt_blocks,
                "correct_answers": correct_indices,
                "marks": 2,
                "difficulty": "medium",
            }
        else:
            q = {
                "type": "mcq_single",
                "prompt": text_block(full_stmt),
                "options": opt_blocks,
                "correct_answer": correct_indices[0],
                "marks": 2,
                "difficulty": "medium",
            }
        questions.append(q)

    return questions


# ── ③ ENGLISH FIX: inline (True)/(False) and "Ans: c" format ────────────────

def parse_english_inline_format(text, week, quiz_title):
    """
    Handle English Graded PDFs where:
    - T/F: "1. Statement text. (True)" or "(False)"
    - MCQ: options "a) text", answer "Ans: c"
    """
    questions = []
    lines = text.splitlines()

    q_pat  = re.compile(r'^\s*(\d+)\.\s+(.+)')
    opt_pat = re.compile(r'^\s*([a-dA-D])\)\s*(.*)')
    ans_pat = re.compile(r'^Ans\s*:\s*([a-dA-D])', re.I)
    tf_inline = re.compile(r'\(?(True|False)\)?\.?\s*$', re.I)

    i = 0
    while i < len(lines):
        ln = lines[i].strip()
        m = q_pat.match(ln)
        if not m:
            i += 1
            continue

        q_num = int(m.group(1))
        q_text = m.group(2).strip()
        i += 1

        # Collect rest of question text (before options or answer)
        q_lines = [q_text]
        while i < len(lines):
            l2 = lines[i].strip()
            if opt_pat.match(l2) or ans_pat.match(l2) or q_pat.match(l2):
                break
            if l2 and l2.lower() not in ('answer:', 'solution'):
                q_lines.append(l2)
            i += 1

        full_text = clean(' '.join(q_lines))

        # Check for inline T/F: "Statement text. (True)"
        tf_m = tf_inline.search(full_text)
        if tf_m:
            stmt = tf_inline.sub('', full_text).strip().rstrip('.')
            correct = tf_m.group(1).lower() == 'true'
            questions.append({
                "type": "true_false",
                "prompt": text_block(stmt),
                "correct_answer": correct,
                "marks": 1,
                "difficulty": "easy",
            })
            continue

        # Collect options
        options = []
        while i < len(lines):
            l2 = lines[i].strip()
            om = opt_pat.match(l2)
            if om:
                options.append(om.group(2).strip())
                i += 1
            elif options and l2 and not ans_pat.match(l2) and not q_pat.match(l2):
                options[-1] = (options[-1] + ' ' + l2).strip()
                i += 1
            else:
                break

        # Get answer
        answer_letter = None
        while i < len(lines):
            l2 = lines[i].strip()
            am = ans_pat.match(l2)
            if am:
                answer_letter = am.group(1).lower()
                i += 1
                # skip explanation lines
                while i < len(lines):
                    l3 = lines[i].strip()
                    if q_pat.match(l3) or (l3 and l3[0].isdigit()):
                        break
                    i += 1
                break
            break

        if not full_text:
            continue

        if options and answer_letter:
            letter_map = {'a': 0, 'b': 1, 'c': 2, 'd': 3}
            idx = letter_map.get(answer_letter, 0)
            idx = min(idx, len(options) - 1)
            opt_blocks = [[{"kind": "text", "value": o}] for o in options]
            questions.append({
                "type": "mcq_single",
                "prompt": text_block(full_text),
                "options": opt_blocks,
                "correct_answer": idx,
                "marks": 1,
                "difficulty": "easy",
            })
        elif not options:
            questions.append({
                "type": "short_answer",
                "prompt": text_block(full_text),
                "acceptable_answers": [answer_letter or "See solution"],
                "marks": 1,
                "difficulty": "easy",
            })

    return questions


# ── Build JSON payload ────────────────────────────────────────────────────────

def build_json(subject, section, week, quiz_title, questions):
    payload = {
        "schema_version": "1.1",
        "quiz_title": quiz_title,
        "subject": subject,
        "section": section,
        "questions": questions,
    }
    if week is not None:
        payload["week"] = week
    return payload


# ── Determine exam type from path ─────────────────────────────────────────────

def get_section_from_path(path):
    p = path.lower()
    if 'quiz1' in p or 'quiz_1' in p or 'quiz 1' in p:
        return 'quiz1'
    if 'quiz2' in p or 'quiz_2' in p or 'quiz 2' in p:
        return 'quiz2'
    if 'end_term' in p or 'endterm' in p or 'et ' in p:
        return 'endterm'
    return 'mock_test'

def get_term_label(path):
    """Extract term like 'Jan 2023', 'May 2024' from path."""
    m = re.search(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[_\s]*(\d{4}|\d{2})', path, re.I)
    if m:
        return f"{m.group(1)} {m.group(2)}"
    return os.path.basename(os.path.dirname(path))


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    total_ok = 0
    total_fail = 0
    total_qs = 0

    # ── Part A: Diploma combined exam PDFs ──────────────────────────────────
    print("=" * 60)
    print("PART A: Diploma Exam PDFs")
    print("=" * 60)

    exam_pdfs = []
    for root, dirs, files in os.walk(DIPLOMA):
        for f in files:
            if f.endswith('.pdf') and any(x in root for x in ['Quiz1_pyq', 'Quiz2_pyq', 'End_Term_pyq']):
                exam_pdfs.append(os.path.join(root, f))

    exam_pdfs.sort()

    for pdf_path in exam_pdfs:
        section   = get_section_from_path(pdf_path)
        term      = get_term_label(pdf_path)
        fname_base = safe_filename(os.path.splitext(os.path.basename(pdf_path))[0])

        try:
            results = split_and_parse_diploma_pdf(pdf_path, section, term)
        except Exception as e:
            print(f"  [ERROR] {pdf_path}: {e}")
            total_fail += 1
            continue

        if not results:
            print(f"  [WARN] No questions extracted: {pdf_path}")
            total_fail += 1
            continue

        for subject, questions in results:
            subj_dir = os.path.join(OUT_ROOT, 'Diploma', subject)
            os.makedirs(subj_dir, exist_ok=True)
            quiz_title = f"{term} {section.replace('_', ' ').title()}"
            payload = build_json(subject, section, None, quiz_title, questions)
            out_name = f"{term.replace(' ', '_')}_{section}_{safe_filename(subject)}.json"
            out_path = os.path.join(subj_dir, out_name)
            with open(out_path, 'w', encoding='utf-8') as fp:
                json.dump(payload, fp, ensure_ascii=False, indent=2)
            print(f"  [OK] Diploma/{subject}/{out_name}  ({len(questions)} q)")
            total_ok += 1
            total_qs += len(questions)

    # ── Part B: Fix skipped Maths PA PDFs ───────────────────────────────────
    print()
    print("=" * 60)
    print("PART B: Maths PA Fix (© format)")
    print("=" * 60)

    MATHS_FIX = [
        (3,  '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 3 Practice Assignment Solution.pdf'),
        (4,  '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 4 Practice Assignment Solution.pdf'),
        (6,  '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 6 practice assignment solution.pdf'),
        (7,  '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 7 practice assignment solution.pdf'),
        (8,  '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 8 Practice Assignment Solution.pdf'),
        (10, '/Users/tusharrrsingh/Downloads/maths I/PA solutions/Week 10 Practice Assignment Solution.pdf'),
    ]

    for week, path in MATHS_FIX:
        if not os.path.exists(path):
            print(f"  [SKIP] Not found: {path}")
            continue
        try:
            text = extract_pdf_text(path)
            questions = parse_maths_circle_format(text, week, f'Week {week} Practice Assignment')
        except Exception as e:
            print(f"  [ERROR] {path}: {e}")
            total_fail += 1
            continue

        if not questions:
            print(f"  [WARN] 0 questions: {path}")
            total_fail += 1
            continue

        subj_dir = os.path.join(OUT_ROOT, 'Mathematics 1')
        os.makedirs(subj_dir, exist_ok=True)
        payload = build_json('Mathematics 1', 'practice', week, f'Week {week} Practice Assignment', questions)
        out_path = os.path.join(subj_dir, f'W{week:02d}_PA_Week_{week}_Practice_Assignment.json')
        with open(out_path, 'w', encoding='utf-8') as fp:
            json.dump(payload, fp, ensure_ascii=False, indent=2)
        print(f"  [OK] Mathematics 1/W{week:02d}_PA  ({len(questions)} q)")
        total_ok += 1
        total_qs += len(questions)

    # ── Part C: Fix English Week 3 ───────────────────────────────────────────
    print()
    print("=" * 60)
    print("PART C: English Week 3 Fix (inline T/F format)")
    print("=" * 60)

    ENG_FIX = [
        (3, '/Users/tusharrrsingh/Downloads/eng 1/GRADED SOLUTIONS/WEEK 3.pdf'),
    ]

    for week, path in ENG_FIX:
        if not os.path.exists(path):
            print(f"  [SKIP] Not found: {path}")
            continue
        try:
            text = extract_pdf_text(path)
            questions = parse_english_inline_format(text, week, f'Week {week} Graded Assignment')
        except Exception as e:
            print(f"  [ERROR] {path}: {e}")
            total_fail += 1
            continue

        if not questions:
            print(f"  [WARN] 0 questions: {path}")
            total_fail += 1
            continue

        subj_dir = os.path.join(OUT_ROOT, 'English 1')
        os.makedirs(subj_dir, exist_ok=True)
        payload = build_json('English 1', 'practice_graded', week, f'Week {week} Graded Assignment', questions)
        out_path = os.path.join(subj_dir, f'W{week:02d}_GA_Week_{week}_Graded_Assignment.json')
        with open(out_path, 'w', encoding='utf-8') as fp:
            json.dump(payload, fp, ensure_ascii=False, indent=2)
        print(f"  [OK] English 1/W{week:02d}_GA  ({len(questions)} q)")
        total_ok += 1
        total_qs += len(questions)

    # ── Summary ─────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print(f"DONE: {total_ok} files created | {total_fail} failed | {total_qs} total questions")
    print(f"Output: {os.path.abspath(OUT_ROOT)}")
    print("=" * 60)


if __name__ == '__main__':
    main()
