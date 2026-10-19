import json, os, glob, re

SUBJECT_SUPPLEMENTS = {
    'Computational Thinking': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following computational processes best exemplifies an iteration abstraction?"}],
            "options": [
                [{"kind": "text", "value": "A loop that repeats a sequence of steps until a condition is met"}],
                [{"kind": "text", "value": "A function call with no return value"}],
                [{"kind": "text", "value": "A single conditional branch"}],
                [{"kind": "text", "value": "Declaring a global variable"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Iteration repeatedly executes a block of statements while a condition is satisfied."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Consider a dataset where each card represents a student with marks in Physics, Chemistry, and Maths. What algorithm can find the student with the highest total score in a single pass?"}],
            "options": [
                [{"kind": "text", "value": "Linear scan maintaining a variable for current maximum total and corresponding student"}],
                [{"kind": "text", "value": "Binary search on unsorted cards"}],
                [{"kind": "text", "value": "Bubble sort requiring O(N^2) comparisons"}],
                [{"kind": "text", "value": "Random sampling without replacement"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Finding the maximum over N unsorted elements requires scanning each element once (O(N) time) and keeping track of the running maximum."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In pseudocode, if variable `count` is incremented inside a loop that runs for each word containing at least one vowel, what does `count` represent after processing all cards?"}],
            "options": [
                [{"kind": "text", "value": "The total number of words that contain at least one vowel"}],
                [{"kind": "text", "value": "The total count of all vowels across all words"}],
                [{"kind": "text", "value": "The length of the longest word"}],
                [{"kind": "text", "value": "The number of consonants in the dataset"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Since count is incremented once per word matching the filter, it counts the qualifying words."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Suppose Table 1 has $N$ cards. If we move cards satisfying condition $C_1$ to Pile A and cards satisfying condition $C_2$ (mutually exclusive with $C_1$) to Pile B, what is the relationship between the card counts $|A|$, $|B|$, and $|\\text{remaining}|$?"}],
            "options": [
                [{"kind": "text", "value": "$|A| + |B| + |\\text{remaining}| = N$"}],
                [{"kind": "text", "value": "$|A| \\times |B| = N$"}],
                [{"kind": "text", "value": "$|A| + |B| = |\\text{remaining}| + N$"}],
                [{"kind": "text", "value": "$|A| - |B| = N$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Since the partition is mutually exclusive and exhaustive of moved cards, the sum equals total cards N."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary purpose of a sentinel value in an iteration over an unsorted sequence of unknown length?"}],
            "options": [
                [{"kind": "text", "value": "To signal the termination of the input or loop"}],
                [{"kind": "text", "value": "To reset the accumulator to zero"}],
                [{"kind": "text", "value": "To sort the elements in ascending order"}],
                [{"kind": "text", "value": "To compute the average of previous elements"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "A sentinel value is a special value whose presence indicates the end of data or sequence."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In flowchart notation, which geometric shape is standard for representing a decision or conditional branch?"}],
            "options": [
                [{"kind": "text", "value": "Diamond"}],
                [{"kind": "text", "value": "Rectangle"}],
                [{"kind": "text", "value": "Oval / Rounded rectangle"}],
                [{"kind": "text", "value": "Parallelogram"}]
            ],
            "correct_answer": 0,
            "marks": 1,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "In standard flowchart syntax, diamonds indicate decision branches, rectangles represent processes, and parallelograms represent input/output."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If a procedure filters rows where `Gender == 'Female'` and `CityTown == 'Chennai'`, which logical operator combines these two conditions?"}],
            "options": [
                [{"kind": "text", "value": "Logical AND (both conditions must be True)"}],
                [{"kind": "text", "value": "Logical OR (at least one condition must be True)"}],
                [{"kind": "text", "value": "Logical NOT (neither condition may be True)"}],
                [{"kind": "text", "value": "Logical XOR (exactly one condition must be True)"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Both predicates must simultaneously hold, so the conjunction AND is used."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "When comparing two nested loops over an $N$-element list to compare each distinct pair of items $(i, j)$ with $i < j$, how many total comparisons are performed?"}],
            "options": [
                [{"kind": "text", "value": "$\\frac{N(N - 1)}{2}$"}],
                [{"kind": "text", "value": "$N^2$"}],
                [{"kind": "text", "value": "$2N$"}],
                [{"kind": "text", "value": "$N!$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "The number of distinct unordered pairs from N elements is C(N, 2) = N(N - 1)/2."}]
        }
    ],
    'English 1': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Choose the sentence with the correct subject-verb agreement."}],
            "options": [
                [{"kind": "text", "value": "Neither the teacher nor the students were aware of the change in schedule."}],
                [{"kind": "text", "value": "Neither the teacher nor the students was aware of the change in schedule."}],
                [{"kind": "text", "value": "Neither the teachers nor the student were aware of the change in schedule."}],
                [{"kind": "text", "value": "Neither the teacher nor the student were aware of the change in schedule."}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "When subjects are joined by 'neither... nor', the verb agrees with the closer subject ('students' -> 'were')."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Identify the word that is an antonym of 'Ephemeral'."}],
            "options": [
                [{"kind": "text", "value": "Permanent"}],
                [{"kind": "text", "value": "Transient"}],
                [{"kind": "text", "value": "Fleeting"}],
                [{"kind": "text", "value": "Momentary"}]
            ],
            "correct_answer": 0,
            "marks": 1,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "'Ephemeral' means lasting for a very short time. Its opposite is 'Permanent'."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Fill in the blank with the appropriate preposition: 'She has been working on this project _____ three months.'"}],
            "options": [
                [{"kind": "text", "value": "for"}],
                [{"kind": "text", "value": "since"}],
                [{"kind": "text", "value": "from"}],
                [{"kind": "text", "value": "during"}]
            ],
            "correct_answer": 0,
            "marks": 1,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "'For' is used with a duration or period of time ('three months'), whereas 'since' refers to a specific starting point."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following sentences is written in the passive voice?"}],
            "options": [
                [{"kind": "text", "value": "The novel was written by George Orwell in 1948."}],
                [{"kind": "text", "value": "George Orwell wrote the novel in 1948."}],
                [{"kind": "text", "value": "The author completed the manuscript quickly."}],
                [{"kind": "text", "value": "Readers around the world admire the classic."}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The subject receives the action: 'was written by...'."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Choose the most appropriate discourse marker to complete the blank: 'He studied diligently; _____, he passed the examination with distinction.'"}],
            "options": [
                [{"kind": "text", "value": "consequently"}],
                [{"kind": "text", "value": "nevertheless"}],
                [{"kind": "text", "value": "on the contrary"}],
                [{"kind": "text", "value": "whereas"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "'Consequently' introduces a natural result or logical outcome of a preceding clause."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which word is correctly spelled?"}],
            "options": [
                [{"kind": "text", "value": "Accommodate"}],
                [{"kind": "text", "value": "Acommodate"}],
                [{"kind": "text", "value": "Accomodate"}],
                [{"kind": "text", "value": "Acomodate"}]
            ],
            "correct_answer": 0,
            "marks": 1,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The correct spelling is 'Accommodate' with double 'c' and double 'm'."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Identify the type of clause underlined in the sentence: '*Although it was raining heavily*, they decided to continue the football match.'"}],
            "options": [
                [{"kind": "text", "value": "Adverbial clause of concession"}],
                [{"kind": "text", "value": "Noun clause acting as subject"}],
                [{"kind": "text", "value": "Relative adjective clause"}],
                [{"kind": "text", "value": "Independent coordinate clause"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Clauses introduced by 'although' express a contrast or concession to the main clause."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the synonym of the word 'Pragmatic'?"}],
            "options": [
                [{"kind": "text", "value": "Practical"}],
                [{"kind": "text", "value": "Idealistic"}],
                [{"kind": "text", "value": "Theoretical"}],
                [{"kind": "text", "value": "Impractical"}]
            ],
            "correct_answer": 0,
            "marks": 1,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "'Pragmatic' means dealing with things sensibly and realistically in a practical way."}]
        }
    ]
}

# Add Maths 1 and Stats 1 supplements from parse_quiz2
import sys
sys.path.append('tools')
from parse_quiz2 import SUBJECT_SUPPLEMENTS as QUIZ2_SUPP

for subj, qs in QUIZ2_SUPP.items():
    SUBJECT_SUPPLEMENTS[subj] = qs

def supplement_low_count_files():
    repaired_count = 0
    for root, dirs, files in os.walk('bulk_quizzes'):
        if 'Diploma' in root: continue
        for f in files:
            if not f.endswith('.json'): continue
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8') as fp:
                d = json.load(fp)
            
            qs = d.get('questions', [])
            if len(qs) >= 8:
                continue
            
            subj = d.get('subject', '')
            if subj not in SUBJECT_SUPPLEMENTS:
                # normalize
                if 'math' in subj.lower() and '2' in subj.lower(): subj = 'Mathematics 2'
                elif 'math' in subj.lower(): subj = 'Mathematics 1'
                elif 'stat' in subj.lower() and '2' in subj.lower(): subj = 'Statistics 2'
                elif 'stat' in subj.lower(): subj = 'Statistics 1'
                elif 'comp' in subj.lower() or 'ct' in subj.lower(): subj = 'Computational Thinking'
                elif 'eng' in subj.lower() and '2' in subj.lower(): subj = 'English 2'
                elif 'eng' in subj.lower(): subj = 'English 1'
                elif 'py' in subj.lower(): subj = 'Python Programming'
            
            pool = SUBJECT_SUPPLEMENTS.get(subj, [])
            if not pool:
                print(f"No pool for {subj} in {p}")
                continue
            
            # Add supplements until >= 8
            existing_stems = set(q['prompt'][0]['value'] for q in qs)
            added = 0
            for sup in pool:
                stem = sup['prompt'][0]['value']
                if stem not in existing_stems:
                    qs.append(sup)
                    existing_stems.add(stem)
                    added += 1
                    if len(qs) >= 8:
                        break
            
            d['questions'] = qs
            with open(p, 'w', encoding='utf-8') as fp:
                json.dump(d, fp, indent=2, ensure_ascii=False)
            repaired_count += 1
            print(f"Repaired {p}: {len(qs)} questions (added {added})")

    print(f"Total files repaired: {repaired_count}")

supplement_low_count_files()
