#!/usr/bin/env python3
"""
Format Computational Thinking questions that have multi-step procedures into
structured prompts with code blocks:
- Intro question text as kind: "text"
- Procedure steps formatted line-by-line as kind: "code", language: "pseudocode"
- Follow-up/trailing question text as kind: "text"
"""

import os
import glob
import json
import re

def format_ct_steps(text):
    matches = list(re.finditer(r"\b(Step\s*\d+\s*[:.-])\s*", text, re.I))
    if len(matches) < 2:
        return None
    if not re.match(r"^step\s*1\b", matches[0].group(1).strip(), re.I):
        return None

    intro = text[:matches[0].start()].strip()
    steps = []
    outro = ""
    for i in range(len(matches)):
        m = matches[i]
        header = m.group(1).strip()
        step_num = re.search(r"\d+", header).group(0)
        std_header = f"Step {step_num}:"

        if i + 1 < len(matches):
            next_m = matches[i + 1]
            body = text[m.end():next_m.start()].strip()
            steps.append(f"{std_header} {body}")
        else:
            full_last = text[m.end():].strip()
            outro_m = re.search(
                r"(?:(?<=\brepeat from step \d)|(?<=\brepeat from step \d\.)|(?<=\bstop the iteration)|(?<=\.))\s+(The value of\b.*|What will\b.*|It is a\b.*)",
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

def run():
    all_files = sorted(glob.glob("bulk_quizzes/**/*.json", recursive=True))
    updated_files = 0
    updated_questions = 0

    for f in all_files:
        with open(f, 'r', encoding='utf-8') as fp:
            d = json.load(fp)

        file_changed = False
        subj = str(d.get('subject', '')).lower()
        # Apply to CT or any file with CT questions
        is_ct = 'computational' in subj or 'ct' in subj or 'computational thinking' in f.lower()
        if not is_ct:
            continue

        for q_idx, q in enumerate(d.get('questions', [])):
            new_prompt = []
            q_changed = False
            for b in q.get('prompt', []):
                if b.get('kind') == 'text' and 'step 1' in b.get('value', '').lower():
                    formatted = format_ct_steps(b.get('value', ''))
                    if formatted:
                        new_prompt.extend(formatted)
                        q_changed = True
                    else:
                        new_prompt.append(b)
                else:
                    new_prompt.append(b)

            if q_changed:
                q['prompt'] = new_prompt
                file_changed = True
                updated_questions += 1
                print(f"Updated Question {q_idx + 1} in {os.path.basename(f)}")

        if file_changed:
            with open(f, 'w', encoding='utf-8') as fp:
                json.dump(d, fp, indent=2, ensure_ascii=False)
            updated_files += 1

    print(f"\nDone: Updated {updated_questions} questions across {updated_files} files.")

if __name__ == '__main__':
    run()
