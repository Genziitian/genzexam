import os, glob, json, math, re
from collections import defaultdict

def plan():
    files = sorted(glob.glob("bulk_quizzes/**/*.json", recursive=True))
    print(f"Total initial files: {len(files)}")

    # 1. Check exact duplicates
    to_delete = set()
    for f in files:
        if "bulk_quizzes/Python/" in f and " - booklet.json" in f:
            to_delete.add(f)
    print(f"Duplicates to delete: {len(to_delete)}")

    # 2. Check odd folders
    odd_folders = [f for f in files if "False" in f or "Hello Admin" in f]
    print(f"Odd folder files: {len(odd_folders)}")

    active_files = [f for f in files if f not in to_delete and f not in odd_folders]

    # Group by directory and section
    groups = defaultdict(list)
    for f in active_files:
        try:
            with open(f) as fp:
                d = json.load(fp)
            sec = d.get("section") or d.get("type") or "misc"
            groups[(os.path.dirname(f), sec)].append((f, d))
        except Exception as e:
            print(f"Err {f}: {e}")

    merge_count = 0
    split_count = 0
    single_under_5 = 0

    for (dpath, sec), flist in sorted(groups.items()):
        under_5 = [x for x in flist if len(x[1].get("questions", [])) < 5]
        over_10 = [x for x in flist if len(x[1].get("questions", [])) > 10]
        ok = [x for x in flist if 5 <= len(x[1].get("questions", [])) <= 10]

        if under_5:
            total_u5_q = sum(len(x[1].get("questions", [])) for x in under_5)
            print(f"[GROUP MERGE] {dpath} | {sec}: {len(under_5)} files, {total_u5_q} Qs")
            merge_count += len(under_5)

        if over_10:
            split_count += len(over_10)

    print(f"\nSummary:")
    print(f"Files to merge (< 5 Qs): {merge_count}")
    print(f"Files to split (> 10 Qs): {split_count}")

plan()
