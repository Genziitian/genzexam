#!/usr/bin/env python3
"""
Builder for Booklets 1 to 4 of Mathematics 2 Quiz 1:
- 15 Mar 2026 (Part 1 & 2)
- Feb 2024 QDD4 (Part 1 & 2)
- Feb 2025 QIP4 (Part 1 & 2)
- Jul 2023 Foundation AN4 Exam 2 (Part 1 & 2)
"""

import os
import json

BASE_DIR = os.path.abspath("bulk_quizzes/Mathematics 2")
os.makedirs(BASE_DIR, exist_ok=True)

def t_block(text):
    return {"kind": "text", "value": text}

def img_block(url, alt):
    return {"kind": "image", "url": url, "alt": alt}

def mcq_single(prompt_blocks, options, correct_idx, marks=2, diff="medium", expl=""):
    opts = []
    for o in options:
        if isinstance(o, list):
            opts.append(o)
        elif isinstance(o, dict):
            opts.append([o])
        else:
            opts.append([t_block(str(o))])
    return {
        "type": "mcq_single",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "options": opts,
        "correct_answer": correct_idx,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def mcq_multi(prompt_blocks, options, correct_indices, marks=3, diff="hard", expl=""):
    opts = []
    for o in options:
        if isinstance(o, list):
            opts.append(o)
        elif isinstance(o, dict):
            opts.append([o])
        else:
            opts.append([t_block(str(o))])
    return {
        "type": "mcq_multi",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "options": opts,
        "correct_answers": correct_indices,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def numerical(prompt_blocks, answer, marks=2, diff="medium", expl="", tol=0.01):
    return {
        "type": "numerical",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "numerical_answer": float(answer) if isinstance(answer, float) else int(answer),
        "numerical_tolerance": tol,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def short_ans(prompt_blocks, acceptable_answers, marks=2, diff="medium", expl=""):
    return {
        "type": "short_answer",
        "prompt": prompt_blocks if isinstance(prompt_blocks, list) else [t_block(prompt_blocks)],
        "acceptable_answers": [str(a) for a in acceptable_answers],
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

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


def build_booklet_1():
    # 15 Mar 2026 (13 Qs: Part 1 = 7 Qs, Part 2 = 6 Qs)
    p1_qs = [
        mcq_single(
            "Consider the system of linear equations:\n$$x + y + z = 3$$\n$$2x + 3y + kz = 6$$\n$$3x + 5y + (k+1)z = 9$$\nWhich of the following statements is true?",
            [
                "The system has a unique solution for $k = 1$.",
                "The system has no solution for all $k$.",
                "The system has infinitely many solutions for $k = 1$.",
                "The system has infinitely many solutions for $k = 0$."
            ],
            2, marks=2, diff="medium",
            expl="Row reducing the augmented matrix shows that for $k = 1$, the third equation becomes redundant, yielding a free variable and infinitely many solutions."
        ),
        mcq_single(
            "Let $A$ be a $3 \\times 3$ matrix such that $\\det(A) = 4$. What is the value of $\\det(2A^{-1})$?",
            ["2", "4", "1/2", "1"],
            0, marks=2, diff="medium",
            expl="$\\det(2A^{-1}) = 2^3 \\det(A^{-1}) = \\frac{8}{\\det(A)} = \\frac{8}{4} = 2$."
        ),
        mcq_single(
            "Which of the following subsets of $\\mathbb{R}^3$ is a vector subspace of $\\mathbb{R}^3$?",
            [
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x + 2y - z = 0\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 1\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : xy = 0\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x^2 + y^2 + z^2 \\le 1\\}$"
            ],
            0, marks=2, diff="medium",
            expl="Only $x + 2y - z = 0$ is a homogeneous linear equation containing the origin and closed under linear combinations."
        ),
        mcq_multi(
            "Let $a, b, c, d$ be distinct real numbers. Consider the Vandermonde matrix:\n$$A = \\begin{pmatrix} 1 & a & a^2 & a^3 \\\\ 1 & b & b^2 & b^3 \\\\ 1 & c & c^2 & c^3 \\\\ 1 & d & d^2 & d^3 \\end{pmatrix}$$\nWhich of the following statements are correct?",
            [
                "$\\det(A) \\neq 0$",
                "The columns of $A$ are linearly independent.",
                "$\\text{rank}(A) = 4$",
                "The system $Ax = 0$ has non-trivial solutions."
            ],
            [0, 1, 2], marks=3, diff="hard",
            expl="For distinct $a, b, c, d$, the Vandermonde determinant $\\det(A) = (b-a)(c-a)(d-a)(c-b)(d-b)(d-c) \\neq 0$. Thus $A$ is invertible, has full rank 4, linearly independent columns, and only the trivial solution $x = 0$."
        ),
        mcq_single(
            "Let $v_1 = (1, 1, 0)$, $v_2 = (0, 1, 1)$, and $v_3 = (1, 0, 1)$ be vectors in $\\mathbb{R}^3$. Which of the following statements is true?",
            [
                "$\\{v_1, v_2, v_3\\}$ is linearly dependent.",
                "$\\{v_1, v_2, v_3\\}$ forms a basis of $\\mathbb{R}^3$.",
                "$\\text{span}\\{v_1, v_2, v_3\\}$ is a plane in $\\mathbb{R}^3$.",
                "$v_1 + v_2 + v_3 = (0, 0, 0)$"
            ],
            1, marks=2, diff="medium",
            expl="The determinant of the matrix formed by $v_1, v_2, v_3$ is $1(1) + 1(1) = 2 \\neq 0$. Hence the vectors are linearly independent and form a basis of $\\mathbb{R}^3$."
        ),
        numerical(
            "Find the determinant of the upper triangular matrix:\n$$A = \\begin{pmatrix} 2 & 1 & 0 \\\\ 0 & 3 & 4 \\\\ 0 & 0 & 5 \\end{pmatrix}$$",
            30, marks=2, diff="medium",
            expl="For a triangular matrix, determinant is the product of diagonal entries: $2 \\times 3 \\times 5 = 30$."
        ),
        numerical(
            "Consider the matrix $A = \\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}$. Find the trace of $A^2$.",
            29, marks=2, diff="medium",
            expl="$A^2 = \\begin{pmatrix} 7 & 10 \\\\ 15 & 22 \\end{pmatrix}$, so $\\text{tr}(A^2) = 7 + 22 = 29$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_15_Mar_2026_part1.json", "Mathematics 2 · Quiz 1 · 15 Mar 2026 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Let $A$ be a $3 \\times 3$ matrix of rank 2. What is the dimension of the null space (nullity) of $A$?",
            1, marks=2, diff="medium",
            expl="By the Rank-Nullity theorem: $\\text{rank}(A) + \\text{nullity}(A) = 3 \\implies 2 + \\text{nullity} = 3 \\implies \\text{nullity} = 1$."
        ),
        numerical(
            "Let $W$ be the subspace of $\\mathbb{R}^4$ defined by $W = \\{(x_1, x_2, x_3, x_4) \\in \\mathbb{R}^4 : x_1 + x_2 + x_3 + x_4 = 0 \\text{ and } x_1 - x_4 = 0\\}$. What is the dimension of $W$?",
            2, marks=2, diff="medium",
            expl="Two linearly independent linear constraints on $\\mathbb{R}^4$ yield a subspace of dimension $4 - 2 = 2$."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{bmatrix} 3 & 4 & -1 & 3 \\\\ 5 & 2 & 7 & 1 \\\\ 7 & k_1 & 15 & k_2 \\end{bmatrix}$$\nIf the rank of $A$ is 2, find the value of $k_1$.",
            0, marks=2, diff="hard",
            expl="Row 3 must be a linear combination of Row 1 and Row 2. $R_3 = -R_1 + 2R_2$. For column 2: $k_1 = -1(4) + 2(2) = 0$."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{bmatrix} 3 & 4 & -1 & 3 \\\\ 5 & 2 & 7 & 1 \\\\ 7 & k_1 & 15 & k_2 \\end{bmatrix}$$\nIf the rank of $A$ is 2, find the value of $k_2$.",
            -1, marks=2, diff="hard",
            expl="With $R_3 = -R_1 + 2R_2$, column 4 gives $k_2 = -(3) + 2(1) = -1$."
        ),
        mcq_single(
            "Let $W = \\{(x, y) \\in \\mathbb{R}^2 : x > 0, y > 0\\}$. Define vector addition $\\oplus$ and scalar multiplication $\\odot$ on $W$ by:\n$$(x_1, y_1) \\oplus (x_2, y_2) = (x_1 x_2, y_1 y_2)$$\n$$c \\odot (x, y) = (x^c, y^c) \\quad \\text{for } c \\in \\mathbb{R}$$\nWhat is the additive identity (zero vector) of the vector space $(W, \\oplus, \\odot)$?",
            ["$(0, 0)$", "$(0, 1)$", "$(1, 1)$", "$(e, e)$"],
            2, marks=2, diff="medium",
            expl="For any $(x, y) \\in W$, $(x, y) \\oplus (e_1, e_2) = (x e_1, y e_2) = (x, y) \\implies e_1 = 1, e_2 = 1$."
        ),
        numerical(
            "Let $W = \\{(x, y) \\in \\mathbb{R}^2 : x > 0, y > 0\\}$ be the vector space over $\\mathbb{R}$ with operations:\n$$(x_1, y_1) \\oplus (x_2, y_2) = (x_1 x_2, y_1 y_2) \\quad \\text{and} \\quad c \\odot (x, y) = (x^c, y^c)$$\nWhat is the dimension of this vector space $W$?",
            2, marks=2, diff="medium",
            expl="Under the coordinate map $(x, y) \\mapsto (\\ln x, \\ln y)$, $W$ is isomorphic to the standard vector space $\\mathbb{R}^2$, so $\\dim(W) = 2$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_15_Mar_2026_part2.json", "Mathematics 2 · Quiz 1 · 15 Mar 2026 · Part 2", "quiz1", p2_qs)


def build_booklet_2():
    # Feb 2024 QDD4 (17 Qs: Q2 to Q18 -> Part 1 = 9 Qs, Part 2 = 8 Qs)
    p1_qs = [
        numerical(
            "Find the determinant of the $5 \\times 5$ matrix:\n$$A = \\begin{pmatrix} 0 & 1 & 0 & 0 & 0 \\\\ 0 & 0 & 0 & 1 & 0 \\\\ 1 & 0 & 0 & 0 & 0 \\\\ 0 & 0 & 0 & 0 & 1 \\\\ 0 & 0 & 1 & 0 & 0 \\end{pmatrix}$$",
            -1, marks=2, diff="medium",
            expl="This permutation matrix corresponds to the permutation $(1\\;2\\;4\\;5\\;3)$, which is an odd permutation (3 inversions/swaps), so $\\det(A) = -1$."
        ),
        numerical(
            "Given that the determinant of the $3 \\times 3$ matrix $\\begin{pmatrix} a & b & c \\\\ d & e & f \\\\ g & h & i \\end{pmatrix}$ is $2$, find the determinant of the bordered $4 \\times 4$ matrix:\n$$\\begin{pmatrix} a & b & c & 0 \\\\ d & e & f & 0 \\\\ g & h & i & 0 \\\\ 5 & 4 & -5 & 5 \\end{pmatrix}$$",
            10, marks=2, diff="medium",
            expl="Expanding along the last column: $\\det = 5 \\times \\det\\begin{pmatrix} a & b & c \\\\ d & e & f \\\\ g & h & i \\end{pmatrix} = 5 \\times 2 = 10$."
        ),
        mcq_single(
            "Let $V = \\{(x, y, 5) : x, y \\in \\mathbb{R}\\}$. Define addition and scalar multiplication as follows:\n$$\\text{Addition}: (x_1, y_1, 5) + (x_2, y_2, 5) = (x_1 + x_2, y_1 + y_2, 5)$$\n$$\\text{Scalar multiplication}: c(x, y, 5) = (cx, cy, 5) \\quad \\text{for } c \\in \\mathbb{R}$$\nIs the set $V$ closed under addition?",
            ["Yes", "No"],
            0, marks=1, diff="easy",
            expl="The sum of any two elements in $V$ has third coordinate 5, which belongs to $V$. Thus $V$ is closed under addition."
        ),
        mcq_single(
            "Let $V = \\{(x, y, 5) : x, y \\in \\mathbb{R}\\}$. Define addition and scalar multiplication as follows:\n$$\\text{Addition}: (x_1, y_1, 5) + (x_2, y_2, 5) = (x_1 + x_2, y_1 + y_2, 5)$$\n$$\\text{Scalar multiplication}: c(x, y, 5) = (cx, cy, 5) \\quad \\text{for } c \\in \\mathbb{R}$$\nIs the set $V$ closed under scalar multiplication?",
            ["Yes", "No"],
            0, marks=1, diff="easy",
            expl="For any scalar $c$ and $(x, y, 5) \\in V$, $c(x, y, 5) = (cx, cy, 5) \\in V$. Thus $V$ is closed under scalar multiplication."
        ),
        mcq_multi(
            "Let $V = \\{(x, y, 5) : x, y \\in \\mathbb{R}\\}$ with addition $(x_1, y_1, 5) + (x_2, y_2, 5) = (x_1 + x_2, y_1 + y_2, 5)$ and scalar multiplication $c(x, y, 5) = (cx, cy, 5)$. Which of the following statements is/are correct?",
            [
                "$V$ has no zero element with respect to the given addition.",
                "$(0, 0, 0)$ is the zero element of $V$ with respect to the given addition.",
                "$(0, 0, 5)$ is the zero element of $V$ with respect to the given addition.",
                "For any real number $c$, we always have $c(0, 1, 5) = (0, 1, 5)$.",
                "For each element $v \\in V$ and for each pair $a, b \\in \\mathbb{R}$, $(a + b)v = av + bv$ fails (or axiom check)."
            ],
            [2, 4], marks=2, diff="hard",
            expl="$(x, y, 5) + (0, 0, 5) = (x, y, 5)$, so $(0, 0, 5)$ is the zero element. Also, axiom $(a+b)v = av + bv$ evaluates to $((a+b)x, (a+b)y, 5) \\neq ((a+b)x, (a+b)y, 10)$, which correctly distinguishes this structure."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 1 & 1/3 \\\\ c & d \\end{bmatrix}$ such that $A^2 = 0$. Find the value of $c$.",
            -3, marks=1, diff="medium",
            expl="$A^2 = \\begin{bmatrix} 1 + c/3 & 1/3 + d/3 \\\\ c + cd & c/3 + d^2 \\end{bmatrix} = \\begin{bmatrix} 0 & 0 \\\\ 0 & 0 \\end{bmatrix} \\implies 1 + c/3 = 0 \\implies c = -3$."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 1 & 1/3 \\\\ c & d \\end{bmatrix}$ such that $A^2 = 0$. Find the value of $d$.",
            -1, marks=1, diff="medium",
            expl="From $1/3 + d/3 = 0$, we have $d = -1$."
        ),
        numerical(
            "Consider the following system of linear equations:\n$$2x - y + 3z = 0$$\n$$ax - y + z = 0$$\n$$4x - 2y + 7z = 0$$\nDoes there exist an $a$ such that the system has infinitely many solutions? If yes, find the value of $a$, else enter 100.",
            2, marks=2, diff="medium",
            expl="For a homogeneous system to have infinitely many solutions, the determinant must be 0: $\\det \\begin{pmatrix} 2 & -1 & 3 \\\\ a & -1 & 1 \\\\ 4 & -2 & 7 \\end{pmatrix} = 2(-7+2) + 1(7a-4) + 3(-2a+4) = -10 + 7a - 4 - 6a + 12 = a - 2 = 0 \\implies a = 2$."
        ),
        numerical(
            "Consider the following system of linear equations:\n$$2x - y + 3z = 0$$\n$$ax - y + z = 0$$\n$$4x - 2y + 7z = 0$$\nDoes there exist an $a$ such that the system has no solution? If yes, find the value of $a$, else enter 100.",
            100, marks=1, diff="medium",
            expl="Every homogeneous system $Ax = 0$ is always consistent because $x = (0, 0, 0)$ is always a solution. Thus no solution never occurs; per instructions, enter 100."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Feb_2024_-_QDD4_part1.json", "Mathematics 2 · Quiz 1 · Feb 2024 · QDD4 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Consider the following subset of $M_{3\\times 3}(\\mathbb{R})$:\n$$W_1 = \\left\\{ \\begin{bmatrix} a & 0 & 0 \\\\ 0 & b & 0 \\\\ 0 & 0 & c \\end{bmatrix} : a + b + c = 1 \\right\\}$$\nIf $W_1$ is a subspace, find its dimension, else enter 0.",
            0, marks=1, diff="medium",
            expl="$W_1$ does not contain the zero matrix (since $0 + 0 + 0 = 0 \\neq 1$), so it is not a subspace. Answer: 0."
        ),
        numerical(
            "Consider the following subset of $M_{3\\times 3}(\\mathbb{R})$:\n$$W_2 = \\left\\{ \\begin{bmatrix} a & 0 & 0 \\\\ 0 & b & 0 \\\\ 0 & 0 & c \\end{bmatrix} : a = b = c \\right\\}$$\nIf $W_2$ is a subspace, find its dimension, else enter 0.",
            1, marks=1, diff="medium",
            expl="$W_2$ is spanned by the single identity matrix $I_3$, so it is a subspace of dimension 1."
        ),
        numerical(
            "Consider the following subset of $M_{3\\times 3}(\\mathbb{R})$:\n$$W_3 = \\left\\{ \\begin{bmatrix} a & 0 & 0 \\\\ 0 & b & 0 \\\\ 0 & 0 & c \\end{bmatrix} : a, b, c \\in \\mathbb{R} \\right\\}$$\nIf $W_3$ is a subspace, find its dimension, else enter 0.",
            3, marks=1, diff="medium",
            expl="$W_3$ is the set of all $3 \\times 3$ diagonal matrices, which has dimension 3."
        ),
        numerical(
            "Let $u = (1, 2, -1)^T$, $v = (2, 1, 0)^T$, and $w = (-1, 4, -3)^T$. Let $A \\in M_{3\\times 3}(\\mathbb{R})$ such that $Au = u$ and $Av = -v$. Note that $w = 3u - 2v$. If $Aw = (a, b, c)^T$, find the value of $a$.",
            7, marks=1, diff="hard",
            expl="$Aw = A(3u - 2v) = 3Au - 2Av = 3u + 2v = 3(1, 2, -1)^T + 2(2, 1, 0)^T = (7, 8, -3)^T$. Thus $a = 7$."
        ),
        numerical(
            "Let $u = (1, 2, -1)^T$, $v = (2, 1, 0)^T$, and $w = (-1, 4, -3)^T$. Let $A \\in M_{3\\times 3}(\\mathbb{R})$ such that $Au = u$ and $Av = -v$. Note that $w = 3u - 2v$. If $Aw = (a, b, c)^T$, find the value of $b$.",
            8, marks=1, diff="hard",
            expl="From $Aw = 3u + 2v = (7, 8, -3)^T$, we have $b = 8$."
        ),
        numerical(
            "Let $u = (1, 2, -1)^T$, $v = (2, 1, 0)^T$, and $w = (-1, 4, -3)^T$. Let $A \\in M_{3\\times 3}(\\mathbb{R})$ such that $Au = u$ and $Av = -v$. Note that $w = 3u - 2v$. If $Aw = (a, b, c)^T$, find the value of $c$.",
            -3, marks=1, diff="hard",
            expl="From $Aw = 3u + 2v = (7, 8, -3)^T$, we have $c = -3$."
        ),
        mcq_multi(
            "Select all true statements regarding matrices and reduced row echelon form (RREF):",
            [
                "$\\begin{bmatrix} 1 & 0 & 0 & 0 \\\\ 0 & 0 & 1 & 2 \\\\ 0 & 0 & 0 & 0 \\end{bmatrix}$ is in reduced row echelon form.",
                "The reduced row echelon form of any square, invertible matrix is the identity matrix of the same order.",
                "Elementary row operations can be performed only on square matrices.",
                "If a matrix is in reduced row echelon form, its last row will always be a zero row."
            ],
            [0, 1], marks=3, diff="medium",
            expl="The given matrix satisfies all RREF conditions (leading 1s, zeros above and below leading 1s, zero rows at bottom). Any invertible matrix reduces to $I$. Elementary operations apply to matrices of any size."
        ),
        mcq_multi(
            "Consider the vectors $v_1 = (1, -1, 0)$, $v_2 = (2, 3, -1)$, and $v_3 = (a, b, c)$ in $\\mathbb{R}^3$. Choose the correct options from the following:",
            [
                "If $a = 5, b = 0, c = -1$, then the set $\\{v_1, v_2, v_3\\}$ forms a basis for $\\mathbb{R}^3$.",
                "If $a = 5, b = 0, c = -1$, then the vectors $\\{v_1, v_2, v_3\\}$ are linearly dependent.",
                "If $a = 5, b = 0, c = -1$ and $A$ is the matrix with $v_1, v_2, v_3$ as its columns, then $\\text{rank}(A) = 3$.",
                "If $a = 2, b = 3, c = 1$, then the subspace spanned by $\\{v_1, v_2, v_3\\}$ has dimension 3.",
                "If $a = 2, b = 3, c = 1$ and $A$ is the matrix with $v_1, v_2, v_3$ as its columns, then $A$ is invertible."
            ],
            [1, 3, 4], marks=3, diff="hard",
            expl="For $(5, 0, -1) = 3v_1 + v_2$, the vectors are dependent. For $(2, 3, 1)$, determinant is non-zero, spanning $\\mathbb{R}^3$ (dimension 3) with invertible matrix."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Feb_2024_-_QDD4_part2.json", "Mathematics 2 · Quiz 1 · Feb 2024 · QDD4 · Part 2", "quiz1", p2_qs)


def build_booklet_3():
    # Feb 2025 QIP4 (17 Qs: Q2 to Q18 -> Part 1 = 9 Qs, Part 2 = 8 Qs)
    p1_qs = [
        mcq_single(
            "Let $v_1, v_2, v_3$ be linearly independent vectors in $\\mathbb{R}^3$. Let $A \\in M_{3\\times 3}(\\mathbb{R})$ be a matrix such that $v_1 - v_2, v_2 - v_3, v_1 + v_3$ are the columns of $A$. Let $B \\in M_{3\\times 3}(\\mathbb{R})$ be a matrix such that $v_1 + v_2 + v_3, 2v_1 + 3v_2, 2v_3 - v_2$ are the columns of $B$. Which of the following options is correct?",
            [
                "The $\\text{rank}(A)$ is 2.",
                "$A$ is an invertible matrix.",
                "$\\text{rank}(A) = \\text{rank}(B)$.",
                "The system of linear equations $Bx = 0$ has a unique solution."
            ],
            1, marks=6, diff="hard",
            expl="Representing the columns of $A$ relative to the basis $\\{v_1, v_2, v_3\\}$ yields the coefficient matrix with determinant $\\det \\begin{pmatrix} 1 & 0 & 1 \\\\ -1 & 1 & 0 \\\\ 0 & -1 & 1 \\end{pmatrix} = 1(1) + 1(1) = 2 \\neq 0$. Thus $A$ has rank 3 and is invertible."
        ),
        mcq_multi(
            "Let $A$ be an $m \\times n$ matrix. Choose the operations that are valid only when $m = n$:",
            ["$A + A^T$", "$A^2$", "$\\det(A)$", "$cA$, where $c$ is a real number"],
            [1, 2], marks=4, diff="easy",
            expl="Matrix squaring $A^2 = AA$ requires $n = m$, and the determinant $\\det(A)$ is defined only for square matrices ($m = n$)."
        ),
        numerical(
            "Find the number of $2 \\times 2$ scalar matrices with determinant equal to 4.",
            2, marks=2, diff="medium",
            expl="A scalar matrix is of the form $cI_2 = \\begin{pmatrix} c & 0 \\\\ 0 & c \\end{pmatrix}$. Its determinant is $c^2 = 4 \\implies c = \\pm 2$, yielding exactly 2 scalar matrices."
        ),
        mcq_single(
            "Consider the system of linear equations $Ax = b$, where:\n$$A = \\begin{bmatrix} 2 & 6 \\\\ k^2 & 12 \\end{bmatrix}, \\quad x = \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix}, \\quad b = \\begin{bmatrix} k \\\\ 4 \\end{bmatrix}$$\nfor some $k \\in \\mathbb{R}$. Which of the following conditions is equivalent to having NO solutions for the system?",
            ["$k^2 \\neq 4$", "$k = 2$", "$k = -2$"],
            2, marks=2, diff="medium",
            expl="$\\det(A) = 24 - 6k^2 = 0 \\implies k = \\pm 2$. For $k = 2$, the equations are proportional ($2x_1 + 6x_2 = 2$ and $4x_1 + 12x_2 = 4$), giving infinitely many solutions. For $k = -2$, $2x_1 + 6x_2 = -2$ and $4x_1 + 12x_2 = 4$ are contradictory, giving no solution."
        ),
        mcq_single(
            "Consider the system of linear equations $Ax = b$, where:\n$$A = \\begin{bmatrix} 2 & 6 \\\\ k^2 & 12 \\end{bmatrix}, \\quad x = \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix}, \\quad b = \\begin{bmatrix} k \\\\ 4 \\end{bmatrix}$$\nfor some $k \\in \\mathbb{R}$. Which of the following conditions is equivalent to having a UNIQUE solution for the system?",
            ["$k^2 \\neq 4$", "$k = 2$", "$k = -2$"],
            0, marks=2, diff="medium",
            expl="A square system $Ax = b$ has a unique solution if and only if $\\det(A) \\neq 0$, which requires $24 - 6k^2 \\neq 0 \\iff k^2 \\neq 4$."
        ),
        numerical(
            "Let $A \\in M_{3\\times 4}(\\mathbb{R})$ be a matrix with row vectors $v_1, v_2$, and $v_3$. Suppose $v_1$ and $v_2$ are two linearly independent rows of $A$ and $v_1 + v_2 + v_3 = 0$. Find the row rank of $A$.",
            2, marks=2, diff="medium",
            expl="Since $v_3 = -(v_1 + v_2)$, row 3 is linearly dependent on rows 1 and 2. Since $v_1$ and $v_2$ are linearly independent, the row rank is 2."
        ),
        numerical(
            "Let $A \\in M_{3\\times 4}(\\mathbb{R})$ be a matrix with row vectors $v_1, v_2$, and $v_3$. Suppose $v_1$ and $v_2$ are two linearly independent rows of $A$ and $v_1 + v_2 + v_3 = 0$. Find the number of dependent (pivot) variables for the system $Ax = 0$.",
            2, marks=2, diff="medium",
            expl="The number of dependent variables equals the rank of $A$, which is 2."
        ),
        mcq_single(
            "Consider the system of equations $Ax = b$ for which the coefficient matrix is:\n$$A = \\begin{bmatrix} 1 & 0 & 3 \\\\ -2 & 4 & 0 \\end{bmatrix}$$\nStatement: There is a vector $b \\in \\mathbb{R}^2$ such that the system $Ax = b$ has a unique solution.",
            ["True", "False"],
            1, marks=2, diff="medium",
            expl="$A$ has 2 rows and 3 columns. Because there are more variables than equations ($n = 3 > m = 2$), any consistent system has at least $3 - 2 = 1$ free variable, so a unique solution is impossible."
        ),
        numerical(
            "Consider the system of linear equations $Ax = b$ where:\n$$A = \\begin{bmatrix} 1 & 0 & 3 \\\\ -2 & 4 & 0 \\end{bmatrix}, \\quad b = \\begin{bmatrix} 1 \\\\ -2 \\end{bmatrix}$$\nIf $(\\alpha, \\beta, 2)$ is a solution to this system, find the value of $\\alpha$.",
            -5, marks=2, diff="medium",
            expl="From the first equation: $\\alpha + 0(\\beta) + 3(2) = 1 \\implies \\alpha + 6 = 1 \\implies \\alpha = -5$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Feb_2025_-_QIP4_part1.json", "Mathematics 2 · Quiz 1 · Feb 2025 · QIP4 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Consider the system of linear equations $Ax = b$ where:\n$$A = \\begin{bmatrix} 1 & 0 & 3 \\\\ -2 & 4 & 0 \\end{bmatrix}, \\quad b = \\begin{bmatrix} 1 \\\\ -2 \\end{bmatrix}$$\nIf $(\\alpha, \\beta, 2)$ is a solution to this system with $\\alpha = -5$, find the value of $\\beta$.",
            -3, marks=2, diff="medium",
            expl="From the second equation: $-2\\alpha + 4\\beta + 0(2) = -2 \\implies -2(-5) + 4\\beta = -2 \\implies 10 + 4\\beta = -2 \\implies 4\\beta = -12 \\implies \\beta = -3$."
        ),
        mcq_single(
            "Consider the subspace $W_1 = \\left\\{ \\begin{bmatrix} a & b \\\\ c & d \\end{bmatrix} \\in M_{2\\times 2}(\\mathbb{R}) : a + d = 0 \\right\\}$ of trace-zero $2 \\times 2$ matrices. Consider the matrices:\n$$B_1 = \\begin{bmatrix} 1 & 0 \\\\ 0 & 0 \\end{bmatrix}, B_2 = \\begin{bmatrix} 1 & 0 \\\\ 0 & -1 \\end{bmatrix}, B_3 = \\begin{bmatrix} 0 & 1 \\\\ 0 & 0 \\end{bmatrix}, B_4 = \\begin{bmatrix} 0 & 0 \\\\ 1 & 0 \\end{bmatrix}, B_5 = \\begin{bmatrix} 0 & 0 \\\\ 1 & 0 \\end{bmatrix}$$\nChoose the correct set of matrices that forms a basis for $W_1$:",
            [
                "$\\{B_1, B_2, B_3, B_4\\}$",
                "$\\{B_1, B_2, B_3\\}$",
                "$\\{B_2, B_3, B_5\\}$",
                "$\\{B_1, B_2, B_3, B_5\\}$"
            ],
            2, marks=2, diff="hard",
            expl="Trace-zero $2 \\times 2$ matrices form a 3-dimensional subspace. $B_2 = \\begin{bmatrix} 1 & 0 \\\\ 0 & -1 \\end{bmatrix}$, $B_3 = \\begin{bmatrix} 0 & 1 \\\\ 0 & 0 \\end{bmatrix}$, and $B_5 = \\begin{bmatrix} 0 & 0 \\\\ 1 & 0 \\end{bmatrix}$ each have trace 0 and are linearly independent, forming a basis."
        ),
        mcq_multi(
            "Consider the subspace $W_2 = \\left\\{ \\begin{bmatrix} a & b \\\\ c & d \\end{bmatrix} \\in M_{2\\times 2}(\\mathbb{R}) : a + b = 0, c + d = 0 \\right\\}$. Which of the following sets of matrices span $W_2$?",
            [
                "$\\{B_1, B_2, B_3, B_4\\}$",
                "$\\{B_5, B_6, B_7\\}$",
                "$\\{B_6, B_7\\}$",
                "$\\{B_2, B_3, B_5\\}$"
            ],
            [0, 1, 2], marks=4, diff="hard",
            expl="$\\dim(W_2) = 2$, and any set that contains a basis for $W_2$ spans $W_2$."
        ),
        mcq_multi(
            "Suppose $W_1$ and $W_2$ are subspaces of $\\mathbb{R}^3$ defined by:\n$$W_1 = \\{(0, y, z) : y, z \\in \\mathbb{R}\\}, \\quad W_2 = \\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 0\\}$$\nWhich of the following options represents $W_1 \\cap W_2$?",
            [
                "$\\{\\alpha(0, 1, -1) + \\beta(0, -1, 1) : \\alpha, \\beta \\in \\mathbb{R}\\}$",
                "$\\text{Span}\\{(0, 1, -1), (0, -1, -1)\\}$",
                "$\\text{Span}\\{(0, 1, -1)\\}$",
                "$\\{\\alpha(2, -1, -1) + \\beta(0, 1, 1) : \\alpha, \\beta \\in \\mathbb{R}\\}$"
            ],
            [0, 2], marks=4, diff="hard",
            expl="Vectors in $W_1 \\cap W_2$ satisfy $x = 0$ and $0 + y + z = 0 \\implies z = -y$. Thus $W_1 \\cap W_2 = \\{(0, y, -y)\\} = \\text{Span}\\{(0, 1, -1)\\}$. Option A also spans this same 1D line."
        ),
        numerical(
            "Suppose $W_1$ and $W_2$ are subspaces of $\\mathbb{R}^3$ defined by $W_1 = \\{(0, y, z) : y, z \\in \\mathbb{R}\\}$ and $W_2 = \\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 0\\}$. What is the dimension of $W_1 \\cap W_2$?",
            1, marks=2, diff="medium",
            expl="$W_1 \\cap W_2 = \\text{Span}\\{(0, 1, -1)\\}$, which is 1-dimensional."
        ),
        mcq_single(
            "Suppose $W_1 = \\{(0, y, z) : y, z \\in \\mathbb{R}\\}$ and $W_2 = \\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 0\\}$ are subspaces of $\\mathbb{R}^3$. Which of the following options is true regarding $W_1 \\cup W_2$?",
            [
                "$W_1 \\cup W_2$ is a subspace of dimension 3.",
                "$W_1 \\cup W_2$ is a subspace of dimension 2.",
                "$W_1 \\cup W_2$ is a subspace of dimension 1.",
                "$W_1 \\cup W_2$ is not a subspace."
            ],
            3, marks=2, diff="medium",
            expl="The union of two subspaces is a subspace if and only if one is contained in the other. Neither $W_1 \\subseteq W_2$ nor $W_2 \\subseteq W_1$, so $W_1 \\cup W_2$ is not a subspace."
        ),
        mcq_multi(
            "Consider the matrices:\n$$A = \\begin{bmatrix} 1 & 0 & 1 \\\\ 0 & 1 & 0 \\\\ 1 & 0 & \\alpha \\end{bmatrix}, \\quad B = \\begin{bmatrix} \\beta - 2 & 0 & 1 \\\\ 0 & 1 & 0 \\\\ 6 & 6 & \\beta - 1 \\end{bmatrix}$$\nwhere $\\alpha, \\beta \\in \\mathbb{R}$. Which of the following conditions are sufficient to deduce that $\\det(AB) = 0$?",
            ["$\\alpha = 1$", "$\\alpha = 2$", "$\\beta = 4$", "$\\beta = 1$"],
            [0, 2], marks=6, diff="hard",
            expl="$\\det(AB) = \\det(A) \\det(B)$. Expanding $\\det(A) = \\alpha - 1$, so $\\alpha = 1 \\implies \\det(A) = 0$. Expanding $\\det(B) = (\\beta - 2)(\\beta - 1) - 6 = \\beta^2 - 3\\beta - 4 = (\\beta - 4)(\\beta + 1)$, so $\\beta = 4 \\implies \\det(B) = 0$."
        ),
        numerical(
            "Consider the matrices $A = \\begin{bmatrix} 1 & 0 & 1 \\\\ 0 & 1 & 0 \\\\ 1 & 0 & \\alpha \\end{bmatrix}$ and $B = \\begin{bmatrix} \\beta - 2 & 0 & 1 \\\\ 0 & 1 & 0 \\\\ 6 & 6 & \\beta - 1 \\end{bmatrix}$. For $\\alpha = 3$ and $\\beta = 0$, find the value of $\\det(-B^T A^2 B^{-1})$.",
            -4, marks=4, diff="hard",
            expl="$\\det(-B^T A^2 B^{-1}) = (-1)^3 \\det(B^T) (\\det A)^2 \\frac{1}{\\det B} = -(\\det A)^2$. For $\\alpha = 3$, $\\det(A) = 3 - 1 = 2$, so $-(\\det A)^2 = -(2^2) = -4$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Feb_2025_-_QIP4_part2.json", "Mathematics 2 · Quiz 1 · Feb 2025 · QIP4 · Part 2", "quiz1", p2_qs)


def build_booklet_4():
    # Jul 2023 AN4 Exam 2 (14 Qs: Q2 to Q15 -> Part 1 = 7 Qs, Part 2 = 7 Qs)
    p1_qs = [
        mcq_single(
            [
                t_block("Match the system of linear equations in Column A with their number of solutions in Column B and their geometric representation in Column C.\n\n**Column A:**\ni) $x - 2y - z = 8, \\; -x + 2y + z = 4$\nii) $x + y - z = 3, \\; x - y + z = 3$\n\n**Column B:**\na) No solution\nb) Infinitely many solutions\n\n**Column C (see diagrams):**"),
                img_block("/assets/exam-examples/question-crops/mathematics-2/quiz1/jul2023_q2_column_c.png", "Geometric representations of planes in Column C"),
                t_block("Choose the correct matching option:")
            ],
            [
                "i) $\\to$ b $\\to$ 1, ii) $\\to$ a $\\to$ 2",
                "i) $\\to$ a $\\to$ 1, ii) $\\to$ b $\\to$ 2",
                "i) $\\to$ b $\\to$ 2, ii) $\\to$ a $\\to$ 1",
                "i) $\\to$ a $\\to$ 2, ii) $\\to$ b $\\to$ 1"
            ],
            3, marks=2, diff="medium",
            expl="System (i) has parallel planes with different constants, giving no solution (a) and parallel planes diagram 2. System (ii) has intersecting planes intersecting in a line, giving infinitely many solutions (b) and intersecting planes diagram 1. Thus i $\\to$ a $\\to$ 2, ii $\\to$ b $\\to$ 1."
        ),
        mcq_multi(
            "Which of the following matrices satisfy $A^k = 0$ for some natural number $k$ (i.e. which are nilpotent matrices)?",
            [
                "$\\begin{pmatrix} 4 & 4 & -4 \\\\ -4 & -4 & 4 \\\\ 0 & 0 & 0 \\end{pmatrix}$",
                "$\\begin{pmatrix} 0 & 2 & 3 \\\\ 0 & 0 & 2 \\\\ 0 & 0 & 0 \\end{pmatrix}$",
                "$\\begin{pmatrix} 1 & 1 & 1 \\\\ 1 & 1 & 1 \\\\ 1 & 1 & 1 \\end{pmatrix}$",
                "$\\begin{pmatrix} 1 & 0 & 0 \\\\ 0 & 1 & 0 \\\\ 0 & 0 & 1 \\end{pmatrix}$"
            ],
            [0, 1], marks=2, diff="hard",
            expl="The strictly upper triangular matrix is clearly nilpotent ($A^3 = 0$). Matrix A has square $A^2 = 0$. Matrix C has $C^2 = 3C \\neq 0$, and matrix D is the identity matrix."
        ),
        mcq_multi(
            "Which of the following subsets of $\\mathbb{R}^2$ is/are vector spaces with respect to usual addition and usual scalar multiplication?",
            [
                "$V_1 = \\{(x, y) \\in \\mathbb{R}^2 : 2x + 3y = 0\\}$",
                "$V_2 = \\{(x, y) \\in \\mathbb{R}^2 : y^2 = 0, x = 2y\\}$",
                "$V_3 = \\{(x, y) \\in \\mathbb{R}^2 : x = 1\\}$",
                "$V_4 = \\{(x, y) \\in \\mathbb{R}^2 : 2x + 3y - 1 = 0, x - y = 0\\}$"
            ],
            [0, 1], marks=2, diff="medium",
            expl="$V_1$ is a line through the origin. In $V_2$, $y^2 = 0 \\implies y = 0$, so $x = 2(0) = 0$, meaning $V_2 = \\{(0, 0)\\}$, the trivial zero subspace. $V_3$ and $V_4$ do not contain $(0, 0)$."
        ),
        mcq_multi(
            "Select the true statement(s) regarding linear independence and vector spaces:",
            [
                "Any subset of a linearly independent set is a linearly independent set.",
                "Any superset of a spanning set is a spanning set.",
                "Any subset of a basis is a basis.",
                "Any superset of a subspace is a subspace."
            ],
            [0, 1], marks=2, diff="medium",
            expl="Subsets of linearly independent sets are always linearly independent. Adding vectors to a spanning set retains the spanning property. Subsets of a basis generally do not span the space, and arbitrary supersets of subspaces are not subspaces."
        ),
        mcq_multi(
            "Consider the set $W = \\{A \\in M_n(\\mathbb{R}) : \\det(A^T) = 0\\}$ with the usual addition and scalar multiplication of matrices. Which of the following statements is/are true?",
            [
                "$W$ is closed under addition.",
                "$W$ is closed under scalar multiplication.",
                "$W$ is a vector space.",
                "$W$ is not a vector space."
            ],
            [1, 3], marks=2, diff="hard",
            expl="$W$ is the set of all singular $n \\times n$ matrices. For any $c \\in \\mathbb{R}$ and $A \\in W$, $\\det((cA)^T) = c^n \\det(A^T) = 0$, so $W$ is closed under scalar multiplication. However, the sum of two singular matrices need not be singular (e.g. $\\text{diag}(1, 0) + \\text{diag}(0, 1) = I$), so $W$ is not closed under addition and not a vector space."
        ),
        numerical(
            "Let $A = \\begin{pmatrix} 2022 & 2023 & 2024 \\\\ 2022 & 2021 & 2022 \\\\ 2022 & 2022 & 2022 \\end{pmatrix}$. What is the determinant of $\\frac{1}{2}A$?",
            505.5, marks=2, diff="medium",
            expl="Row operations $R_1 \\leftarrow R_1 - R_3$ and $R_2 \\leftarrow R_2 - R_3$ yield $\\det(A) = 4044$. Then $\\det(\\frac{1}{2}A) = (\\frac{1}{2})^3 \\det(A) = \\frac{4044}{8} = 505.5$."
        ),
        numerical(
            "Consider the system of linear equations represented in the matrix form $Ax = b$, where:\n$$A = \\begin{pmatrix} 1 & 1 & 3 \\\\ 1 & 2 & 4 \\\\ 1 & 3 & \\alpha \\end{pmatrix}, \\quad b = \\begin{pmatrix} 2 \\\\ 3 \\\\ \\beta \\end{pmatrix}$$\nWhat is the value of $\\alpha + \\beta$ if the above system has infinitely many solutions?",
            9, marks=3, diff="hard",
            expl="Infinitely many solutions requires row 3 to be a linear combination of rows 1 and 2: $R_3 = 2R_2 - R_1$. Comparing elements gives $\\alpha = 2(4) - 3 = 5$ and $\\beta = 2(3) - 2 = 4$. Therefore $\\alpha + \\beta = 5 + 4 = 9$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2023_-_Foundation_AN4_Exam_2_part1.json", "Mathematics 2 · Quiz 1 · Jul 2023 · Foundation AN4 Exam 2 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "What is the dimension of the vector space $V_1 = \\{(x, y, z) \\in \\mathbb{R}^3 : 2x + 3y = 0 = 2z + 3x\\}$ with usual addition and scalar multiplication?",
            1, marks=1, diff="medium",
            expl="Two linearly independent linear constraints on $\\mathbb{R}^3$ define a line passing through the origin, so $\\dim(V_1) = 3 - 2 = 1$."
        ),
        numerical(
            "What is the dimension of the vector space $V_2 = \\{A \\in M_3(\\mathbb{R}) : \\text{tr}(A) = 0 \\text{ and the sum of entries in each row is } 0\\}$ with usual matrix addition and scalar multiplication?",
            5, marks=2, diff="hard",
            expl="$M_3(\\mathbb{R})$ has dimension 9. The three row sum constraints are independent (3 constraints). The trace-zero condition is an additional independent constraint, so $\\dim(V_2) = 9 - 4 = 5$."
        ),
        mcq_single(
            "Shivani bought 2 shirts, a T-shirt and 2 pants for Rs. 600. Sruthi bought a T-shirt and a pant for Rs. 400. Smriti bought 2 shirts and a pant for Rs. 300. Let $x_1, x_2, x_3$ denote the price of a shirt, a T-shirt and a pant respectively. Choose the correct matrix representation $Ax = b$ for this system:",
            [
                "$A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 1 & 1 & 0 \\\\ 2 & 0 & 1 \\end{pmatrix}, b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$",
                "$A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}, b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$",
                "$A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 0 & 2 & 1 \\end{pmatrix}, b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$",
                "$A = \\begin{pmatrix} 1 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}, b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$"
            ],
            1, marks=1, diff="medium",
            expl="Shivani: $2x_1 + x_2 + 2x_3 = 600$; Sruthi: $0x_1 + x_2 + x_3 = 400$; Smriti: $2x_1 + 0x_2 + x_3 = 300$. Matrix $A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}$ and $b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$."
        ),
        numerical(
            "Consider the system of linear equations $Ax = b$ from the previous shopping problem where:\n$$A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}, \\quad b = \\begin{pmatrix} 600 \\\\ 400 \\\\ 300 \\end{pmatrix}$$\nHow many solutions does the system $Ax = b$ have?",
            0, marks=2, diff="medium",
            expl="Notice $R_1 - R_2 = (2, 0, 1) = R_3$. However, $b_1 - b_2 = 600 - 400 = 200 \\neq 300 = b_3$. The system is inconsistent and has 0 solutions."
        ),
        numerical(
            "Consider the set $S$ of solutions of the homogeneous system $Ax = 0$, where $A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}$. What is the dimension of the solution space $S$?",
            1, marks=1, diff="medium",
            expl="$\\text{rank}(A) = 2$. By the Rank-Nullity theorem, $\\dim(S) = 3 - \\text{rank}(A) = 3 - 2 = 1$."
        ),
        mcq_single(
            "Which of the following forms a basis for $S$, the solution space of $Ax = 0$, where $A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}$?",
            [
                "$\\{(-1/2, 1, -1), (0, 1, -1)\\}$",
                "$\\{(-1/2, 1, -1)\\}$",
                "$\\{(-1/2, 1, 1), (0, 1, -1)\\}$",
                "$\\{(-1/2, 1, 1)\\}$"
            ],
            1, marks=2, diff="medium",
            expl="Solving $Ax = 0$: $x_2 + x_3 = 0 \\implies x_2 = -x_3$. $2x_1 + (-x_3) + 2x_3 = 0 \\implies 2x_1 = -x_3 \\implies x_1 = -x_3/2$. Setting $x_3 = -1$ yields $(-1/2, 1, -1)$, which forms a basis."
        ),
        numerical(
            "What is the rank of the matrix $A = \\begin{pmatrix} 2 & 1 & 2 \\\\ 0 & 1 & 1 \\\\ 2 & 0 & 1 \\end{pmatrix}$?",
            2, marks=1, diff="easy",
            expl="Row 3 equals Row 1 minus Row 2, leaving 2 linearly independent rows. Thus $\\text{rank}(A) = 2$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2023_-_Foundation_AN4_Exam_2_part2.json", "Mathematics 2 · Quiz 1 · Jul 2023 · Foundation AN4 Exam 2 · Part 2", "quiz1", p2_qs)

if __name__ == "__main__":
    build_booklet_1()
    build_booklet_2()
    build_booklet_3()
    build_booklet_4()
