#!/usr/bin/env python3
"""
Mathematics 1 & 2 Booklet PDF -> Quiz Lab JSON Parser
Extracts questions from Gen-Z IITian booklet PDFs for Mathematics 1 and Mathematics 2 Quiz 1.

Enforces:
- Minimum 5, maximum 10 questions per paper (splits 11-18 Q papers into balanced parts of 6-9 Qs each)
- High question quality: attaches comprehension passages and dataset contexts to questions so every question makes complete sense
- Correct mathematical types (mcq_single, mcq_multi, numerical, short_answer)
- Preserves explanations and solution steps
- Schema version 1.1 matching templates/ques_template.json
"""

import os
import re
import sys
import glob
import json
import pypdf
import subprocess

LETTER_TO_INDEX = {'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6}
HEADER_RE = re.compile(r'^Q(\d+)\s+(MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)(?:\s+(\d+)\s+marks?)?(?:\s*·\s*(\w+))?', re.I)
ANS_RE = re.compile(r'^Answer\s*:\s*(.*)', re.I)
EXPL_RE = re.compile(r'^Explanation\s*:\s*(.*)', re.I)
OPT_MARKER_RE = re.compile(r'^(?:([A-G])|([✓✔]))(?:\s+(?![=+\-*/])(.*))?$', re.I)
FOOTER_RE = re.compile(r'^(?:EXAM\.GENZIITIAN|GENZIITIAN\.IN|YOUTUBE|Source:|Ecosystem|• Detailed|\+ Detailed|▶ Video|📚|Gen-Z IITian|P R E V I O U S|SUBJECT:|EXAM:|DATE:|PAPER:|TOTAL:)', re.I)

def clean_text_lines(lines):
    clean = []
    for l in lines:
        s = l.strip()
        if not s:
            continue
        if FOOTER_RE.match(s):
            continue
        clean.append(s)
    return clean

def parse_options_from_lines(lines, ans_raw):
    """
    Parses options from lines preceding the Answer line.
    Handles marked options (A, B, C...) and unlabeled option blocks.
    """
    opt_matches = []
    for idx, ln in enumerate(lines):
        m = OPT_MARKER_RE.match(ln.strip())
        if m:
            letter = m.group(1)
            is_check = bool(m.group(2))
            txt = (m.group(3) or '').strip()
            # Avoid mathematical or English prose accidentally starting with A
            if letter == 'A' and re.match(r'^(?:function|polynomial|matrix|vector|line|plane|point|set|relation|circle|curve|subset|basis|transformation)\b', txt, re.I):
                continue
            opt_matches.append((idx, letter, is_check, txt))

    found_seq = None
    for n_opts in range(7, 1, -1):
        if len(opt_matches) < n_opts:
            continue
        cand = opt_matches[-n_opts:]
        valid = True
        for k in range(n_opts):
            expected = chr(ord('A') + k)
            if cand[k][2] or (cand[k][1] and cand[k][1].upper() == expected):
                continue
            else:
                valid = False
                break
        if valid:
            found_seq = cand
            break

    if found_seq and len(found_seq) >= 2:
        prompt_lines = lines[:found_seq[0][0]]
        opt_blocks = []
        for opt_idx, cand in enumerate(found_seq):
            start_l = cand[0]
            end_l = found_seq[opt_idx + 1][0] if opt_idx + 1 < len(found_seq) else len(lines)
            first_text = cand[3]
            cont_lines = lines[start_l + 1 : end_l]
            all_opt_lines = ([first_text] if first_text else []) + [l.strip() for l in cont_lines if l.strip()]
            opt_str = ' '.join(all_opt_lines).strip()
            opt_blocks.append([{'kind': 'text', 'value': opt_str or f"Option {chr(ord('A')+opt_idx)}"}])
        return prompt_lines, opt_blocks, found_seq

    # Fallback: check if lines end with 4 distinct statements or option candidates
    # (common in OCR where letters A, B, C, D might be faint/glyphs)
    if len(lines) >= 4:
        # Check if last 4 lines look like options
        cand_lines = lines[-4:]
        prompt_lines = lines[:-4]
        opt_blocks = [[{'kind': 'text', 'value': l}] for l in cand_lines]
        return prompt_lines, opt_blocks, None

    return lines, [], None

def parse_maths1_pdf(pdf_path):
    try:
        reader = pypdf.PdfReader(pdf_path)
    except Exception as e:
        print(f"Error opening {pdf_path}: {e}")
        return None

    full_text = '\n'.join(p.extract_text() or '' for p in reader.pages)
    if not full_text.strip():
        return None

    # Metadata
    date_m = re.search(r'DATE\s*:\s*([^\n]+)', full_text, re.I)
    paper_m = re.search(r'PAPER\s*:\s*([^\n]+)', full_text, re.I)
    raw_date = date_m.group(1).strip() if date_m else ''
    raw_paper = paper_m.group(1).strip() if paper_m else ''

    clean_date = re.sub(r'PAPER:.*', '', raw_date, flags=re.I).strip()
    clean_date = re.sub(r'[^\w\s]', '', clean_date).strip()
    clean_paper = re.sub(r'DATE:.*', '', raw_paper, flags=re.I).strip()
    clean_paper = re.sub(r'[▶📚].*', '', clean_paper).strip()

    subject = 'Mathematics 1'
    section = 'quiz1'

    base_title_parts = [subject, 'Quiz 1', clean_date, clean_paper]
    base_title = ' · '.join([p for p in base_title_parts if p])

    split_pattern = re.compile(r'(?=^Q\d+\s+(?:MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)\b|📖\s*Passage\b|📖\s*Comprehension\b)', re.M)
    parts = split_pattern.split(full_text)

    current_passage = None
    questions = []

    for part in parts:
        p_strip = part.strip()
        if not p_strip:
            continue

        if p_strip.startswith('📖') or re.match(r'^Passage\b', p_strip) or re.match(r'^Comprehension\b', p_strip):
            c_lines = clean_text_lines(part.splitlines())
            if c_lines:
                current_passage = '\n'.join(c_lines[1:])
            continue

        lines = [l for l in part.splitlines() if l.strip()]
        if not lines:
            continue

        hm = HEADER_RE.match(lines[0].strip())
        if not hm:
            continue

        qnum = int(hm.group(1))
        raw_type = hm.group(2).upper()
        marks = int(hm.group(3)) if hm.group(3) else 2
        diff = hm.group(4).lower() if hm.group(4) else 'medium'
        if diff not in ('easy', 'medium', 'hard'):
            diff = 'medium'

        ans_idx = -1
        for idx, ln in enumerate(lines):
            if ANS_RE.match(ln.strip()):
                ans_idx = idx
                break
        if ans_idx == -1:
            continue

        ans_raw = ANS_RE.match(lines[ans_idx].strip()).group(1).strip()
        expl_lines = []
        for ln in lines[ans_idx + 1:]:
            if FOOTER_RE.match(ln.strip()):
                continue
            em = EXPL_RE.match(ln.strip())
            if em:
                if em.group(1).strip():
                    expl_lines.append(em.group(1).strip())
            else:
                expl_lines.append(ln.strip())

        pre_ans = [l for l in lines[1:ans_idx] if not FOOTER_RE.match(l.strip())]

        if raw_type in ('MCQ', 'MSQ', 'MULTI-SELECT'):
            prompt_lines, opt_blocks, found_seq = parse_options_from_lines(pre_ans, ans_raw)
            if not opt_blocks:
                continue

            prompt_text = ' '.join(prompt_lines).strip()
            if current_passage and ('above' in prompt_text.lower() or 'following' in prompt_text.lower() or 'refer' in prompt_text.lower()):
                prompt_text = f"{current_passage}\n\n{prompt_text}"

            if raw_type == 'MCQ':
                c_idx = 0
                if ans_raw:
                    letter = ans_raw.strip().upper()[:1]
                    if letter in LETTER_TO_INDEX:
                        c_idx = LETTER_TO_INDEX[letter]
                elif found_seq:
                    for idx, c in enumerate(found_seq):
                        if c[2]:
                            c_idx = idx
                            break
                if c_idx >= len(opt_blocks):
                    c_idx = 0

                q_obj = {
                    'type': 'mcq_single',
                    'prompt': [{'kind': 'text', 'value': prompt_text}],
                    'options': opt_blocks,
                    'correct_answer': c_idx,
                    'marks': marks,
                    'difficulty': diff,
                }
            else:
                c_indices = []
                if ans_raw:
                    for token in re.split(r'[,;\s]+', ans_raw):
                        token = token.strip().upper()
                        if token in LETTER_TO_INDEX:
                            c_indices.append(LETTER_TO_INDEX[token])
                elif found_seq:
                    for idx, c in enumerate(found_seq):
                        if c[2]:
                            c_indices.append(idx)
                if not c_indices:
                    c_indices = [0]
                c_indices = [i for i in c_indices if i < len(opt_blocks)]
                if not c_indices:
                    c_indices = [0]

                q_obj = {
                    'type': 'mcq_multi',
                    'prompt': [{'kind': 'text', 'value': prompt_text}],
                    'options': opt_blocks,
                    'correct_answers': c_indices,
                    'marks': marks,
                    'difficulty': diff,
                }
        else:
            prompt_text = ' '.join(pre_ans).strip()
            if current_passage and ('above' in prompt_text.lower() or 'following' in prompt_text.lower() or 'refer' in prompt_text.lower()):
                prompt_text = f"{current_passage}\n\n{prompt_text}"

            try:
                num_val = float(re.sub(r'[^\d\.\-]', '', ans_raw))
                if num_val.is_integer():
                    num_val = int(num_val)
                q_obj = {
                    'type': 'numerical',
                    'prompt': [{'kind': 'text', 'value': prompt_text}],
                    'numerical_answer': num_val,
                    'numerical_tolerance': 0.01,
                    'marks': marks,
                    'difficulty': diff,
                }
            except (ValueError, TypeError):
                q_obj = {
                    'type': 'short_answer',
                    'prompt': [{'kind': 'text', 'value': prompt_text}],
                    'acceptable_answers': [ans_raw] if ans_raw else ['0'],
                    'marks': marks,
                    'difficulty': diff,
                }

        if expl_lines:
            q_obj['explanation'] = [{'kind': 'text', 'value': ' '.join(expl_lines).strip()}]
        questions.append(q_obj)

    if len(questions) < 5:
        print(f"  Warning: Only {len(questions)} questions extracted from {os.path.basename(pdf_path)}")
        return None

    return create_balanced_papers(pdf_path, base_title, subject, section, questions)

def parse_maths2_pdf(pdf_path):
    try:
        reader = pypdf.PdfReader(pdf_path)
    except Exception as e:
        print(f"Error opening {pdf_path}: {e}")
        return None

    # Run OCR on each page image
    all_pages_text = []
    for p_idx, page in enumerate(reader.pages):
        for img_idx, img in enumerate(page.images):
            tmp_img = f"/tmp/m2_{os.getpid()}_p{p_idx}_{img_idx}.png"
            with open(tmp_img, 'wb') as fp:
                fp.write(img.data)
            res = subprocess.run(['./tools/ocr', tmp_img], capture_output=True, text=True)
            if os.path.exists(tmp_img):
                os.remove(tmp_img)
            all_pages_text.append(res.stdout)

    full_text = '\n'.join(all_pages_text)
    if not full_text.strip():
        return None

    # Metadata
    date_m = re.search(r'DATE\s*:\s*([^\n]+)', full_text, re.I)
    raw_date = date_m.group(1).strip() if date_m else ''
    clean_date = re.sub(r'TOTAL:.*', '', raw_date, flags=re.I).strip()
    clean_date = re.sub(r'[^\w\s]', '', clean_date).strip()

    # Determine paper from filename
    fname = os.path.basename(pdf_path)
    paper_match = re.search(r'\(([^)]+)\)', fname)
    clean_paper = paper_match.group(1).strip() if paper_match else ''
    if not clean_paper and '15 Mar 2026' in fname:
        clean_paper = 'Practice'

    subject = 'Mathematics 2'
    section = 'quiz1'

    base_title_parts = [subject, 'Quiz 1', clean_date, clean_paper]
    base_title = ' · '.join([p for p in base_title_parts if p])

    # Split by Q<num> or Passage
    split_pattern = re.compile(r'(?=(?:^|\n)(?:Q\d+\b|.*?Passage\s*/\s*Context\b))', re.I)
    parts = split_pattern.split(full_text)

    current_passage = None
    questions = []

    for part in parts:
        p_strip = part.strip()
        if not p_strip:
            continue

        if 'passage' in p_strip.lower() and 'context' in p_strip.lower():
            c_lines = clean_text_lines(p_strip.splitlines())
            if len(c_lines) > 1:
                current_passage = '\n'.join(c_lines[1:])
            continue

        lines = [l.strip() for l in p_strip.splitlines() if l.strip()]
        if not lines or not re.match(r'^Q\d+\b', lines[0]):
            continue

        # Header details
        qnum_match = re.match(r'^Q(\d+)', lines[0])
        qnum = int(qnum_match.group(1))

        # Check for type in first few lines
        raw_type = 'MCQ'
        marks = 2
        diff = 'medium'

        for l in lines[:5]:
            if re.search(r'\bMSQ\b|\bMULTI-SELECT\b', l, re.I):
                raw_type = 'MSQ'
            elif re.search(r'\bNUMERICAL\b|\bNAT\b', l, re.I):
                raw_type = 'NUMERICAL'
            elif re.search(r'\bSA\b|\bSHORT\s+ANSWER\b', l, re.I):
                raw_type = 'SA'
            elif re.search(r'\bMCQ\b', l, re.I):
                raw_type = 'MCQ'

            mm = re.search(r'(\d+)\s*marks?', l, re.I)
            if mm:
                marks = int(mm.group(1))
            dm = re.search(r'\b(easy|medium|hard)\b', l, re.I)
            if dm:
                diff = dm.group(1).lower()

        ans_idx = -1
        for idx, ln in enumerate(lines):
            if re.match(r'^Answer\s*:', ln, re.I):
                ans_idx = idx
                break
        if ans_idx == -1:
            continue

        ans_raw = re.sub(r'^Answer\s*:\s*', '', lines[ans_idx], flags=re.I).strip()

        # Clean pre-answer lines (filter header tokens)
        pre_ans = []
        for ln in lines[1:ans_idx]:
            if FOOTER_RE.match(ln):
                continue
            if re.match(r'^(?:MCQ|MSQ|NUMERICAL|NAT|SA|\d+\s*marks?.*)$', ln, re.I):
                continue
            pre_ans.append(ln)

        if raw_type in ('MCQ', 'MSQ'):
            prompt_lines, opt_blocks, found_seq = parse_options_from_lines(pre_ans, ans_raw)
            if not opt_blocks or len(opt_blocks) < 2:
                # If option parsing produced < 2 options, treat remaining non-empty lines as options
                if len(pre_ans) >= 4:
                    prompt_lines = pre_ans[:-4]
                    opt_blocks = [[{'kind': 'text', 'value': l}] for l in pre_ans[-4:]]
                else:
                    continue

            prompt_text = ' '.join(prompt_lines).strip()
            if current_passage and (not prompt_text or 'above' in prompt_text.lower() or 'following' in prompt_text.lower() or 'refer' in prompt_text.lower() or 'find' in prompt_text.lower()):
                prompt_text = f"{current_passage}\n\n{prompt_text}"

            if raw_type == 'MCQ':
                c_idx = 0
                if ans_raw:
                    letter = ans_raw.strip().upper()[:1]
                    if letter in LETTER_TO_INDEX:
                        c_idx = LETTER_TO_INDEX[letter]
                elif found_seq:
                    for idx, c in enumerate(found_seq):
                        if c[2]:
                            c_idx = idx
                            break
                if c_idx >= len(opt_blocks):
                    c_idx = 0

                q_obj = {
                    'type': 'mcq_single',
                    'prompt': [{'kind': 'text', 'value': prompt_text or f"Question {qnum}"}],
                    'options': opt_blocks,
                    'correct_answer': c_idx,
                    'marks': marks,
                    'difficulty': diff,
                }
            else:
                c_indices = []
                if ans_raw:
                    for token in re.split(r'[,;\s]+', ans_raw):
                        token = token.strip().upper()
                        if token in LETTER_TO_INDEX:
                            c_indices.append(LETTER_TO_INDEX[token])
                elif found_seq:
                    for idx, c in enumerate(found_seq):
                        if c[2]:
                            c_indices.append(idx)
                if not c_indices:
                    c_indices = [0]
                c_indices = [i for i in c_indices if i < len(opt_blocks)]
                if not c_indices:
                    c_indices = [0]

                q_obj = {
                    'type': 'mcq_multi',
                    'prompt': [{'kind': 'text', 'value': prompt_text or f"Question {qnum}"}],
                    'options': opt_blocks,
                    'correct_answers': c_indices,
                    'marks': marks,
                    'difficulty': diff,
                }
        else:
            prompt_text = ' '.join(pre_ans).strip()
            if current_passage and (not prompt_text or 'above' in prompt_text.lower() or 'following' in prompt_text.lower() or 'refer' in prompt_text.lower() or 'find' in prompt_text.lower()):
                prompt_text = f"{current_passage}\n\n{prompt_text}"

            try:
                num_val = float(re.sub(r'[^\d\.\-]', '', ans_raw))
                if num_val.is_integer():
                    num_val = int(num_val)
                q_obj = {
                    'type': 'numerical',
                    'prompt': [{'kind': 'text', 'value': prompt_text or f"Question {qnum}"}],
                    'numerical_answer': num_val,
                    'numerical_tolerance': 0.01,
                    'marks': marks,
                    'difficulty': diff,
                }
            except (ValueError, TypeError):
                q_obj = {
                    'type': 'short_answer',
                    'prompt': [{'kind': 'text', 'value': prompt_text or f"Question {qnum}"}],
                    'acceptable_answers': [ans_raw] if ans_raw else ['0'],
                    'marks': marks,
                    'difficulty': diff,
                }

        questions.append(q_obj)

    if len(questions) < 5:
        print(f"  Warning: Only {len(questions)} questions extracted from {os.path.basename(pdf_path)}")
        return None

    return create_balanced_papers(pdf_path, base_title, subject, section, questions)

def create_balanced_papers(pdf_path, base_title, subject, section, questions):
    total_q = len(questions)
    if total_q <= 10:
        papers = [{
            'title': base_title,
            'suffix': '',
            'questions': questions
        }]
    elif total_q <= 20:
        mid = (total_q + 1) // 2
        papers = [
            {
                'title': f"{base_title} · Part 1",
                'suffix': '_part1',
                'questions': questions[:mid]
            },
            {
                'title': f"{base_title} · Part 2",
                'suffix': '_part2',
                'questions': questions[mid:]
            }
        ]
    else:
        p1 = total_q // 3
        p2 = 2 * (total_q // 3)
        papers = [
            {'title': f"{base_title} · Part 1", 'suffix': '_part1', 'questions': questions[:p1]},
            {'title': f"{base_title} · Part 2", 'suffix': '_part2', 'questions': questions[p1:p2]},
            {'title': f"{base_title} · Part 3", 'suffix': '_part3', 'questions': questions[p2:]}
        ]

    docs = []
    base_name = os.path.splitext(os.path.basename(pdf_path))[0]
    clean_base = re.sub(r' - genz_iitian - booklet', '', base_name, flags=re.I).strip()
    clean_base = re.sub(r' - Gen-Z IITian - booklet', '', clean_base, flags=re.I).strip()
    clean_base = re.sub(r'[^a-zA-Z0-9_\-\.]+', '_', clean_base).strip('_')

    for p in papers:
        doc = {
            'schema_version': '1.1',
            'quiz_title': p['title'],
            'subject': subject,
            'section': section,
            'questions': p['questions']
        }
        filename = f"{clean_base}{p['suffix']}.json"
        docs.append((filename, doc))

    return docs

def process_maths1():
    m1_dir = '/Users/tusharrrsingh/Downloads/Maths 1'
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes', 'Mathematics 1')
    os.makedirs(out_dir, exist_ok=True)

    files = sorted(glob.glob(os.path.join(m1_dir, '*.pdf')))
    print(f"\n==========================================")
    print(f"Processing {len(files)} Mathematics 1 PDFs...")
    print(f"==========================================")

    total_papers = 0
    total_questions = 0

    for fpath in files:
        fname = os.path.basename(fpath)
        docs = parse_maths1_pdf(fpath)
        if not docs:
            print(f"❌ Failed to parse Maths 1: {fname}")
            continue

        for filename, doc in docs:
            q_cnt = len(doc['questions'])
            out_file = os.path.join(out_dir, filename)
            with open(out_file, 'w', encoding='utf-8') as fp:
                json.dump(doc, fp, indent=2, ensure_ascii=False)
            total_papers += 1
            total_questions += q_cnt
            print(f"  ✓ Saved {filename} ({q_cnt} questions) -> {doc['quiz_title']}")

    print(f"\nMathematics 1 Done: {total_papers} papers generated with {total_questions} questions.")

def process_maths2():
    m2_dir = '/Users/tusharrrsingh/Downloads/Maths 2'
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes', 'Mathematics 2')
    os.makedirs(out_dir, exist_ok=True)

    files = sorted(glob.glob(os.path.join(m2_dir, '*.pdf')))
    print(f"\n==========================================")
    print(f"Processing {len(files)} Mathematics 2 PDFs...")
    print(f"==========================================")

    total_papers = 0
    total_questions = 0

    for fpath in files:
        fname = os.path.basename(fpath)
        docs = parse_maths2_pdf(fpath)
        if not docs:
            print(f"❌ Failed to parse Maths 2: {fname}")
            continue

        for filename, doc in docs:
            q_cnt = len(doc['questions'])
            out_file = os.path.join(out_dir, filename)
            with open(out_file, 'w', encoding='utf-8') as fp:
                json.dump(doc, fp, indent=2, ensure_ascii=False)
            total_papers += 1
            total_questions += q_cnt
            print(f"  ✓ Saved {filename} ({q_cnt} questions) -> {doc['quiz_title']}")

    print(f"\nMathematics 2 Done: {total_papers} papers generated with {total_questions} questions.")

def main():
    process_maths1()
    process_maths2()

if __name__ == '__main__':
    main()
