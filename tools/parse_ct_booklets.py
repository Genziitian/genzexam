#!/usr/bin/env python3
"""
Computational Thinking Booklet PDF -> Quiz Lab JSON Parser
Extracts questions from Gen-Z IITian booklet PDFs for Computational Thinking Quiz 1.

Enforces:
- Minimum 5, maximum 10 questions per paper (splits 12-14 Q papers into balanced parts of 6-7 Qs each)
- Preserves CT pseudocode, procedures, and indentation
- Automatically separates procedure steps (Step 1, Step 2, ...) into code blocks (pseudocode)
- Captures comprehension passages and attaches them to corresponding questions
- Schema version 1.1 matching templates/ques_template.json
"""

import os
import re
import sys
import glob
import json
import pypdf

LETTER_TO_INDEX = {'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6}
HEADER_RE = re.compile(r'^Q(\d+)\s+(MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)(?:\s+(\d+)\s+marks?)?(?:\s*·\s*(\w+))?', re.I)
ANS_RE = re.compile(r'^Answer\s*:\s*(.*)', re.I)
EXPL_RE = re.compile(r'^Explanation\s*:\s*(.*)', re.I)
OPT_MARKER_RE = re.compile(r'^(?:([A-G])|([✓✔]))(?:\s+(?![=+\-*/])(.*))?$', re.I)
FOOTER_RE = re.compile(r'^(?:EXAM\.GENZIITIAN|GENZIITIAN\.IN|YOUTUBE|Source:|Ecosystem|• Detailed|▶ Video|📚|Gen-Z IITian|P R E V I O U S|SUBJECT:|EXAM:|DATE:|PAPER:)', re.I)

def is_ct_code_line(ln, in_code=False):
    s = ln.strip()
    if not s:
        return in_code
    if ln.startswith('  ') or ln.startswith('\t'):
        return True
    if re.match(r'^(?:Procedure\b|End\s+Procedure\b|End\s+[A-Za-z]\w*)', s, re.I):
        return True
    if re.match(r'^(?:while\b|if\b|else\b|elif\b|for\b|return\b|repeat\b)', s, re.I):
        return True
    if re.match(r'^(?:Pick a card\b|Move\b|Read\b|Maintain\b|Arrange\b|Initialize\b|Stop\b|Divide\b|Store\b|Add\b|Increment\b)', s, re.I):
        return True
    if re.match(r'^[a-zA-Z_]\w*\s*(?:=|\+=|-=|\*=|/=|==|<=|>=|<|>)\s*', s):
        return True
    if re.match(r'^[a-zA-Z_]\w*(?:\s*,\s*[a-zA-Z_]\w*)*\s*=', s):
        return True
    if '*****' in s or s in ('{', '}', '{ }'):
        return True
    if in_code and (s.endswith('{') or s.endswith('}') or s.endswith(';') or s.endswith(')')):
        return True
    return False

def format_procedure_steps(text):
    """
    Extracts Step 1, Step 2, etc. from text and formats them as structured pseudocode.
    """
    matches = list(re.finditer(r'\b(Step\s*\d+\s*[:.-])\s*', text, re.I))
    if len(matches) < 2 or not re.match(r'^step\s*1\b', matches[0].group(1).strip(), re.I):
        return None

    intro = text[:matches[0].start()].strip()
    steps = []
    outro = ""
    for i in range(len(matches)):
        m = matches[i]
        header = m.group(1).strip()
        step_num = re.search(r'\d+', header).group(0)
        std_header = f"Step {step_num}:"

        if i + 1 < len(matches):
            next_m = matches[i + 1]
            body = text[m.end():next_m.start()].strip()
            steps.append(f"{std_header} {body}")
        else:
            full_last = text[m.end():].strip()
            outro_m = re.search(
                r'(?:(?<=\brepeat from step \d)|(?<=\brepeat from step \d\.)|(?<=\bstop the iteration)|(?<=\.))\s+(The value of\b.*|What will\b.*|It is a\b.*|Choose\b.*|Identify\b.*)',
                full_last,
                re.I
            )
            if outro_m:
                body = full_last[:outro_m.start()].strip()
                outro = full_last[outro_m.start():].strip()
            else:
                body = full_last.strip()
            steps.append(f"{std_header} {body}")

    code_val = "\n".join(steps)
    prompt_blocks = []
    if intro:
        prompt_blocks.append({"kind": "text", "value": intro})
    prompt_blocks.append({"kind": "code", "language": "pseudocode", "value": code_val})
    if outro:
        prompt_blocks.append({"kind": "text", "value": outro})
    return prompt_blocks

def split_text_code(lines):
    blocks = []
    curr_kind = None
    curr_lines = []
    in_code = False
    for ln in lines:
        if not ln.strip():
            if curr_lines:
                curr_lines.append('')
            continue
        is_c = is_ct_code_line(ln, in_code)
        kind = 'code' if is_c else 'text'
        in_code = (kind == 'code')
        if kind != curr_kind:
            if curr_lines and curr_kind:
                val = '\n'.join(curr_lines).strip()
                if val:
                    blocks.append((curr_kind, val))
            curr_kind = kind
            curr_lines = [ln]
        else:
            curr_lines.append(ln)
    if curr_lines and curr_kind:
        val = '\n'.join(curr_lines).strip()
        if val:
            blocks.append((curr_kind, val))
    return blocks

def build_prompt_blocks(comp_lines, prompt_lines):
    full_prompt_text = ' '.join(l.strip() for l in prompt_lines if l.strip())
    step_formatted = format_procedure_steps(full_prompt_text)

    res = []
    if comp_lines:
        comp_blocks = split_text_code(comp_lines)
        for k, v in comp_blocks:
            if k == 'code':
                res.append({'kind': 'code', 'language': 'pseudocode', 'value': v})
            else:
                res.append({'kind': 'text', 'value': ' '.join(v.splitlines())})

    if step_formatted:
        res.extend(step_formatted)
    else:
        q_blocks = split_text_code(prompt_lines)
        for k, v in q_blocks:
            if k == 'code':
                res.append({'kind': 'code', 'language': 'pseudocode', 'value': v})
            else:
                res.append({'kind': 'text', 'value': ' '.join(v.splitlines())})

    if not res:
        res = [{'kind': 'text', 'value': 'Question'}]
    return res

def parse_ct_pdf(pdf_path):
    try:
        reader = pypdf.PdfReader(pdf_path)
    except Exception as e:
        print(f"Error opening {pdf_path}: {e}")
        return None

    full_text = '\n'.join(p.extract_text() or '' for p in reader.pages)
    if not full_text.strip():
        return None

    # Metadata extraction
    date_m = re.search(r'DATE\s*:\s*([^\n]+)', full_text, re.I)
    paper_m = re.search(r'PAPER\s*:\s*([^\n]+)', full_text, re.I)
    raw_date = date_m.group(1).strip() if date_m else ''
    raw_paper = paper_m.group(1).strip() if paper_m else ''

    clean_date = re.sub(r'PAPER:.*', '', raw_date, flags=re.I).strip()
    clean_date = re.sub(r'[^\w\s]', '', clean_date).strip()
    clean_paper = re.sub(r'DATE:.*', '', raw_paper, flags=re.I).strip()

    subject = 'Computational Thinking'
    section = 'quiz1'

    base_title_parts = [subject, 'Quiz 1', clean_date, clean_paper]
    base_title = ' · '.join([p for p in base_title_parts if p])

    split_pattern = re.compile(r'(?=^Q\d+\s+(?:MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)\b|📖\s*Passage\b|📖\s*Comprehension\b)', re.M)
    parts = split_pattern.split(full_text)

    current_comprehension = None
    questions = []

    for part_idx, part in enumerate(parts):
        p_strip = part.strip()
        if not p_strip:
            continue

        if p_strip.startswith('📖') or re.match(r'^Passage\b', p_strip) or re.match(r'^Comprehension\b', p_strip):
            if part_idx == 0 or 'refer to these datasets (Scores, Words, Library' in p_strip:
                continue
            c_lines = [l for l in part.splitlines() if l.strip()]
            clean_c_lines = []
            for ln in c_lines[1:]:
                if FOOTER_RE.match(ln.strip()):
                    continue
                clean_c_lines.append(ln)
            current_comprehension = clean_c_lines
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
            opt_matches = []
            for idx, ln in enumerate(pre_ans):
                m = OPT_MARKER_RE.match(ln.strip())
                if m:
                    letter = m.group(1)
                    is_check = bool(m.group(2))
                    txt = (m.group(3) or '').strip()
                    # Skip English prose lines accidentally matching A
                    if letter == 'A' and re.match(r'^(?:procedure|programmer|student|dataset|pseudocode|card|table|person|variable)\b', txt, re.I):
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

            if not found_seq or len(found_seq) < 2:
                continue

            prompt_lines = pre_ans[:found_seq[0][0]]
            prompt_blocks = build_prompt_blocks(current_comprehension, prompt_lines)

            opt_blocks = []
            for opt_idx, cand in enumerate(found_seq):
                start_l = cand[0]
                end_l = found_seq[opt_idx + 1][0] if opt_idx + 1 < len(found_seq) else len(pre_ans)
                first_text = cand[3]
                cont_lines = pre_ans[start_l + 1 : end_l]
                all_opt_lines = ([first_text] if first_text else []) + [l.strip() for l in cont_lines if l.strip()]
                opt_str = '\n'.join(all_opt_lines)
                if '\n' in opt_str and any(is_ct_code_line(l) for l in all_opt_lines):
                    opt_blocks.append([{'kind': 'code', 'language': 'pseudocode', 'value': opt_str}])
                else:
                    opt_blocks.append([{'kind': 'text', 'value': ' '.join(all_opt_lines)}])

            if raw_type == 'MCQ':
                c_idx = 0
                if ans_raw:
                    letter = ans_raw.strip().upper()[:1]
                    if letter in LETTER_TO_INDEX:
                        c_idx = LETTER_TO_INDEX[letter]
                else:
                    for idx, c in enumerate(found_seq):
                        if c[2]:
                            c_idx = idx
                            break
                if c_idx >= len(opt_blocks):
                    c_idx = 0

                q_obj = {
                    'type': 'mcq_single',
                    'prompt': prompt_blocks,
                    'options': opt_blocks,
                    'correct_answer': c_idx,
                    'marks': marks,
                    'difficulty': diff,
                }
            else:
                c_indices = []
                if ans_raw:
                    for part_token in re.split(r'[,;\s]+', ans_raw):
                        token = part_token.strip().upper()
                        if token in LETTER_TO_INDEX:
                            c_indices.append(LETTER_TO_INDEX[token])
                if not c_indices:
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
                    'prompt': prompt_blocks,
                    'options': opt_blocks,
                    'correct_answers': c_indices,
                    'marks': marks,
                    'difficulty': diff,
                }
        else:
            prompt_lines = pre_ans
            prompt_blocks = build_prompt_blocks(current_comprehension, prompt_lines)
            try:
                num_val = float(re.sub(r'[^\d\.\-]', '', ans_raw))
                if num_val.is_integer():
                    num_val = int(num_val)
                q_obj = {
                    'type': 'numerical',
                    'prompt': prompt_blocks,
                    'numerical_answer': num_val,
                    'numerical_tolerance': 0.01,
                    'marks': marks,
                    'difficulty': diff,
                }
            except (ValueError, TypeError):
                q_obj = {
                    'type': 'short_answer',
                    'prompt': prompt_blocks,
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

    total_q = len(questions)
    if total_q <= 10:
        papers = [{
            'title': base_title,
            'suffix': '',
            'questions': questions
        }]
    elif total_q <= 20:
        mid = total_q // 2
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

def main():
    ct_dir = sys.argv[1] if len(sys.argv) > 1 else '/Users/tusharrrsingh/Downloads/CT'
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes', 'Computational Thinking')
    os.makedirs(out_dir, exist_ok=True)

    files = sorted(glob.glob(os.path.join(ct_dir, '*.pdf')))
    print(f"Found {len(files)} CT PDFs to process.")

    total_papers = 0
    total_questions = 0

    for fpath in files:
        fname = os.path.basename(fpath)
        docs = parse_ct_pdf(fpath)
        if not docs:
            print(f"❌ Failed to parse: {fname}")
            continue

        for filename, doc in docs:
            q_cnt = len(doc['questions'])
            out_file = os.path.join(out_dir, filename)
            with open(out_file, 'w', encoding='utf-8') as fp:
                json.dump(doc, fp, indent=2, ensure_ascii=False)
            total_papers += 1
            total_questions += q_cnt
            print(f"  ✓ Saved {filename} ({q_cnt} questions) -> {doc['quiz_title']}")

    print(f"\nDone! Generated {total_papers} papers with {total_questions} total questions in bulk_quizzes/Computational Thinking/.")

if __name__ == '__main__':
    main()
