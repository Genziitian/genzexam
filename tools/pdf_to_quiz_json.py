#!/usr/bin/env python3
"""
PDF → Quiz Lab JSON Converter
Converts IIT-Madras style question-paper PDFs into bulk-import-ready JSON.
Usage: python3 pdf_to_quiz_json.py
"""

import os, re, json, sys
import pypdf

# ── Output root ─────────────────────────────────────────────────────────────
OUT_ROOT = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes')
DOWNLOADS = os.path.expanduser('~/Downloads')

# ── PDF catalogue: (subject_folder_name, section, week_number_or_None, pdf_path, quiz_title) ──
PDFS = [
    # ── Computational Thinking ───────────────────────────────────────────
    ('Computational Thinking', 'practice', 1,  os.path.join(DOWNLOADS, 'ct/practice assignment solution /Week 1 PA Solution.pdf'), 'Week 1 Practice Assignment'),
    ('Computational Thinking', 'practice', 2,  os.path.join(DOWNLOADS, 'ct/practice assignment solution /Week 2 PA Solution.pdf'), 'Week 2 Practice Assignment'),
    ('Computational Thinking', 'practice', 3,  os.path.join(DOWNLOADS, 'ct/practice assignment solution /Week 3 PA Solution.pdf'), 'Week 3 Practice Assignment'),
    ('Computational Thinking', 'practice', 4,  os.path.join(DOWNLOADS, 'ct/practice assignment solution /Week 4 PA Solution.pdf'), 'Week 4 Practice Assignment'),
    ('Computational Thinking', 'practice_graded', 1,  os.path.join(DOWNLOADS, 'ct/GA Solutions/Week 1 GA .pdf'), 'Week 1 Graded Assignment'),
    ('Computational Thinking', 'practice_graded', 2,  os.path.join(DOWNLOADS, 'ct/GA Solutions/Week 2 GA.pdf'), 'Week 2 Graded Assignment'),
    ('Computational Thinking', 'practice_graded', 3,  os.path.join(DOWNLOADS, 'ct/GA Solutions/Week 3 GA.pdf'), 'Week 3 Graded Assignment'),
    ('Computational Thinking', 'practice_graded', 4,  os.path.join(DOWNLOADS, 'ct/GA Solutions/Week 4 GA.pdf'), 'Week 4 Graded Assignment'),
    ('Computational Thinking', 'mock_test',  None, os.path.join(DOWNLOADS, 'ct/DS_Qualifier/IIT M QUALIFIER AN EXAM QDQ1.pdf'), 'DS Qualifier Exam QDQ1'),
    ('Computational Thinking', 'mock_test',  None, os.path.join(DOWNLOADS, 'ct/DS_Qualifier/IIT M QUALIFIER AN EXAM QDQ2.pdf'), 'DS Qualifier Exam QDQ2'),

    # ── English 1 ────────────────────────────────────────────────────────
    ('English 1', 'practice_graded', 1,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 1.pdf'), 'Week 1 Graded Assignment'),
    ('English 1', 'practice_graded', 2,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 2.pdf'), 'Week 2 Graded Assignment'),
    ('English 1', 'practice_graded', 3,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 3.pdf'), 'Week 3 Graded Assignment'),
    ('English 1', 'practice_graded', 4,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 4.pdf'), 'Week 4 Graded Assignment'),
    ('English 1', 'practice_graded', 5,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 5.pdf'), 'Week 5 Graded Assignment'),
    ('English 1', 'practice_graded', 6,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 6.pdf'), 'Week 6 Graded Assignment'),
    ('English 1', 'practice_graded', 7,  os.path.join(DOWNLOADS, 'eng 1/GRADED SOLUTIONS/WEEK 7.pdf'), 'Week 7 Graded Assignment'),
    ('English 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'eng 1/IIT M QUALIFIER AN EXAM QDQ1.pdf'), 'Qualifier Exam QDQ1'),
    ('English 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'eng 1/IIT M QUALIFIER AN EXAM QDQ2.pdf'), 'Qualifier Exam QDQ2'),

    # ── Mathematics 1 ────────────────────────────────────────────────────
    ('Mathematics 1', 'practice', 1,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 1 Practice Assignment Solution.pdf'), 'Week 1 Practice Assignment'),
    ('Mathematics 1', 'practice', 2,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 2 Practice Assignment Solution.pdf'), 'Week 2 Practice Assignment'),
    ('Mathematics 1', 'practice', 3,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 3 Practice Assignment Solution.pdf'), 'Week 3 Practice Assignment'),
    ('Mathematics 1', 'practice', 4,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 4 Practice Assignment Solution.pdf'), 'Week 4 Practice Assignment'),
    ('Mathematics 1', 'practice', 5,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 5  Practice Assignment Solution.pdf'), 'Week 5 Practice Assignment'),
    ('Mathematics 1', 'practice', 6,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 6 practice assignment solution.pdf'), 'Week 6 Practice Assignment'),
    ('Mathematics 1', 'practice', 7,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 7 practice assignment solution.pdf'), 'Week 7 Practice Assignment'),
    ('Mathematics 1', 'practice', 8,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 8 Practice Assignment Solution.pdf'), 'Week 8 Practice Assignment'),
    ('Mathematics 1', 'practice', 9,  os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 9 Practice Assignment Solution.pdf'), 'Week 9 Practice Assignment'),
    ('Mathematics 1', 'practice', 10, os.path.join(DOWNLOADS, 'maths I/PA solutions/Week 10 Practice Assignment Solution.pdf'), 'Week 10 Practice Assignment'),
    ('Mathematics 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'maths I/drive-download-20261009T104734Z-1-001/IIT M QUALIFIER AN EXAM QDQ1.pdf'), 'DS Qualifier Exam QDQ1'),
    ('Mathematics 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'maths I/drive-download-20261009T104734Z-1-001/IIT M QUALIFIER AN EXAM QDQ2.pdf'), 'DS Qualifier Exam QDQ2'),

    # ── Statistics 1 ─────────────────────────────────────────────────────
    ('Statistics 1', 'practice_graded', 1,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_1_Graded_Solution.pdf'), 'Week 1 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 2,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_2_Graded_Solution.pdf'), 'Week 2 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 3,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_3_Graded_Solution.pdf'), 'Week 3 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 4,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_4_Graded_Solution.pdf'), 'Week 4 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 5,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_5_GA_Solution.pdf'), 'Week 5 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 5,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_5_EMQ_Solution.pdf'), 'Week 5 EMQ Graded Assignment'),
    ('Statistics 1', 'practice_graded', 6,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_6_Graded_Solution.pdf'), 'Week 6 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 6,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_6_Graded_Part_2(EMQ)_Solution.pdf'), 'Week 6 EMQ Graded Assignment'),
    ('Statistics 1', 'practice_graded', 7,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_7_Graded_Solution.pdf'), 'Week 7 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 8,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_8_Graded_ Solution.pdf'), 'Week 8 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 9,  os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_9_Graded_Solution.pdf'), 'Week 9 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 10, os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_10_Graded_Solution.pdf'), 'Week 10 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 11, os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_11_Graded_Solution (1).pdf'), 'Week 11 Graded Assignment'),
    ('Statistics 1', 'practice_graded', 12, os.path.join(DOWNLOADS, 'stats1/Graded assignment solutions/Week_12_Graded_Solution.pdf'), 'Week 12 Graded Assignment'),
    ('Statistics 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'stats1/DS_Qualifier/IIT M QUALIFIER AN EXAM QDQ1.pdf'), 'DS Qualifier Exam QDQ1'),
    ('Statistics 1', 'mock_test',  None, os.path.join(DOWNLOADS, 'stats1/DS_Qualifier/IIT M QUALIFIER AN EXAM QDQ2.pdf'), 'DS Qualifier Exam QDQ2'),
]

# ── Text extraction ──────────────────────────────────────────────────────────

def extract_pdf_text(path):
    reader = pypdf.PdfReader(path)
    return '\n'.join(page.extract_text() or '' for page in reader.pages)

# ── Question parsing helpers ─────────────────────────────────────────────────

def clean(s):
    return re.sub(r'\s+', ' ', s).strip()

def text_block(val):
    return [{"kind": "text", "value": clean(val)}]

def safe_filename(s):
    return re.sub(r'[^\w\- ]', '_', s)[:80].strip()

# ── Option letter → 0-based index ────────────────────────────────────────────

LETTER_MAP = {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4,
              '1': 0, '2': 1, '3': 2, '4': 3, '5': 4}

def resolve_answer_index(raw, num_options):
    """Return 0-based index or None if can't resolve."""
    raw = raw.strip().lower().rstrip('.')
    if raw in LETTER_MAP:
        idx = LETTER_MAP[raw]
        return idx if idx < num_options else None
    # numeric
    if re.match(r'^\d+$', raw):
        idx = int(raw) - 1
        return idx if 0 <= idx < num_options else None
    return None

# ── IIT-Madras style parser (covers CT, Stats, Eng, Maths solution PDFs) ─────

def parse_iit_style(text, subject, week, quiz_title):
    """
    Parse Q&A solution PDFs from IIT Madras.
    Handles:
    - MCQ (options a/b/c/d, answer letter)
    - Numerical (NAT) questions (answer is a number)
    - True/False questions
    - Multi-select (MSQ)
    """
    questions = []
    lines = text.splitlines()
    i = 0

    # Patterns
    # Question header: "Question 4 [3 Marks]" or "4. some text" or "Question 4 [3 marks]"
    q_hdr_rich  = re.compile(r'^Question\s+(\d+)\s*\[(\d+(?:\.\d+)?)\s*[Mm]arks?\]', re.I)
    q_hdr_plain = re.compile(r'^(\d+)\.\s+(.+)')  # "1. Mark the appropriate..."
    opt_pat     = re.compile(r'^\(?([a-dA-D])\)?[\.\)]\s*(.*)')
    ans_pat     = re.compile(r'^Answer[:\s]+(.+)', re.I)
    nat_num_pat = re.compile(r'^-?\d+(\.\d+)?$')
    tf_pat      = re.compile(r'^(true|false)$', re.I)

    # Shared statement blocks (e.g., "Question (1 to 3)\nStatement\n<para>")
    shared_stmt = ''
    shared_end  = 0  # last question number of shared block

    def flush_shared():
        nonlocal shared_stmt, shared_end
        shared_stmt = ''
        shared_end = 0

    # Collect logical question chunks
    # First pass: split into question blocks
    raw_blocks = []
    j = 0
    while j < len(lines):
        line = lines[j].strip()

        # Detect shared statement "Question (X to Y)" or "Question X to Y"
        m_range = re.match(r'Question\s*\(?\s*(\d+)\s+to\s+(\d+)\s*\)?', line, re.I)
        if m_range:
            start_q = int(m_range.group(1))
            end_q   = int(m_range.group(2))
            # Collect statement lines until next "Question N ["
            j += 1
            stmt_lines = []
            while j < len(lines):
                l2 = lines[j].strip()
                if q_hdr_rich.match(l2) or re.match(r'^Question\s*\(?\s*\d+\s+to\s+\d+', l2, re.I):
                    break
                stmt_lines.append(l2)
                j += 1
            shared_stmt = ' '.join(l for l in stmt_lines if l and l.lower() not in ('statement', 'answer', 'solution', ''))
            shared_end = end_q
            continue

        # Rich header: "Question 4 [3 Marks]"
        m = q_hdr_rich.match(line)
        if m:
            q_num   = int(m.group(1))
            marks   = float(m.group(2))
            # Collect all lines of this question block
            j += 1
            block_lines = []
            while j < len(lines):
                l2 = lines[j].strip()
                # Stop at next question header
                if q_hdr_rich.match(l2) or re.match(r'^Question\s*\(?\s*\d+\s+to\s+\d+', l2, re.I):
                    break
                block_lines.append(l2)
                j += 1
            stmt_prefix = shared_stmt if q_num <= shared_end else ''
            raw_blocks.append({'num': q_num, 'marks': marks, 'lines': block_lines, 'prefix': stmt_prefix})
            if q_num > shared_end:
                flush_shared()
            continue

        # Plain header: "1. Mark the appropriate response."
        m = q_hdr_plain.match(line)
        if m:
            q_num = int(m.group(1))
            first_line = m.group(2).strip()
            j += 1
            block_lines = [first_line]
            while j < len(lines):
                l2 = lines[j].strip()
                if q_hdr_plain.match(l2) and int(q_hdr_plain.match(l2).group(1)) > q_num:
                    break
                block_lines.append(l2)
                j += 1
            raw_blocks.append({'num': q_num, 'marks': 1.0, 'lines': block_lines, 'prefix': ''})
            continue

        j += 1

    # Second pass: parse each block into a question object
    for block in raw_blocks:
        lines_b = block['lines']
        marks   = block['marks']
        prefix  = block.get('prefix', '')

        # Separate into: statement, options, answer, solution/explanation
        stmt_lines = []
        options    = []
        answer_raw = None
        explanation_lines = []
        section    = 'statement'

        for ln in lines_b:
            if not ln or ln.lower() in ('statement', 'options', ''):
                continue

            if re.match(r'^Answer', ln, re.I):
                section = 'answer'
                remainder = re.sub(r'^Answer[:\s]*', '', ln, flags=re.I).strip()
                if remainder:
                    answer_raw = remainder
                continue

            if ln.lower().startswith('solution'):
                section = 'explanation'
                after = ln[len('solution'):].lstrip(':').strip()
                if after:
                    explanation_lines.append(after)
                continue

            if section == 'statement':
                m_opt = opt_pat.match(ln)
                if m_opt:
                    # Switch to options section
                    section = 'options'
                    options.append({'letter': m_opt.group(1).lower(), 'text': clean(m_opt.group(2))})
                else:
                    stmt_lines.append(ln)

            elif section == 'options':
                m_opt = opt_pat.match(ln)
                if m_opt:
                    options.append({'letter': m_opt.group(1).lower(), 'text': clean(m_opt.group(2))})
                elif re.match(r'^Answer', ln, re.I):
                    section = 'answer'
                    remainder = re.sub(r'^Answer[:\s]*', '', ln, flags=re.I).strip()
                    if remainder:
                        answer_raw = remainder
                else:
                    # continuation of last option text
                    if options:
                        options[-1]['text'] = (options[-1]['text'] + ' ' + ln).strip()

            elif section == 'answer':
                if not answer_raw:
                    answer_raw = ln
                else:
                    # continuation
                    answer_raw = (answer_raw + ' ' + ln).strip()

            elif section == 'explanation':
                explanation_lines.append(ln)

        # Build the stem
        full_stmt = ' '.join(filter(None, [prefix, ' '.join(stmt_lines)])).strip()
        if not full_stmt:
            continue  # skip empty
        explanation = clean(' '.join(explanation_lines)) if explanation_lines else None

        # Determine type
        if not answer_raw:
            continue

        answer_raw_clean = clean(answer_raw)

        # True/False?
        if tf_pat.match(answer_raw_clean):
            q = {
                "type": "true_false",
                "prompt": text_block(full_stmt),
                "correct_answer": answer_raw_clean.lower() == 'true',
                "marks": max(1, int(marks)),
                "difficulty": "medium",
            }
            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)
            continue

        # NAT / Numerical?
        if nat_num_pat.match(answer_raw_clean) and not options:
            try:
                num = float(answer_raw_clean)
                q = {
                    "type": "numerical",
                    "prompt": text_block(full_stmt),
                    "numerical_answer": num,
                    "numerical_tolerance": 0,
                    "marks": max(1, int(marks)),
                    "difficulty": "medium",
                }
                if explanation:
                    q["explanation"] = text_block(explanation)
                questions.append(q)
                continue
            except ValueError:
                pass

        # MCQ / MSQ (has options)?
        if options:
            opt_blocks = [[{"kind": "text", "value": o['text']}] for o in options]

            # Multi-select: "b and d", "a, c", etc.
            multi_pat = re.compile(r'([a-d])(?:\s+and\s+|\s*,\s*)([a-d](?:(?:\s+and\s+|\s*,\s*)[a-d])*)', re.I)
            multi_m = multi_pat.match(answer_raw_clean)

            if multi_m:
                # extract all letters
                letters = re.findall(r'[a-d]', answer_raw_clean, re.I)
                indices = []
                for l in letters:
                    idx = resolve_answer_index(l.lower(), len(options))
                    if idx is not None and idx not in indices:
                        indices.append(idx)
                if indices:
                    q = {
                        "type": "mcq_multi",
                        "prompt": text_block(full_stmt),
                        "options": opt_blocks,
                        "correct_answers": indices,
                        "marks": max(1, int(marks)),
                        "difficulty": "medium",
                    }
                    if explanation:
                        q["explanation"] = text_block(explanation)
                    questions.append(q)
                    continue

            # Single MCQ
            # Answer could be "(c)" or "c" or "c)" or "option c" etc.
            letter_match = re.search(r'\b([a-d])\b', answer_raw_clean, re.I)
            if letter_match:
                idx = resolve_answer_index(letter_match.group(1).lower(), len(options))
                if idx is not None:
                    q = {
                        "type": "mcq_single",
                        "prompt": text_block(full_stmt),
                        "options": opt_blocks,
                        "correct_answer": idx,
                        "marks": max(1, int(marks)),
                        "difficulty": "medium",
                    }
                    if explanation:
                        q["explanation"] = text_block(explanation)
                    questions.append(q)
                    continue

            # Fallback: short_answer
            q = {
                "type": "short_answer",
                "prompt": text_block(full_stmt),
                "acceptable_answers": [answer_raw_clean],
                "marks": max(1, int(marks)),
                "difficulty": "medium",
            }
            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)
            continue

        # No options — check if it's a letter-only answer (MCQ without visible options in this block)
        letter_only = re.match(r'^[a-d]$', answer_raw_clean, re.I)
        if letter_only:
            # MCQ but options weren't on the same page as statement; still produce a placeholder
            letter = answer_raw_clean.lower()
            q = {
                "type": "short_answer",
                "prompt": text_block(full_stmt),
                "acceptable_answers": [letter, f'({letter})'],
                "marks": max(1, int(marks)),
                "difficulty": "medium",
            }
            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)
            continue

        # Fallback: short answer
        if answer_raw_clean:
            q = {
                "type": "short_answer",
                "prompt": text_block(full_stmt),
                "acceptable_answers": [answer_raw_clean],
                "marks": max(1, int(marks)),
                "difficulty": "medium",
            }
            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)

    return questions

# ── Qualifier exam parser (IIT M format) ─────────────────────────────────────

def parse_qualifier_exam(text, subject, quiz_title):
    """
    Parses IIT M Qualifier exam PDFs.
    - MCQ/MSQ with image-only options → skipped (can't extract images)
    - MCQ/MSQ with text options → fully parsed
    - SA/NAT (Short Answer / Numerical) → parsed with 'Possible Answers'
    - Comprehension groups → statement extracted and passed to sub-questions
    """
    questions = []

    blocks = re.split(r'(?=Question Number\s*:\s*\d+)', text)

    q_header_re = re.compile(
        r'Question Number\s*:\s*(\d+)\s+'
        r'Question Id\s*:\s*\S+\s+'
        r'Question Type\s*:\s*(MCQ|MSQ|SA|NAT)',
        re.I
    )
    marks_re     = re.compile(r'Correct Marks\s*:\s*(\d+(?:\.\d+)?)', re.I)
    opt_id_re    = re.compile(r'^(\d{10,})\.\s*(.*)')
    possible_re  = re.compile(r'Possible Answers?\s*:', re.I)
    skip_re      = re.compile(
        r'^(Response Type|Evaluation Required|Show Word Count|'
        r'Answers Type|Text Areas|Sub-Section|Section|Group|Question Label|'
        r'Question Shuffling|Question Numbers|Max\. Selectable)',
        re.I
    )

    comprehension_stmt = ''
    comp_range = (0, 0)

    for raw_block in blocks:
        lines = [l.strip() for l in raw_block.splitlines()]
        lines = [l for l in lines if l]

        m = q_header_re.search(raw_block)
        if not m:
            if 'COMPREHENSION' in raw_block.upper():
                range_m = re.search(r'Question Numbers\s*:\s*\((\d+)\s+to\s+(\d+)\)', raw_block, re.I)
                if range_m:
                    comp_range = (int(range_m.group(1)), int(range_m.group(2)))
                comp_lines = []
                in_stmt = False
                for ln in lines:
                    if skip_re.match(ln):
                        continue
                    if re.match(r'COMPREHENSION', ln, re.I):
                        in_stmt = True
                        continue
                    if in_stmt and ln:
                        comp_lines.append(ln)
                comprehension_stmt = clean(' '.join(comp_lines))
            continue

        q_num  = int(m.group(1))
        q_type = m.group(2).upper()

        marks_m = marks_re.search(raw_block)
        marks = float(marks_m.group(1)) if marks_m else 1.0
        if marks == 0:
            continue

        comp_prefix = ''
        if comp_range[0] <= q_num <= comp_range[1] and comprehension_stmt:
            comp_prefix = comprehension_stmt

        header_end = raw_block.find(m.group(0)) + len(m.group(0))
        body = raw_block[header_end:]
        body_lines = [l.strip() for l in body.splitlines() if l.strip()]

        stmt_lines   = []
        options      = []
        answer_lines = []
        in_possible  = False
        in_options   = False

        for ln in body_lines:
            if marks_re.match(ln):
                continue
            if skip_re.match(ln):
                in_possible = False
                continue
            if re.match(r'^Options\s*:', ln, re.I):
                in_options = True
                continue
            opt_m = opt_id_re.match(ln)
            if opt_m:
                in_options = True
                opt_text = opt_m.group(2).strip()
                if opt_text:
                    options.append(opt_text)
                continue
            if possible_re.match(ln):
                in_possible = True
                remainder = re.sub(r'^Possible Answers?\s*:', '', ln, flags=re.I).strip()
                if remainder:
                    answer_lines.append(remainder)
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
            questions.append(q)

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
            questions.append(q)
        # else: image-only MCQ → skip

    return questions
    """
    Parses the dense IIT M Qualifier exam PDF format.
    Structure: Question Number, Question Type, Marks, Options, then a bold mark for correct answer.
    The correct answer appears inline as 'Correct Option(s): ...' or via green-colored text markers.
    """
    questions = []
    lines = [l.strip() for l in text.splitlines() if l.strip()]

    q_header = re.compile(r'Question Number\s*:\s*(\d+)\s+Question Id\s*:\s*\S+\s+Question Type\s*:\s*(MCQ|MSQ|SA|NAT)', re.I)
    marks_pat = re.compile(r'Correct Marks\s*:\s*(\d+(?:\.\d+)?)', re.I)
    opt_id_pat = re.compile(r'^\d{10,}\.')  # "6406533348194. text"
    correct_pat = re.compile(r'Correct Option\(?s?\)?[:\s]+(.+)', re.I)
    nat_ans_pat = re.compile(r'(?:Given Answer|Correct Answer)[:\s]+(.+)', re.I)

    i = 0
    while i < len(lines):
        m = q_header.match(lines[i])
        if not m:
            i += 1
            continue

        q_num  = int(m.group(1))
        q_type = m.group(2).upper()
        i += 1

        marks = 1.0
        stmt_lines = []
        options = []
        answer_raw = None
        explanation_lines = []
        section = 'pre'

        while i < len(lines):
            ln = lines[i]
            if q_header.match(ln):
                break

            mm = marks_pat.match(ln)
            if mm:
                marks = float(mm.group(1))
                i += 1
                continue

            if ln.lower().startswith('question label'):
                i += 1
                continue

            if opt_id_pat.match(ln):
                # Line like "6406533348194.  some option text"
                text_part = re.sub(r'^\d+\.\s*', '', ln).strip()
                section = 'options'
                if text_part:
                    options.append(text_part)
                i += 1
                continue

            mc = correct_pat.match(ln)
            if mc:
                answer_raw = mc.group(1).strip()
                i += 1
                continue

            mn = nat_ans_pat.match(ln)
            if mn:
                answer_raw = mn.group(1).strip()
                i += 1
                continue

            if ln.lower().startswith('solution'):
                section = 'explanation'
                i += 1
                continue

            if section == 'pre' or section == 'statement':
                if ln not in ('', 'Options :') and not marks_pat.match(ln):
                    section = 'statement'
                    stmt_lines.append(ln)
            elif section == 'options':
                if options and not opt_id_pat.match(ln) and ln not in ('', 'Options :'):
                    # continuation of last option
                    options[-1] = (options[-1] + ' ' + ln).strip()
            elif section == 'explanation':
                explanation_lines.append(ln)

            i += 1

        # Skip intro/instructions questions (marks=0)
        if marks == 0:
            continue

        full_stmt = clean(' '.join(stmt_lines))
        if not full_stmt:
            continue

        explanation = clean(' '.join(explanation_lines)) if explanation_lines else None

        if q_type in ('MCQ', 'MSQ') and options:
            opt_blocks = [[{"kind": "text", "value": o}] for o in options if o]

            if answer_raw:
                # Parse answer: could be option text, or index
                letters = re.findall(r'\b([1-4]|[a-d])\b', answer_raw, re.I)
                indices = []
                for l in letters:
                    idx = resolve_answer_index(l.lower(), len(opt_blocks))
                    if idx is not None and idx not in indices:
                        indices.append(idx)

                if q_type == 'MSQ' and len(indices) > 1:
                    q = {"type": "mcq_multi", "prompt": text_block(full_stmt),
                         "options": opt_blocks, "correct_answers": indices,
                         "marks": max(1, int(marks)), "difficulty": "medium"}
                elif indices:
                    q = {"type": "mcq_single", "prompt": text_block(full_stmt),
                         "options": opt_blocks, "correct_answer": indices[0],
                         "marks": max(1, int(marks)), "difficulty": "medium"}
                else:
                    q = {"type": "short_answer", "prompt": text_block(full_stmt),
                         "acceptable_answers": [answer_raw],
                         "marks": max(1, int(marks)), "difficulty": "medium"}
            else:
                q = {"type": "short_answer", "prompt": text_block(full_stmt),
                     "acceptable_answers": ["See explanation"],
                     "marks": max(1, int(marks)), "difficulty": "medium"}

            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)

        elif q_type in ('NAT', 'SA') and answer_raw:
            try:
                num = float(answer_raw.strip())
                q = {"type": "numerical", "prompt": text_block(full_stmt),
                     "numerical_answer": num, "numerical_tolerance": 0.01,
                     "marks": max(1, int(marks)), "difficulty": "medium"}
            except ValueError:
                q = {"type": "short_answer", "prompt": text_block(full_stmt),
                     "acceptable_answers": [answer_raw.strip()],
                     "marks": max(1, int(marks)), "difficulty": "medium"}
            if explanation:
                q["explanation"] = text_block(explanation)
            questions.append(q)

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

# ── Main ──────────────────────────────────────────────────────────────────────

def section_label(section):
    return {'practice': 'PA', 'practice_graded': 'GA', 'mock_test': 'Mock',
            'quiz1': 'Q1', 'quiz2': 'Q2', 'endterm': 'ET'}.get(section, section)

def main():
    total_ok = 0
    total_fail = 0
    total_qs = 0

    for subject, section, week, pdf_path, quiz_title in PDFS:
        if not os.path.exists(pdf_path):
            print(f'  [SKIP] File not found: {pdf_path}')
            continue

        try:
            text = extract_pdf_text(pdf_path)
        except Exception as e:
            print(f'  [ERROR] PDF read failed: {pdf_path}: {e}')
            total_fail += 1
            continue

        try:
            if 'qualifier' in pdf_path.lower() or 'qdq' in pdf_path.lower() or 'qdb' in pdf_path.lower() or 'qdd' in pdf_path.lower() or 'qdf' in pdf_path.lower():
                questions = parse_qualifier_exam(text, subject, quiz_title)
            else:
                questions = parse_iit_style(text, subject, week, quiz_title)
        except Exception as e:
            print(f'  [ERROR] Parse failed: {pdf_path}: {e}')
            total_fail += 1
            continue

        if not questions:
            print(f'  [WARN] 0 questions parsed: {pdf_path}')
            total_fail += 1
            continue

        payload = build_json(subject, section, week, quiz_title, questions)

        # Output filename
        subj_dir = os.path.join(OUT_ROOT, subject)
        os.makedirs(subj_dir, exist_ok=True)
        week_label = f'W{week:02d}_' if week else ''
        sec_label  = section_label(section)
        fname = f'{week_label}{sec_label}_{safe_filename(quiz_title)}.json'
        out_path = os.path.join(subj_dir, fname)

        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        print(f'  [OK] {subject}/{fname}  ({len(questions)} questions)')
        total_ok += 1
        total_qs += len(questions)

    print()
    print(f'Done: {total_ok} files created, {total_fail} skipped/failed, {total_qs} total questions.')
    print(f'Output directory: {os.path.abspath(OUT_ROOT)}')

if __name__ == '__main__':
    main()
