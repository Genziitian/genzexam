#!/usr/bin/env python3
"""
Booklet PDF → Quiz Lab JSON Parser
Extracts questions from Gen-Z IITian booklet PDFs for Python, English 1, English 2, etc.
Enforces:
- Minimum 5 questions per paper (aims for >= 8; Python booklets have 13-18 questions)
- Preserves Python code blocks, indentation, and structure
- Comprehensive context preservation for multi-question comprehension sets
- Schema version 1.1 matching templates/ques_template.json
"""

import os
import re
import sys
import glob
import json
import pypdf

LETTER_TO_INDEX = {'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5}
HEADER_RE = re.compile(r'^Q(\d+)\s+(MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)(?:\s+(\d+)\s+marks?)?(?:\s*·\s*(\w+))?', re.I)
ANS_RE = re.compile(r'^Answer\s*:\s*(.*)', re.I)
EXPL_RE = re.compile(r'^Explanation\s*:\s*(.*)', re.I)
OPT_MARKER_RE = re.compile(r'^(?:([A-F])|([✓✔]))\s+(.*)')
FOOTER_RE = re.compile(r'^(?:EXAM\.GENZIITIAN|GENZIITIAN\.IN|YOUTUBE|Source:|Ecosystem|• Detailed|▶ Video|📚|Gen-Z IITian)', re.I)

def is_code_line(ln, in_c=False):
    s = ln.strip()
    if not s:
        return in_c
    if ln.startswith('  ') or ln.startswith('\t'):
        return True
    if s.startswith('#'):
        return True
    if re.match(r'^(?:def|for|while|if|elif|else:|try:|except|finally:|with|return|class|import|from|break|continue|pass)\b', s):
        return True
    if re.match(r'^(?:print|input)\s*\(', s):
        return True
    if re.match(r'^\d+\s+(?:def|for|while|if|elif|else:|return|print|input|\w+[\s,]*=)', s):
        return True
    if re.match(r'^not\s*\(', s) or re.match(r'^not\s+not\b', s) or re.match(r'^not\s+[a-zA-Z_]\w*\b', s):
        return True
    if re.match(r'^[a-zA-Z_]\w*(?:\[[^\]]+\])*(?:\s*,\s*[a-zA-Z_]\w*(?:\[[^\]]+\])*)*\s*(?:=|\+=|-=|\*=|/=|//=)\s*', s):
        return True
    if re.match(r'^[a-zA-Z_]\w*\.[a-zA-Z_]\w*\(', s):
        return True
    if in_c and (s.endswith(',') or s.endswith(']') or s.endswith('}') or s.endswith(')') or s.startswith(']') or s.startswith('}') or s.startswith(')')):
        return True
    if in_c and re.match(r'^[\'\"].*[\'\"][\s,]*$', s):
        return True
    return False

def split_text_code(lines):
    blocks = []
    curr_kind = None
    curr_lines = []
    in_c = False
    for ln in lines:
        if not ln.strip():
            if curr_lines:
                curr_lines.append('')
            continue
        is_c = is_code_line(ln, in_c)
        kind = 'code' if is_c else 'text'
        in_c = True if kind == 'code' else False
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
    res = []
    comp_blocks = split_text_code(comp_lines) if comp_lines else []
    q_blocks = split_text_code(prompt_lines)

    comp_has_code = any(b[0] == 'code' for b in comp_blocks)
    if comp_has_code:
        for k, v in comp_blocks:
            if k == 'code':
                res.append({'kind': 'code', 'language': 'python', 'value': v})
            else:
                res.append({'kind': 'text', 'value': ' '.join(v.splitlines())})
    for k, v in q_blocks:
        if k == 'code':
            res.append({'kind': 'code', 'language': 'python', 'value': v})
        else:
            res.append({'kind': 'text', 'value': ' '.join(v.splitlines())})
    if not res:
        res = [{'kind': 'text', 'value': 'Question'}]
    return res

def parse_booklet_pdf(pdf_path, override_subject=None, override_section=None):
    try:
        reader = pypdf.PdfReader(pdf_path)
    except Exception as e:
        print(f"Error opening {pdf_path}: {e}")
        return None

    full_text = '\n'.join(p.extract_text() or '' for p in reader.pages)
    if not full_text.strip() or 'ERR_FILE_NOT_FOUND' in full_text:
        return None

    # Metadata extraction
    subj_m = re.search(r'SUBJECT\s*\n\s*([^\n]+)', full_text, re.I)
    exam_m = re.search(r'E\s*X\s*A\s*M\s*\n\s*([^\n]+)', full_text, re.I)
    date_m = re.search(r'DATE\s*\n\s*([^\n]+)', full_text, re.I)
    paper_m = re.search(r'PAPER\s*\n\s*([^\n]+)', full_text, re.I)

    raw_subject = subj_m.group(1).strip() if subj_m else 'Python'
    raw_exam = exam_m.group(1).strip() if exam_m else 'Quiz 1'
    date = date_m.group(1).strip() if date_m else ''
    paper = paper_m.group(1).strip() if paper_m else ''

    subject = override_subject or raw_subject
    if subject.lower() in ('python', 'intro to python'):
        subject = 'Python Programming'
    elif subject.lower() in ('english 1', 'eng 1'):
        subject = 'English 1'
    elif subject.lower() in ('english 2', 'eng 2'):
        subject = 'English 2'

    section = override_section or ('quiz1' if 'quiz 1' in raw_exam.lower() else 'quiz2' if 'quiz 2' in raw_exam.lower() else 'practice')

    clean_date = re.sub(r'[^\w\s]', '', date).strip()
    title_parts = [subject, 'Quiz 1' if section == 'quiz1' else 'Quiz 2' if section == 'quiz2' else 'Exam', clean_date, paper]
    title = ' · '.join([p for p in title_parts if p])

    # Split by Q<number> header or Comprehension header
    split_pattern = re.compile(r'(?=^Q\d+\s+(?:MCQ|MSQ|MULTI-SELECT|NUMERICAL|NAT|SA)\b|📖\s*Comprehension\b)', re.M)
    parts = split_pattern.split(full_text)

    current_comprehension = None
    questions = []

    for part in parts:
        p_strip = part.strip()
        if not p_strip:
            continue

        if p_strip.startswith('📖') or re.match(r'^Comprehension\b', p_strip):
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
                    txt = m.group(3).strip()
                    if not txt.startswith('='):
                        opt_matches.append((idx, m.group(1), bool(m.group(2)), txt))

            found_seq = None
            for n_opts in range(6, 1, -1):
                if len(opt_matches) < n_opts:
                    continue
                cand = opt_matches[-n_opts:]
                if all(cand[k][2] or cand[k][1] == chr(ord('A') + k) for k in range(n_opts)):
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
                all_opt_lines = [first_text] + [l.strip() for l in cont_lines if l.strip()]
                opt_str = '\n'.join(all_opt_lines)
                if '\n' in opt_str and any(is_code_line(l) for l in all_opt_lines):
                    opt_blocks.append([{'kind': 'code', 'language': 'python', 'value': opt_str}])
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
                    for part in re.split(r'[,;\s]+', ans_raw):
                        part = part.strip().upper()
                        if part in LETTER_TO_INDEX:
                            c_indices.append(LETTER_TO_INDEX[part])
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
        return None

    return {
        'schema_version': '1.1',
        'quiz_title': title,
        'subject': subject,
        'section': section,
        'questions': questions
    }

def main():
    default_dir = os.path.expanduser('~/Downloads/Python')
    pdf_dir = sys.argv[1] if len(sys.argv) > 1 else default_dir
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'bulk_quizzes', 'Python')
    os.makedirs(out_dir, exist_ok=True)

    if os.path.isfile(pdf_dir):
        files = [pdf_dir]
    else:
        files = sorted(glob.glob(os.path.join(pdf_dir, 'Python_Quiz1_* booklet.pdf')))
        if not files:
            files = sorted(glob.glob(os.path.join(pdf_dir, '*.pdf')))

    print(f"Found {len(files)} PDFs to parse.")
    results = []

    for fpath in files:
        base_name = os.path.splitext(os.path.basename(fpath))[0]
        data = parse_booklet_pdf(fpath)
        if not data:
            print(f"❌ Failed: {base_name}")
            continue

        q_count = len(data.get('questions', []))
        if q_count < 5:
            print(f"⚠️ Skipped (<5 questions: {q_count}): {base_name}")
            continue

        # Save primary output matching <filename>.json
        out_file = os.path.join(out_dir, f"{base_name}.json")
        with open(out_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        # Also save clean version without ' - booklet' suffix for flexible imports
        if ' - booklet' in base_name:
            clean_name = base_name.replace(' - booklet', '')
            clean_file = os.path.join(out_dir, f"{clean_name}.json")
            with open(clean_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"✅ Saved ({q_count} questions): {out_file}")
        results.append((base_name, q_count, data['quiz_title']))

    print(f"\nDone! Processed {len(results)}/{len(files)} papers successfully.")
    return results

if __name__ == '__main__':
    main()
