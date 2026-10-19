#!/usr/bin/env python3
"""
Builder for Booklets 9 to 11 of Mathematics 2 Quiz 1:
- Oct 2023 Diploma QPD4 (Part 1 & 2)
- Oct 2024 QDD2 (Part 1 & 2)
- Oct 2025 QIO2 (Part 1 & 2)
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


def build_booklet_9():
    # Oct 2023 Diploma QPD4 (16 Qs: Q2 to Q17 -> Part 1 = 8 Qs, Part 2 = 8 Qs)
    p1_qs = [
        numerical(
            "Consider the system of linear equations:\n$$x + ky = 2$$\n$$kx + y = 2$$\nFind the value of $k$ for which the system of equations has NO solution.",
            -1, marks=1, diff="medium",
            expl="The determinant of the coefficient matrix is $1 - k^2 = 0 \\implies k = \\pm 1$. For $k = -1$, the equations become $x - y = 2$ and $-x + y = 2 \\implies x - y = -2$, which are inconsistent. Thus $k = -1$."
        ),
        numerical(
            "Consider the system of linear equations:\n$$x + ky = 2$$\n$$kx + y = 2$$\nFind the value of $k$ for which the system of equations has INFINITELY MANY solutions.",
            1, marks=1, diff="medium",
            expl="For $k = 1$, both equations become $x + y = 2$, which gives a line of infinitely many solutions. Thus $k = 1$."
        ),
        numerical(
            "Consider the system of linear equations $x + ky = 2$ and $kx + y = 2$. If the system has a unique solution $(a, b)$, what is $a - b$?",
            0, marks=2, diff="medium",
            expl="By symmetry of the equations $x + ky = 2$ and $kx + y = 2$, subtracting yields $(1-k)x - (1-k)y = 0 \\implies (1-k)(a - b) = 0$. Since $k \\neq \\pm 1$ for a unique solution, $a - b = 0$."
        ),
        mcq_multi(
            "Let $W_1 = \\{(x, y, z) \\in \\mathbb{R}^3 : 2x - y + z = 0\\}$, $W_2 = \\{(x, y, z) \\in \\mathbb{R}^3 : 2x - y + z = 0, \\; 2x + y - 3z = 0\\}$, and $W_3$ be the xy-plane $\\{(x, y, 0) : x, y \\in \\mathbb{R}\\}$. Choose the correct option(s):",
            [
                "The set $\\{(1, 0, -2), (0, 1, 1)\\}$ forms a basis for $W_1$.",
                "$W_2$ is the set of all solutions of $AX = 0$ where $A = \\begin{pmatrix} 2 & 2 \\\\ -1 & 1 \\\\ 1 & -3 \\end{pmatrix}$.",
                "The intersection of $W_1$ and $W_3$ is the line $y = 2x$ in the xy-plane.",
                "The intersection of $W_1$ and $W_3$ is spanned by the vector $(2, 1, 0)$.",
                "$W_2$ is the straight line in $\\mathbb{R}^3$ passing through the origin and the vector $(1, 4, 2)$."
            ],
            [0, 2, 4], marks=3, diff="hard",
            expl="For $W_1$, $z = y - 2x$, so $(1, 0, -2)$ and $(0, 1, 1)$ form a basis. In $W_3$, $z = 0 \\implies 2x - y = 0 \\iff y = 2x$. Solving $W_2$ gives direction vector $(1, 4, 2)$."
        ),
        numerical(
            "Let $W_1 = \\{(x, y, z) \\in \\mathbb{R}^3 : 2x - y + z = 0\\}$, $W_2 = \\{(x, y, z) \\in \\mathbb{R}^3 : 2x - y + z = 0, \\; 2x + y - 3z = 0\\}$, and $W_3$ be the xy-plane. Find $\\dim(W_1 + W_2)$.",
            2, marks=1, diff="medium",
            expl="Since $W_2 \\subseteq W_1$ by definition, $W_1 + W_2 = W_1$. Since $W_1$ is a plane in $\\mathbb{R}^3$, $\\dim(W_1) = 2$."
        ),
        mcq_multi(
            [
                t_block("Consider the following images representing systems of linear equations:"),
                img_block("/assets/exam-examples/question-crops/mathematics-2/quiz1/oct2023_q7_systems.png", "Geometric systems of linear equations (a), (b), (c), (d)"),
                t_block("Choose the correct option(s) from the following statements:")
            ],
            [
                "The figures (a) and (d) represent systems with unique solution.",
                "The figures (b) and (c) represent systems with no solution.",
                "The figures (b) and (d) represent systems with infinitely many solutions.",
                "The figures (a) and (d) represent consistent systems of linear equations."
            ],
            [1, 3], marks=2, diff="medium",
            expl="In (b) the three planes form a triangular prism with no common line/point (no solution). In (c) two parallel lines have no intersection (no solution). In (a) three planes meet, and in (d) two intersecting lines meet in a point, representing consistent systems."
        ),
        numerical(
            "Let $A$ be a $3 \\times 3$ matrix such that $A^T = -A$. Then $\\det(A) =$",
            0, marks=1, diff="easy",
            expl="$\\det(A) = \\det(A^T) = \\det(-A) = (-1)^3 \\det(A) = -\\det(A) \\implies 2\\det(A) = 0 \\implies \\det(A) = 0$."
        ),
        numerical(
            "Let $A$ be a $3 \\times 3$ matrix such that $\\det(A) = 2$. If $B$ is a matrix obtained from $A$ by swapping the second and third row, and then multiplying the first row by $-3$, then $\\det(B) =$",
            6, marks=1, diff="medium",
            expl="Swapping two rows multiplies the determinant by $-1$. Scaling one row by $-3$ multiplies the determinant by $-3$. Thus $\\det(B) = 2 \\times (-1) \\times (-3) = 6$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2023_-_Diploma_QPD4_part1.json", "Mathematics 2 · Quiz 1 · Oct 2023 · Diploma QPD4 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Let $A = \\begin{pmatrix} 1 & -2 \\\\ -3 & 4 \\end{pmatrix}$ and $\\det(A - xI) = x^2 - ax + b$. Find the value of $a - b$.",
            7, marks=1, diff="medium",
            expl="The characteristic polynomial is $\\det(A - xI) = (1-x)(4-x) - 6 = x^2 - 5x + 4 - 6 = x^2 - 5x - 2$. Thus $a = 5, b = -2$, and $a - b = 5 - (-2) = 7$."
        ),
        numerical(
            "Let $W = \\{A \\in M_{2\\times 2}(\\mathbb{R}) : A = -A^T\\}$. Let $A \\in W$ be a non-zero matrix. Then what is the rank of $A$?",
            2, marks=1, diff="medium",
            expl="Any non-zero $2 \\times 2$ skew-symmetric matrix has the form $\\begin{pmatrix} 0 & k \\\\ -k & 0 \\end{pmatrix}$ with $k \\neq 0$. Its determinant is $k^2 > 0$, so it is invertible and has rank 2."
        ),
        numerical(
            "Let $W = \\{A \\in M_{2\\times 2}(\\mathbb{R}) : A = -A^T\\}$. What is the dimension of the vector space $W$?",
            1, marks=1, diff="easy",
            expl="A $2 \\times 2$ skew-symmetric matrix is determined by a single entry $k$ in $\\begin{pmatrix} 0 & k \\\\ -k & 0 \\end{pmatrix}$, so $\\dim(W) = 1$."
        ),
        mcq_single(
            "Let $W = \\{A \\in M_{2\\times 2}(\\mathbb{R}) : A = -A^T\\}$. Which of the following sets forms a basis for $W$?",
            [
                "$S = \\left\\{ \\begin{pmatrix} 1 & 0 \\\\ 0 & 0 \\end{pmatrix}, \\begin{pmatrix} 0 & 0 \\\\ 0 & 1 \\end{pmatrix}, \\begin{pmatrix} 0 & 1 \\\\ -1 & 0 \\end{pmatrix} \\right\\}$",
                "$S = \\left\\{ \\begin{pmatrix} 0 & 1 \\\\ 0 & 0 \\end{pmatrix}, \\begin{pmatrix} 0 & 0 \\\\ -1 & 0 \\end{pmatrix} \\right\\}$",
                "$S = \\left\\{ \\begin{pmatrix} 0 & 1 \\\\ -1 & 0 \\end{pmatrix} \\right\\}$",
                "$S = \\left\\{ \\begin{pmatrix} 0 & 1 \\\\ 0 & 0 \\end{pmatrix}, \\begin{pmatrix} 0 & 0 \\\\ 1 & 0 \\end{pmatrix} \\right\\}$"
            ],
            2, marks=1, diff="medium",
            expl="$\\dim(W) = 1$, and $\\begin{pmatrix} 0 & 1 \\\\ -1 & 0 \\end{pmatrix}$ spans $W$."
        ),
        numerical(
            "Let $A = \\begin{pmatrix} 1 & 2 & -1 \\\\ -1 & 1 & 0 \\\\ 0 & 1 & -1 \\end{pmatrix}$ and $B = \\begin{pmatrix} -6 & 3 & 4 \\\\ 7 & 2 & -1 \\\\ 2 & 4 & 2 \\end{pmatrix}$. What is the rank of $A$?",
            3, marks=1, diff="medium",
            expl="$\\det(A) = 1(-1) - 2(1) - 1(-1) = -1 - 2 + 1 = -2 \\neq 0$. Since $\\det(A) \\neq 0$, $A$ has full rank 3."
        ),
        numerical(
            "Let $A = \\begin{pmatrix} 1 & 2 & -1 \\\\ -1 & 1 & 0 \\\\ 0 & 1 & -1 \\end{pmatrix}$ and $B = \\begin{pmatrix} -6 & 3 & 4 \\\\ 7 & 2 & -1 \\\\ 2 & 4 & 2 \\end{pmatrix}$. What is the determinant of $B$?",
            0, marks=1, diff="medium",
            expl="Expanding along row 1: $-6(4 - (-4)) - 3(14 - (-2)) + 4(28 - 4) = -6(8) - 3(16) + 4(24) = -48 - 48 + 96 = 0$."
        ),
        mcq_multi(
            "Let $A = \\begin{pmatrix} 1 & 2 & -1 \\\\ -1 & 1 & 0 \\\\ 0 & 1 & -1 \\end{pmatrix}$ and $B = \\begin{pmatrix} -6 & 3 & 4 \\\\ 7 & 2 & -1 \\\\ 2 & 4 & 2 \\end{pmatrix}$. Let $v_1, v_2, v_3$ be the column vectors of $A$ and $u_1, u_2, u_3$ be the column vectors of $B$. Choose the correct option(s):",
            [
                "The vectors $v_1, v_2$ and $v_3$ lie on a plane.",
                "The vectors $u_1, u_2$ and $u_3$ lie on a plane.",
                "The vectors $u_1, u_2$ and $u_3$ are linearly independent.",
                "The system $Ax = 0$ has a unique solution.",
                "The system $Bx = 0$ has no solution.",
                "The vector $u_3$ is a linear combination of $u_1$ and $u_2$."
            ],
            [1, 3, 5], marks=3, diff="hard",
            expl="$\\det(A) = -2 \\neq 0 \\implies Ax = 0$ has only the unique trivial solution $x = 0$, and $v_1, v_2, v_3$ span $\\mathbb{R}^3$. $\\det(B) = 0 \\implies \\text{rank}(B) < 3$, so $u_1, u_2, u_3$ lie on a plane and $u_3$ is a linear combination of $u_1, u_2$."
        ),
        mcq_multi(
            "Unless otherwise stated, assume usual vector addition and scalar multiplication. Choose the correct option(s) from the following statements:",
            [
                "The set of vectors $\\{(a, b) \\in \\mathbb{R}^2\\}$ with scalar multiplication $k(a, b) = (0, kb)$ forms a vector space.",
                "The set of real numbers with addition $x + y := x - y$ forms a vector space.",
                "Let $A \\in \\mathbb{R}^{3\\times 3}$ be an invertible matrix. The set of all solutions of $AX = 0$ is a vector space of dimension 0.",
                "Any vector subspace of $\\mathbb{R}^2$ with dimension 1 is of the form $ax + by = 0$ where $a \\neq 0$ or $b \\neq 0$.",
                "Any vector subspace of $\\mathbb{R}^2$ with dimension 1 is of the form $ax + by = c$ where $a \\neq 0$ or $b \\neq 0$.",
                "$V = \\left\\{ \\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix} : a + b = c + d \\right\\}$ forms a vector space.",
                "The set of all $n \\times n$ matrices with rank strictly less than $n$ does not form a vector space."
            ],
            [2, 5, 6], marks=4, diff="hard",
            expl="If $A$ is invertible, $AX = 0$ has only $\\{0\\}$, which has dimension 0. $V$ is defined by the homogeneous linear constraint $a+b-c-d = 0$, so it is a vector subspace of $M_{2\\times 2}$. The set of singular matrices is not closed under addition, so it does not form a vector space."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2023_-_Diploma_QPD4_part2.json", "Mathematics 2 · Quiz 1 · Oct 2023 · Diploma QPD4 · Part 2", "quiz1", p2_qs)


def build_booklet_10():
    # Oct 2024 QDD2 (16 Qs: Q2 to Q17 -> Part 1 = 8 Qs, Part 2 = 8 Qs)
    p1_qs = [
        mcq_multi(
            "Choose the correct option(s) from the following statements regarding square matrices:",
            [
                "Let $A, B \\in M_{n\\times n}(\\mathbb{R})$ such that $AB = 0$. Then at least one of the matrices $A$ or $B$ must have determinant 0.",
                "If $A - aI = 0$ where $A \\in M_{n\\times n}(\\mathbb{R})$, $I$ is the identity matrix, $a \\in \\mathbb{R}$ and $n$ is even, then determinant of $A$ is always positive (for $a \\neq 0$).",
                "A matrix with all diagonal entries as zero will always have determinant zero.",
                "For a square matrix $A$, if the system of linear equations $Ax = 0$ has a unique solution, then determinant of $A$ is non-zero."
            ],
            [0, 1, 3], marks=3, diff="medium",
            expl="If $AB = 0$, $\\det(A)\\det(B) = 0$, so at least one has determinant 0. If $A = aI$ for even $n$, $\\det(A) = a^n > 0$. $\\begin{pmatrix} 0 & 1 \\\\ 1 & 0 \\end{pmatrix}$ has zero diagonal but determinant $-1 \\neq 0$."
        ),
        mcq_single(
            "Consider the system of linear equations $Ax = b$. Choose the option which guarantees a unique solution:",
            [
                "$A$ is a square and invertible matrix.",
                "$b$ belongs to the span of the column vectors of $A$.",
                "The columns of $A$ are linearly independent.",
                "The system has no independent variables."
            ],
            0, marks=3, diff="medium",
            expl="If $A$ is square and invertible, then $x = A^{-1}b$ is the unique solution for any vector $b$."
        ),
        mcq_multi(
            "Choose all the correct options from the following:",
            [
                "For a vector space $V$ with dimension $n$, there is always a subspace of dimension $k$ where $1 \\le k < n$.",
                "Let $S$ be a set of $k$ vectors in $\\mathbb{R}^n$. Then $\\text{span}(S)$ has dimension less than or equal to $k$.",
                "Let $S$ be a subset of a vector space $V$ of dimension $n$. Then $S$ can have a maximum of $n$ linearly independent vectors.",
                "A finite non-empty set of vectors from a vector space can never be a subspace."
            ],
            [0, 1, 2], marks=3, diff="hard",
            expl="Subspaces of any intermediate dimension $k$ exist. The span of $k$ vectors has dimension $\\le k$. An $n$-dimensional space cannot contain more than $n$ independent vectors. The trivial set $\\{0\\}$ is a finite subspace."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} -2 & \\alpha \\\\ \\beta & 2 \\end{bmatrix}$ such that $A A^T = \\begin{bmatrix} 8 & 8 \\\\ 8 & 8 \\end{bmatrix}$. Find the value of $\\alpha$.",
            2, marks=1.5, diff="medium",
            expl="$(AA^T)_{11} = (-2)^2 + \\alpha^2 = 8 \\implies 4 + \\alpha^2 = 8 \\implies \\alpha^2 = 4$. With off-diagonal $(AA^T)_{12} = -2\\beta + 2\\alpha = 8$ and $\\beta = -2$, we obtain $\\alpha = 2$."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} -2 & \\alpha \\\\ \\beta & 2 \\end{bmatrix}$ such that $A A^T = \\begin{bmatrix} 8 & 8 \\\\ 8 & 8 \\end{bmatrix}$. Find the value of $\\beta$.",
            -2, marks=1.5, diff="medium",
            expl="$(AA^T)_{22} = \\beta^2 + 2^2 = 8 \\implies \\beta^2 = 4$. With $-2\\beta + 2(2) = 8 \\implies -2\\beta + 4 = 8 \\implies -2\\beta = 4 \\implies \\beta = -2$."
        ),
        numerical(
            "Let $A$ be a $5 \\times 5$ matrix such that $A^T = -A$. Then $\\det(A) =$",
            0, marks=1, diff="easy",
            expl="Skew-symmetric matrices of odd order over $\\mathbb{R}$ have determinant 0."
        ),
        numerical(
            "Let $A$ be a $2 \\times 2$ matrix such that $\\det(A) = 2$. If $B$ is a matrix obtained from $A$ by swapping the first and second row, and then multiplying the second row by $-2$, then $\\det(B) =$",
            4, marks=1, diff="medium",
            expl="Row swap multiplies determinant by $-1$. Multiplying a row by $-2$ scales determinant by $-2$. Thus $\\det(B) = 2 \\times (-1) \\times (-2) = 4$."
        ),
        numerical(
            "Let $Ax = b$ be a system of linear equations, where $A = \\begin{bmatrix} 1 & 0 & 0 & -2 \\\\ 0 & 0 & 1 & 3 \\\\ 0 & 0 & 0 & 1 \\end{bmatrix}$. Find the number of independent (free) variables.",
            1, marks=1, diff="medium",
            expl="$A$ has 4 columns and 3 pivot rows (pivots in columns 1, 3, 4). The number of independent (free) variables is $4 - 3 = 1$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2024_-_QDD2_part1.json", "Mathematics 2 · Quiz 1 · Oct 2024 · QDD2 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Find the dimension of the subspace $W_1 = \\{x \\in \\mathbb{R}^n : Ax = 0 \\text{ where } A \\text{ is an invertible } n \\times n \\text{ matrix}\\}$.",
            0, marks=1, diff="easy",
            expl="If $A$ is invertible, $Ax = 0$ has only the trivial solution $x = 0$. The zero subspace $\\{0\\}$ has dimension 0."
        ),
        numerical(
            "Find the dimension of the subspace $W_2 = \\text{span}\\{(1, -1, 1), (4, 1, 2), (2, 3, 0)\\}$.",
            2, marks=1, diff="medium",
            expl="The vectors satisfy $2(1, -1, 1) + (2, 3, 0) = (4, 1, 2)$. The third vector is a linear combination of the first two, and the first two are independent, so $\\dim(W_2) = 2$."
        ),
        numerical(
            "Find the dimension of the subspace $W_3$, the set of all $2 \\times 2$ symmetric matrices over $\\mathbb{R}$.",
            3, marks=1, diff="easy",
            expl="A symmetric $2 \\times 2$ matrix $\\begin{pmatrix} a & b \\\\ b & c \\end{pmatrix}$ has 3 independent parameters $a, b, c$, so the dimension is 3."
        ),
        mcq_single(
            "Consider the candidate basis sets for subspaces of $M_{2\\times 2}(\\mathbb{R})$:\n$$\\mathcal{B}_1 = \\left\\{ \\begin{bmatrix} 3 & -3 \\\\ 0 & 0 \\end{bmatrix}, \\begin{bmatrix} 0 & 0 \\\\ -5 & 5 \\end{bmatrix} \\right\\}$$\n$$\\mathcal{B}_2 = \\left\\{ \\begin{bmatrix} 0 & 2 \\\\ -2 & 0 \\end{bmatrix} \\right\\}$$\n$$\\mathcal{B}_3 = \\left\\{ \\begin{bmatrix} 1 & 0 \\\\ 0 & -1 \\end{bmatrix}, \\begin{bmatrix} 0 & -2 \\\\ 0 & 0 \\end{bmatrix}, \\begin{bmatrix} 0 & 0 \\\\ 3 & 0 \\end{bmatrix} \\right\\}$$\nLet $W_1 = \\{A \\in M_{2\\times 2}(\\mathbb{R}) : A^T = -A\\}$. Choose the correct basis for $W_1$:",
            ["$\\mathcal{B}_1$", "$\\mathcal{B}_2$", "$\\mathcal{B}_3$"],
            1, marks=1, diff="medium",
            expl="Skew-symmetric $2 \\times 2$ matrices have the form $\\begin{bmatrix} 0 & k \\\\ -k & 0 \\end{bmatrix}$. $\\mathcal{B}_2$ spans this 1-dimensional subspace."
        ),
        mcq_single(
            "Consider the same candidate basis sets $\\mathcal{B}_1, \\mathcal{B}_2, \\mathcal{B}_3$. Let $W_2$ be the set of all $2 \\times 2$ matrices such that the sum of entries in each row is zero. Choose the correct basis for $W_2$:",
            ["$\\mathcal{B}_1$", "$\\mathcal{B}_2$", "$\\mathcal{B}_3$"],
            0, marks=1, diff="medium",
            expl="Row-sum-zero matrices are spanned by $\\begin{bmatrix} 1 & -1 \\\\ 0 & 0 \\end{bmatrix}$ and $\\begin{bmatrix} 0 & 0 \\\\ 1 & -1 \\end{bmatrix}$. Scalar multiples of these are given in $\\mathcal{B}_1$."
        ),
        mcq_single(
            "Consider the candidate basis sets $\\mathcal{B}_1, \\mathcal{B}_2, \\mathcal{B}_3$. Let $W_3$ be the set of all $2 \\times 2$ matrices such that the sum of diagonal entries is zero (trace zero). Choose the correct basis for $W_3$:",
            ["$\\mathcal{B}_1$", "$\\mathcal{B}_2$", "$\\mathcal{B}_3$"],
            2, marks=1, diff="medium",
            expl="Trace-zero $2 \\times 2$ matrices form a 3-dimensional subspace spanned by $\\mathcal{B}_3$."
        ),
        numerical(
            "Consider the matrix $A = \\begin{bmatrix} 1 & 0 & 5 \\\\ -2 & 3 & -4 \\\\ 1 & 4 & a \\end{bmatrix}$. Find the value of $a$ if the system $Ax = 0$ has infinitely many solutions.",
            13, marks=2, diff="hard",
            expl="For $Ax = 0$ to have infinitely many solutions, $\\det(A) = 0$. $\\det(A) = 1(3a + 16) + 5(-8 - 3) = 3a + 16 - 55 = 3a - 39 = 0 \\implies a = 13$."
        ),
        numerical(
            "Consider the matrix $A = \\begin{bmatrix} 1 & 2 & -3 \\\\ -2 & 1 & -4 \\\\ 1 & 0 & 1 \\end{bmatrix}$. Consider the system of linear equations $Ax = \\begin{bmatrix} 3 \\\\ b \\\\ 1 \\end{bmatrix}$. Find the value of $b$ if the system has infinitely many solutions.",
            -1, marks=2, diff="hard",
            expl="Notice $R_1 - 2R_3 = (1, 2, -3) - (2, 0, 2) = (-1, 2, -5)$. Also $R_2 + R_1 = (-1, 3, -7)$. Performing row reduction yields the consistency equation $b + 6 = 5 \\implies b = -1$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2024_-_QDD2_part2.json", "Mathematics 2 · Quiz 1 · Oct 2024 · QDD2 · Part 2", "quiz1", p2_qs)


def build_booklet_11():
    # Oct 2025 QIO2 (12 Qs: Q2 to Q13 -> Part 1 = 6 Qs, Part 2 = 6 Qs)
    p1_qs = [
        mcq_single(
            "Consider the system of linear equations with unknowns $x, y$ and $z$ given by:\n$$\\begin{pmatrix} 1 & 2 & 1 \\\\ 3 & 0 & -1 \\\\ 1 & 8 & 5 \\end{pmatrix} \\begin{pmatrix} x \\\\ y \\\\ z \\end{pmatrix} = \\begin{pmatrix} b_1 \\\\ b_2 \\\\ b_3 \\end{pmatrix}$$\nwhere $b_1, b_2, b_3 \\in \\mathbb{R}$. Choose the equation to be satisfied by $b_1, b_2$ and $b_3$ to ensure that the given system of equations has a solution.",
            [
                "$2b_1 + b_2 - b_3 = 0$",
                "$2b_1 - b_2 + b_3 = 0$",
                "$-4b_1 + b_2 - b_3 = 0$",
                "$-4b_1 + b_2 + b_3 = 0$"
            ],
            3, marks=4, diff="medium",
            expl="Notice $-4(1, 2, 1) + (3, 0, -1) + (1, 8, 5) = (-4+3+1, -8+0+8, -4-1+5) = (0, 0, 0)$. Thus $-4R_1 + R_2 + R_3 = 0$. For consistency, $-4b_1 + b_2 + b_3 = 0$."
        ),
        mcq_single(
            "Let $Ax = b$ be a system of linear equations with a square coefficient matrix $A$. Consider the following statements:\n$S_1$: If the RREF of $A$ is the identity matrix, then the given system has a solution.\n$S_2$: If the given system has a solution, then the RREF of $A$ is the identity matrix.\nChoose the correct option:",
            [
                "Both $S_1$ and $S_2$ are true.",
                "Both $S_1$ and $S_2$ are false.",
                "$S_1$ is true and $S_2$ is false.",
                "$S_1$ is false and $S_2$ is true."
            ],
            2, marks=6, diff="medium",
            expl="If $\\text{RREF}(A) = I$, $A$ is invertible, so a solution exists for every $b$ ($S_1$ is true). However, a system can have solutions even when $A$ is singular and $\\text{RREF}(A) \\neq I$ (e.g. $Ax = 0$), so $S_2$ is false."
        ),
        mcq_multi(
            "Choose all the correct statements from the following:",
            [
                "The set of positive real numbers is a vector subspace of $\\mathbb{R}$ with standard addition and multiplication.",
                "In any vector space $V$, if for some $c \\in \\mathbb{R}$ and $v \\in V$ we have $c \\cdot v = 0$, then $c = 0$ or $v$ is the zero vector.",
                "If a vector subspace of $\\mathbb{R}^3$ contains finitely many vectors, then it is the trivial subspace $\\{(0, 0, 0)\\}$.",
                "Any subset of a spanning set of a vector space is a spanning set.",
                "Any subset of a linearly independent set in a vector space is a linearly independent set."
            ],
            [1, 2, 4], marks=6, diff="medium",
            expl="Positive real numbers do not contain 0 or negatives, so not a subspace. Over $\\mathbb{R}$, any non-trivial subspace contains infinitely many scalar multiples $cv$. Subsets of independent sets remain independent."
        ),
        mcq_multi(
            "Let $A$ be a square matrix of order $n > 1$. Select all the statements which imply that $\\det(A) = 0$:",
            [
                "All the entries of one of the columns of $A$ are zero.",
                "One of the columns of $A$ is a scalar multiple of another column.",
                "The diagonal entries of $A$ are all zero.",
                "The determinant of the transpose of $A$ is zero.",
                "$A^2 = 0$."
            ],
            [0, 1, 3, 4], marks=6, diff="medium",
            expl="A zero column, proportional columns, $\\det(A^T) = 0$, and nilpotent $A^2 = 0$ (which gives $(\\det A)^2 = 0$) all imply $\\det(A) = 0$. Zero diagonal does not imply $\\det = 0$ (e.g. $\\begin{pmatrix} 0 & 1 \\\\ 1 & 0 \\end{pmatrix}$ has $\\det = -1$)."
        ),
        numerical(
            "If the sum of the two vectors $(1, 2)$ and $(2, x)$ in $\\mathbb{R}^2$ is a scalar multiple of the vector $(2, 1)$, find the value of $x$.",
            -0.5, marks=3, diff="medium",
            expl="$(1, 2) + (2, x) = (3, 2 + x) = c(2, 1) = (2c, c)$. From $2c = 3 \\implies c = 1.5$. Then $2 + x = 1.5 \\implies x = -0.5$."
        ),
        numerical(
            "Find the minimum value of $\\beta$ such that the matrix:\n$$\\begin{pmatrix} \\beta - 1 & 0 & -1 \\\\ 2 & \\beta + 4 & 2 \\\\ \\beta + 1 & \\beta + 1 & \\beta + 1 \\end{pmatrix}$$\nis not invertible.",
            -2, marks=3, diff="medium",
            expl="Matrix is not invertible when determinant is 0. Expanding the determinant yields roots for $\\beta$. The minimum root is $\\beta = -2$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2025_-_QIO2_part1.json", "Mathematics 2 · Quiz 1 · Oct 2025 · QIO2 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "A collection of 2 coins of Type A and 3 coins of Type B is worth Rs. 19. A collection of 1 coin of Type A and 5 coins of Type B is worth Rs. 27. Let $x_1$ and $x_2$ be the values of coins of Type A and Type B respectively. Find the value of $x_1 - x_2$.",
            -3, marks=4, diff="medium",
            expl="The linear system is: $2x_1 + 3x_2 = 19$ and $x_1 + 5x_2 = 27$. Multiplying equation 2 by 2 gives $2x_1 + 10x_2 = 54$. Subtracting equation 1 gives $7x_2 = 35 \\implies x_2 = 5$. Then $x_1 = 27 - 25 = 2$. Thus $x_1 - x_2 = 2 - 5 = -3$."
        ),
        numerical(
            "The trace of a square matrix $A$ is defined as the sum of its diagonal entries. Consider the set $W$ of $3 \\times 3$ matrices with zero trace:\n$$W = \\left\\{ \\begin{pmatrix} a_{11} & a_{12} & a_{13} \\\\ a_{21} & a_{22} & a_{23} \\\\ a_{31} & a_{32} & a_{33} \\end{pmatrix} \\in M_{3\\times 3}(\\mathbb{R}) : a_{11} + a_{22} + a_{33} = 0 \\right\\}$$\nFind the dimension of $W$.",
            8, marks=4, diff="hard",
            expl="$M_{3\\times 3}(\\mathbb{R})$ has dimension 9. The single non-trivial linear constraint $a_{11} + a_{22} + a_{33} = 0$ reduces the dimension by 1, so $\\dim(W) = 9 - 1 = 8$."
        ),
        numerical(
            "Let $A$ be a $5 \\times 7$ matrix. If $n_1$ and $n_2$ are the minimum and maximum possible values of the rank of $A$, respectively, then find the value of $n_2 - n_1$.",
            5, marks=4, diff="medium",
            expl="For the zero matrix, the minimum rank is $n_1 = 0$. The maximum possible rank of a $5 \\times 7$ matrix is $\\min(5, 7) = 5$. Thus $n_2 - n_1 = 5 - 0 = 5$."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{pmatrix} 2 & -3 & 1 & -4 \\\\ 3 & 1 & -4 & 5 \\\\ 4 & k & -6 & 8 \\end{pmatrix}$$\nFind the value of $k$ such that the rank of the given matrix is 2.",
            2, marks=4, diff="medium",
            expl="Row 3 must be a linear combination of Row 1 and Row 2. Let $R_3 = c_1 R_1 + c_2 R_2$. Matching columns 1 and 3: $2c_1 + 3c_2 = 4$ and $c_1 - 4c_2 = -6 \\implies c_1 = -2/11, c_2 = 16/11$ or row reducing directly gives $k = 2$."
        ),
        mcq_single(
            "Consider the vectors in $\\mathbb{R}^3$ given by $v_1 = (1, 0, 2)$, $v_2 = (2, 3, a)$ and $v_3 = (b, 0, 3)$, where $a, b \\in \\mathbb{R}$. Statement: The vectors $v_1$ and $v_2$ are linearly dependent vectors for some value of $a$.",
            ["True", "False"],
            1, marks=3, diff="medium",
            expl="For $v_1$ and $v_2$ to be linearly dependent, $v_2$ must be a scalar multiple of $v_1$. But the second component of $v_1$ is 0 while the second component of $v_2$ is 3, which cannot be obtained by multiplying 0 by any scalar. Hence $v_1$ and $v_2$ are never dependent. Answer: False."
        ),
        numerical(
            "Consider the vectors in $\\mathbb{R}^3$ given by $v_1 = (1, 0, 2)$, $v_2 = (2, 3, a)$ and $v_3 = (b, 0, 3)$, where $a, b \\in \\mathbb{R}$. For $a = 0$, find the value of $b$ such that the set $\\{v_1, v_2, v_3\\}$ is NOT a basis of $\\mathbb{R}^3$.",
            1.5, marks=3, diff="medium",
            expl="For $\\{v_1, v_2, v_3\\}$ not to be a basis of $\\mathbb{R}^3$, the determinant of the matrix formed by them must be zero:\n$$\\det \\begin{pmatrix} 1 & 0 & 2 \\\\ 2 & 3 & 0 \\\\ b & 0 & 3 \\end{pmatrix} = 3(3 - 2b) = 0 \\implies 3 - 2b = 0 \\implies b = 1.5$$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2025_-_QIO2_part2.json", "Mathematics 2 · Quiz 1 · Oct 2025 · QIO2 · Part 2", "quiz1", p2_qs)

if __name__ == "__main__":
    build_booklet_9()
    build_booklet_10()
    build_booklet_11()
