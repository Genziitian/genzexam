#!/usr/bin/env python3
"""
Builder for 22 Mathematics 2 Quiz 1 question papers.
Conforms strictly to Quiz Lab Schema 1.1 and paper size constraints (5 <= Q <= 10).
All matrices and equations typeset in clean KaTeX.
All diagram questions use verified image crops.
"""

import os
import json

BASE_DIR = os.path.abspath("bulk_quizzes/Mathematics 2")
os.makedirs(BASE_DIR, exist_ok=True)

def t_block(text):
    return {"kind": "text", "value": text}

def img_block(url, alt):
    return {"kind": "image", "url": url, "alt": alt}

def mcq_single(prompt_blocks, options_text_or_blocks, correct_idx, marks=2, diff="medium", expl=""):
    opts = []
    for o in options_text_or_blocks:
        if isinstance(o, list):
            opts.append(o)
        elif isinstance(o, dict):
            opts.append([o])
        else:
            opts.append([t_block(str(o))])
    q = {
        "type": "mcq_single",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "options": opts,
        "correct_answer": correct_idx,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }
    return q

def mcq_multi(prompt_blocks, options_text_or_blocks, correct_indices, marks=3, diff="hard", expl=""):
    opts = []
    for o in options_text_or_blocks:
        if isinstance(o, list):
            opts.append(o)
        elif isinstance(o, dict):
            opts.append([o])
        else:
            opts.append([t_block(str(o))])
    q = {
        "type": "mcq_multi",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "options": opts,
        "correct_answers": correct_indices,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }
    return q

def numerical(prompt_blocks, answer, marks=2, diff="medium", expl="", tol=0.01):
    q = {
        "type": "numerical",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "numerical_answer": float(answer) if isinstance(answer, float) else int(answer),
        "numerical_tolerance": tol,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }
    return q

def short_ans(prompt_blocks, acceptable_answers, marks=2, diff="medium", expl=""):
    q = {
        "type": "short_answer",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "acceptable_answers": [str(a) for a in acceptable_answers],
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }
    return q

def save_paper(filename, title, section, questions):
    assert 5 <= len(questions) <= 10, f"Size error in {filename}: {len(questions)} Qs"
    data = {
        "schema_version": "1.1",
        "quiz_title": title,
        "subject": "Mathematics 2",
        "section": section,
        "questions": questions
    }
    path = os.path.join(BASE_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Saved: {filename} ({len(questions)} Qs)")
