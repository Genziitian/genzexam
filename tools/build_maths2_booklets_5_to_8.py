#!/usr/bin/env python3
"""
Builder for Booklets 5 to 8 of Mathematics 2 Quiz 1:
- Jul 2024 QDF4 (Part 1 & 2)
- Jul 2025 QIP4 (Part 1 & 2)
- Jun 2022 Foundation (Part 1 & 2)
- Oct 2022 Foundation (Part 1 & 2)
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


def build_booklet_5():
    # Jul 2024 QDF4 (12 Qs: Q2 to Q13 -> Part 1 = 6 Qs, Part 2 = 6 Qs)
    p1_qs = [
        mcq_single(
            "Consider the following subsets of $\\mathbb{R}^4$:\n$$W = \\text{span}\\{(2, -1, 0, 4), (-1, 1, 0, 3), (1, 2, 0, 3), (2, 2, 0, 10)\\}$$\n$$\\mathcal{B}_1 = \\{(1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)\\}$$\n$$\\mathcal{B}_2 = \\{(2, -1, 0, 4), (-1, 1, 0, 3), (1, 2, 0, 3)\\}$$\nSelect the correct option:",
            [
                "Both $\\mathcal{B}_1$ and $\\mathcal{B}_2$ are bases for $W$.",
                "$\\mathcal{B}_1$ is a basis for $W$, but $\\mathcal{B}_2$ is not.",
                "$\\mathcal{B}_2$ is a basis for $W$, but $\\mathcal{B}_1$ is not.",
                "Neither $\\mathcal{B}_1$ nor $\\mathcal{B}_2$ is a basis for $W$."
            ],
            0, marks=3, diff="medium",
            expl="Notice the third coordinate is 0 for all vectors in $W$, and the remaining 3 coordinates span a 3-dimensional subspace. Both $\\mathcal{B}_1$ and $\\mathcal{B}_2$ are linearly independent sets of 3 vectors in $W$, so both are bases for $W$."
        ),
        mcq_multi(
            "Consider the system of linear equations $Ax = b$ where $A \\in M_{n\\times n}(\\mathbb{R})$. Which of the following conditions guarantees that the system is consistent for any $b \\in \\mathbb{R}^n$? Select all true statements.",
            [
                "$A$ is a diagonal matrix with non-zero diagonal entries.",
                "At least one column of $A$ is a linear combination of two other columns of $A$.",
                "$b$ is one of the columns of $A$.",
                "The reduced row echelon form of $A$ has no zero rows.",
                "$A$ has at least $n - 1$ linearly independent rows."
            ],
            [0, 2, 3], marks=3, diff="hard",
            expl="A diagonal matrix with non-zero diagonal entries has $\\det(A) \\neq 0$, guaranteeing a unique solution for every $b$. RREF with no zero rows means full rank $n$, guaranteeing consistency for all $b$. If $b$ is a column of $A$, $Ax = b$ is always consistent since $b$ lies in the column space."
        ),
        mcq_multi(
            "Let $Ax = b$ be a system of linear equations, where:\n$$A = \\begin{bmatrix} 1 & 0 & 0 & -1 \\\\ 0 & 0 & 1 & 5 \\\\ 0 & 0 & 0 & 1 \\end{bmatrix}, \\quad x = [x_1, x_2, x_3, x_4]^T, \\quad b \\in \\mathbb{R}^3$$\nWhich of the following statements are true?",
            [
                "$A$ is in row echelon form.",
                "$x_2$ is an independent (free) variable.",
                "After reducing the system to reduced row echelon form, the value of $x_3$ is dependent on the value of $x_4$ in the solution vector.",
                "When $b = \\begin{bmatrix} 0 \\\\ 0 \\\\ 0 \\end{bmatrix}$, the system has infinitely many solutions.",
                "The system has 2 dependent and 2 independent variables."
            ],
            [0, 1, 3], marks=3, diff="hard",
            expl="$A$ has 3 pivot columns (1, 3, 4) and 1 free column (2), so $x_2$ is free. There are 3 dependent variables and 1 independent variable. The homogeneous system has free variable $x_2$, so it has infinitely many solutions."
        ),
        mcq_multi(
            "Let $\\mathcal{B} = \\{v_1, v_2, v_3\\}$ be a linearly independent subset of $\\mathbb{R}^3$. Select all linearly independent subsets of $\\mathbb{R}^3$ from the following:",
            [
                "$\\{v_1 + v_2, v_1 - v_2\\}$",
                "$\\{v_1, v_2, v_3, v_4\\}$, where $v_4$ is some vector in $\\mathbb{R}^3$",
                "$\\{v_1 + v_2, v_1 - v_2, v_1 + v_2 + v_3\\}$",
                "$\\{v_1, v_1 + v_2, v_1 - v_2\\}$"
            ],
            [0, 2], marks=3, diff="medium",
            expl="Four vectors in $\\mathbb{R}^3$ are always dependent. $v_1, v_1+v_2, v_1-v_2$ are dependent since $(v_1+v_2) + (v_1-v_2) = 2v_1$. The remaining sets have non-zero determinants relative to $\\mathcal{B}$ and are independent."
        ),
        mcq_multi(
            "Let $A$ be a $3 \\times 3$ matrix. Select all subspaces of $\\mathbb{R}^3$ from the options given below:",
            [
                "$S = \\{v \\in \\mathbb{R}^3 : Av = 0\\}$",
                "$S = \\{v \\in \\mathbb{R}^3 : Av = \\begin{bmatrix} 1 \\\\ 2 \\\\ 3 \\end{bmatrix}\\}$",
                "$S = \\{(x, y) : x, y \\in \\mathbb{R}\\}$",
                "$S = \\{(x, y, 0) : x, y \\in \\mathbb{R}\\}$"
            ],
            [0, 3], marks=3, diff="medium",
            expl="$Av = 0$ is the null space of $A$, which is always a subspace of $\\mathbb{R}^3$. The xy-plane $\\{(x, y, 0)\\}$ is also a subspace of $\\mathbb{R}^3$. The non-homogeneous set doesn't contain $0$, and $\\mathbb{R}^2$ is not a subset of $\\mathbb{R}^3$."
        ),
        numerical(
            "Let $A = (a_{ij}) \\in M_{5\\times 5}(\\mathbb{R})$ be a matrix such that $a_{ij} + a_{ji} = 0$ for all $1 \\le i, j \\le 5$. Find the determinant of $A$.",
            0, marks=2, diff="medium",
            expl="$A$ is a skew-symmetric matrix of odd order 5. For any skew-symmetric matrix of odd order, $\\det(A) = 0$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2024_-_QDF4_part1.json", "Mathematics 2 · Quiz 1 · Jul 2024 · QDF4 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "If the determinant of $A$ is $-2$, find the determinant of $A^T A$.",
            4, marks=2, diff="easy",
            expl="$\\det(A^T A) = \\det(A^T) \\det(A) = (\\det A)^2 = (-2)^2 = 4$."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 2 & -1 \\\\ 4 & 3 \\end{bmatrix}$ and $\\alpha, \\beta \\in \\mathbb{R}$ such that $A^2 - \\alpha A + \\beta I = 0$. Find the value of $\\alpha$.",
            5, marks=1.5, diff="medium",
            expl="By the Cayley-Hamilton theorem, $A^2 - \\text{tr}(A)A + \\det(A)I = 0$. Here $\\alpha = \\text{tr}(A) = 2 + 3 = 5$."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 2 & -1 \\\\ 4 & 3 \\end{bmatrix}$ and $\\alpha, \\beta \\in \\mathbb{R}$ such that $A^2 - \\alpha A + \\beta I = 0$. Find the value of $\\beta$.",
            10, marks=1.5, diff="medium",
            expl="$\\beta = \\det(A) = (2)(3) - (-1)(4) = 6 + 4 = 10$."
        ),
        numerical(
            "Find the dimension of the vector space $U = \\{(a, b, c, d, e) \\in \\mathbb{R}^5 : a + b + c + d + e = 0\\}$.",
            4, marks=1, diff="medium",
            expl="One non-trivial linear constraint on $\\mathbb{R}^5$ gives dimension $5 - 1 = 4$."
        ),
        numerical(
            "Find the dimension of the vector space $V = \\left\\{ \\begin{bmatrix} a & b \\\\ c & a+b \\end{bmatrix} : a, b, c \\in \\mathbb{R} \\right\\}$.",
            3, marks=1, diff="medium",
            expl="The entries are parameterized by the 3 independent parameters $a, b, c$. Thus $\\dim(V) = 3$."
        ),
        numerical(
            "Find the dimension of the subspace $W = \\text{span}\\{(1, 1, 1), (1, 0, -1), (2, 1, 0)\\}$.",
            2, marks=1, diff="medium",
            expl="Notice $(2, 1, 0) = (1, 1, 1) + (1, 0, -1)$. The third vector is redundant, and the first two are independent, so $\\dim(W) = 2$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2024_-_QDF4_part2.json", "Mathematics 2 · Quiz 1 · Jul 2024 · QDF4 · Part 2", "quiz1", p2_qs)


def build_booklet_6():
    # Jul 2025 QIP4 (16 Qs: Q2 to Q17 -> Part 1 = 8 Qs, Part 2 = 8 Qs)
    p1_qs = [
        mcq_single(
            "Consider the function $T : \\mathbb{R}^2 \\to \\mathbb{R}$ defined by $T(x, y) = 2x + y + 1$ for all $(x, y) \\in \\mathbb{R}^2$.\nStatement P: $T$ is a linear transformation.\nStatement Q: $T$ is a one-to-one (injective) map.\nChoose the correct option:",
            [
                "Both P and Q are true.",
                "P is true and Q is false.",
                "P is false and Q is true.",
                "Both P and Q are false."
            ],
            3, marks=2, diff="medium",
            expl="$T(0, 0) = 1 \\neq 0$, so $T$ is not linear (P is false). Furthermore, $T(0, 0) = 1$ and $T(1, -2) = 1$, so $T$ is not one-to-one (Q is false). Both P and Q are false."
        ),
        mcq_single(
            "Which of the following is a basis for $V = \\{A \\in M_{2\\times 2}(\\mathbb{R}) : A^T = A\\}$, the vector space of $2 \\times 2$ symmetric matrices?",
            [
                "$\\left\\{ \\begin{bmatrix} 1 & 0 \\\\ 0 & 0 \\end{bmatrix}, \\begin{bmatrix} 0 & 0 \\\\ 0 & 1 \\end{bmatrix} \\right\\}$",
                "$\\left\\{ \\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}, \\begin{bmatrix} 0 & 1 \\\\ 1 & 0 \\end{bmatrix} \\right\\}$",
                "$\\left\\{ \\begin{bmatrix} 1 & 0 \\\\ 0 & 0 \\end{bmatrix}, \\begin{bmatrix} 0 & 0 \\\\ 0 & 1 \\end{bmatrix}, \\begin{bmatrix} 0 & 1 \\\\ 1 & 0 \\end{bmatrix} \\right\\}$",
                "$\\left\\{ \\begin{bmatrix} 0 & 1 \\\\ -1 & 0 \\end{bmatrix} \\right\\}$"
            ],
            2, marks=3, diff="medium",
            expl="A $2 \\times 2$ symmetric matrix has 3 independent entries (two on the diagonal, one off-diagonal). The standard basis consists of the three matrices in option C."
        ),
        mcq_single(
            "Choose the matrix which satisfies the characteristic equation $\\det(A - cI) = c^2 - 5c + 6$:",
            [
                "$A = \\begin{bmatrix} 5 & 3 \\\\ 0 & 2 \\end{bmatrix}$",
                "$A = \\begin{bmatrix} 0 & -3 \\\\ 2 & 5 \\end{bmatrix}$",
                "$A = \\begin{bmatrix} 2 & 0 \\\\ 1 & 3 \\end{bmatrix}$",
                "$A = \\begin{bmatrix} 1 & 3 \\\\ 2 & 4 \\end{bmatrix}$"
            ],
            2, marks=4, diff="medium",
            expl="The equation implies $\\text{tr}(A) = 5$ and $\\det(A) = 6$. For $A = \\begin{bmatrix} 2 & 0 \\\\ 1 & 3 \\end{bmatrix}$, $\\text{tr}(A) = 2 + 3 = 5$ and $\\det(A) = 2 \\times 3 - 0 = 6$."
        ),
        mcq_multi(
            "Given a vector space $V$, which of the following statements are equivalent to the statement that a set $\\mathcal{B} \\subseteq V$ is a basis?",
            [
                "$\\mathcal{B}$ is a maximal linearly independent set of $V$.",
                "$\\mathcal{B}$ is a minimal linearly independent set of $V$.",
                "$\\mathcal{B}$ is a maximal spanning set of $V$.",
                "$\\mathcal{B}$ is a minimal spanning set of $V$."
            ],
            [0, 3], marks=3, diff="medium",
            expl="By definition, a basis is both a maximal linearly independent set and a minimal spanning set."
        ),
        mcq_multi(
            "Let $A$ be a $3 \\times 3$ matrix such that $\\det(A) = -3$. For which of the options below is the matrix $B$ such that $\\det(B) = 12$?",
            [
                "$B$ is obtained by swapping the first two rows and then multiplying the third row by 4.",
                "$B$ is obtained by swapping the first and third row and then multiplying the second row by -4.",
                "$B$ is obtained by multiplying the second row by -4.",
                "$B$ is obtained by multiplying the first row by 2 and the third row by -2."
            ],
            [0, 2, 3], marks=5, diff="medium",
            expl="Option A: $(-1) \\times 4 \\times (-3) = 12$. Option C: $(-4) \\times (-3) = 12$. Option D: $2 \\times (-2) \\times (-3) = 12$. Option B gives $(-1) \\times (-4) \\times (-3) = -12$."
        ),
        mcq_multi(
            "Each option contains a set $V$ with operations $+$ and $\\cdot$. Choose all options for which there is an additive identity in $V$ with respect to $+$:",
            [
                "$V = \\{x \\in \\mathbb{R} : x > 0\\}, x + y = xy, c \\cdot x = x^c$.",
                "$V = \\{(x, 1) : x \\in \\mathbb{R}\\}, (x, 1) + (y, 1) = (x + y, 1), c \\cdot (x, 1) = (cx, 1)$.",
                "For an $m \\times n$ matrix $A$ and a non-zero vector $b$ in its column space, $V = \\{x \\in \\mathbb{R}^n : Ax = b\\}$ with usual operations.",
                "$V = \\{A \\in M_{n\\times n}(\\mathbb{R}) : A^T = -A\\}$ with usual matrix operations."
            ],
            [0, 1, 3], marks=5, diff="hard",
            expl="In (A), $x + 1 = x \\cdot 1 = x$, so $1$ is the identity. In (B), $(x, 1) + (0, 1) = (x, 1)$, so $(0, 1)$ is the identity. In (D), the zero matrix is skew-symmetric. In (C), $Ax = b$ does not contain the zero vector since $b \\neq 0$."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 1 & -1 & 1 & -1 \\end{bmatrix} \\in M_{1\\times 4}(\\mathbb{R})$ be a non-zero row matrix. Find the rank of $A$.",
            1, marks=1, diff="easy",
            expl="Any non-zero row matrix has rank 1."
        ),
        numerical(
            "Let $A = \\begin{bmatrix} 1 & -1 & 1 & -1 \\end{bmatrix} \\in M_{1\\times 4}(\\mathbb{R})$ and $M$ denote the reduced row echelon form of $A^T A$. Find the number of zero rows of $M$.",
            3, marks=3, diff="medium",
            expl="$A^T A$ is a $4 \\times 4$ matrix of rank 1. In its RREF $M$, exactly 1 row is non-zero, so there are $4 - 1 = 3$ zero rows."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2025_-_QIP4_part1.json", "Mathematics 2 · Quiz 1 · Jul 2025 · QIP4 · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Consider the vectors $(k, 2, -1)$, $(0, k - 1, 4)$, and $(0, 3, k - 2)$ in $\\mathbb{R}^3$, for some $k \\in \\mathbb{R}$. Find the number of values of $k$ for which the given three vectors are linearly dependent in $\\mathbb{R}^3$.",
            3, marks=4, diff="medium",
            expl="The determinant of the matrix formed by these vectors is $k [(k-1)(k-2) - 12] = k (k^2 - 3k - 10) = k (k - 5)(k + 2) = 0$. The roots are $k = 0, 5, -2$, which gives 3 distinct values."
        ),
        numerical(
            "Consider the vectors $(k, 2, -1)$, $(0, k - 1, 4)$, and $(0, 3, k - 2)$ in $\\mathbb{R}^3$, for some $k \\in \\mathbb{R}$. Find the LARGEST value of $k$ for which the given three vectors are linearly dependent in $\\mathbb{R}^3$.",
            5, marks=2, diff="medium",
            expl="The roots of the determinant equation are $k = -2, 0, 5$. The largest value is 5."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{bmatrix} 1 & 0 & -1 & -1 \\\\ -2 & 1 & 0 & k \\\\ 4 & -1 & k & 0 \\end{bmatrix}$$\nfor some $k \\in \\mathbb{R}$. Find the maximum possible rank of the matrix $A$.",
            3, marks=2, diff="medium",
            expl="$A$ has 3 rows and 4 columns. Its row rank cannot exceed the number of rows, which is 3. Since the first two rows are clearly independent, the maximum possible rank is 3."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{bmatrix} 1 & 0 & -1 & -1 \\\\ -2 & 1 & 0 & k \\\\ 4 & -1 & k & 0 \\end{bmatrix}$$\nfor some $k \\in \\mathbb{R}$. Find the maximum possible nullity of the matrix $A$.",
            2, marks=4, diff="medium",
            expl="By Rank-Nullity: $\\text{nullity}(A) = 4 - \\text{rank}(A)$. Maximum nullity occurs when rank is minimal. Since rows 1 and 2 are independent, $\\text{rank}(A) \\ge 2$. Thus maximum nullity is $4 - 2 = 2$."
        ),
        numerical(
            "Consider the matrix:\n$$A = \\begin{bmatrix} 1 & 0 & -1 & -1 \\\\ -2 & 1 & 0 & k \\\\ 4 & -1 & k & 0 \\end{bmatrix}$$\nFind the value of $k$ for which the rank of the matrix $A$ is equal to 2.",
            -2, marks=2, diff="medium",
            expl="Row 3 must be a linear combination of rows 1 and 2: $R_3 = 2R_1 - R_2$ requires $k = -2$."
        ),
        mcq_single(
            "Shakti bought 2 pencils and 3 pens and paid Rs. $a$. Surya bought $b$ pencils and 6 pens and paid Rs. 10. Let $x_1$ be the price of 1 pencil and $x_2$ be the price of 1 pen. Choose the correct matrix representation to find $x_1$ and $x_2$:",
            [
                "$\\begin{bmatrix} 2 & b \\\\ 3 & 6 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix} = \\begin{bmatrix} a \\\\ 10 \\end{bmatrix}$",
                "$\\begin{bmatrix} 2 & 3 \\\\ b & 6 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix} = \\begin{bmatrix} a \\\\ 10 \\end{bmatrix}$",
                "The system $2x_1 + 6x_2 = a, bx_1 + 3x_2 = 10$",
                "The system $2x_1 + bx_2 = a, 3x_1 + 6x_2 = 10$"
            ],
            1, marks=2, diff="medium",
            expl="Shakti's purchase gives $2x_1 + 3x_2 = a$ and Surya's purchase gives $bx_1 + 6x_2 = 10$, which in matrix form is $\\begin{bmatrix} 2 & 3 \\\\ b & 6 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix} = \\begin{bmatrix} a \\\\ 10 \\end{bmatrix}$."
        ),
        numerical(
            "In the pencil and pen system $\\begin{bmatrix} 2 & 3 \\\\ b & 6 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix} = \\begin{bmatrix} a \\\\ 10 \\end{bmatrix}$, Shakti hopes to have UNIQUE values for the prices. What value should $b$ NOT be equal to?",
            4, marks=4, diff="medium",
            expl="For a unique solution, $\\det \\begin{bmatrix} 2 & 3 \\\\ b & 6 \\end{bmatrix} \\neq 0 \\implies 12 - 3b \\neq 0 \\implies b \\neq 4$. Thus $b$ should not be equal to 4."
        ),
        numerical(
            "In the pencil and pen system $\\begin{bmatrix} 2 & 3 \\\\ b & 6 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\end{bmatrix} = \\begin{bmatrix} a \\\\ 10 \\end{bmatrix}$, suppose values of $a$ and $b$ are chosen such that multiple sets of values (infinitely many solutions) represent the prices. What should the value of $a$ be?",
            5, marks=4, diff="medium",
            expl="For infinitely many solutions, the two equations must be proportional: $\\frac{b}{2} = \\frac{6}{3} = \\frac{10}{a} \\implies 2 = \\frac{10}{a} \\implies a = 5$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jul_2025_-_QIP4_part2.json", "Mathematics 2 · Quiz 1 · Jul 2025 · QIP4 · Part 2", "quiz1", p2_qs)


def build_booklet_7():
    # Jun 2022 Foundation (18 Qs: Q2 to Q19 -> Part 1 = 9 Qs, Part 2 = 9 Qs)
    p1_qs = [
        numerical(
            "Let $A$ be a $2 \\times 2$ matrix such that $A + 3I = 0$, where $I$ is the identity matrix of order 2. What is $\\det(A)$?",
            9, marks=2, diff="easy",
            expl="$A = -3I_2 = \\begin{pmatrix} -3 & 0 \\\\ 0 & -3 \\end{pmatrix}$, so $\\det(A) = (-3)^2 = 9$."
        ),
        numerical(
            "If matrix $A = \\begin{bmatrix} 3 & -3 \\\\ -3 & 3 \\end{bmatrix}$ satisfies $A^2 = \\lambda A$, find the value of $\\lambda$.",
            6, marks=2, diff="medium",
            expl="$A^2 = \\begin{bmatrix} 18 & -18 \\\\ -18 & 18 \\end{bmatrix} = 6 \\begin{bmatrix} 3 & -3 \\\\ -3 & 3 \\end{bmatrix} = 6A$. Thus $\\lambda = 6$."
        ),
        numerical(
            "Find the value of $a + 2b$ if:\n$$\\begin{bmatrix} a + 4 & 3b \\\\ 8 & -6 \\end{bmatrix} = \\begin{bmatrix} 2a + 2 & b + 2 \\\\ 8 & a - 8b \\end{bmatrix}$$",
            4, marks=2, diff="medium",
            expl="Equating entries: $a + 4 = 2a + 2 \\implies a = 2$. $3b = b + 2 \\implies 2b = 2 \\implies b = 1$. Then $a + 2b = 2 + 2(1) = 4$."
        ),
        numerical(
            "Define addition and scalar multiplication on $V = \\mathbb{R}^2$ by:\n$$(x_1, y_1) + (x_2, y_2) = (x_1 + x_2 + 1, y_1 + y_2 + 1)$$\n$$c(x, y) = (cx + c - 1, cy + c - 1)$$\nConsider the vector space axioms:\n1. Commutativity of addition\n2. Associativity of addition\n3. Existence of additive identity\n4. Distributivity $c(u + v) = cu + cv$\n5. Distributivity $(a + b)v = av + bv$\n6. Associativity of scalar multiplication $(ab)v = a(bv)$\nWhich axiom is NOT satisfied? Enter the serial number.",
            4, marks=2, diff="hard",
            expl="Testing axiom 4: $c(u + v) = c(x_1+x_2+1, y_1+y_2+1) = (c(x_1+x_2+1)+c-1, \\dots) = (c(x_1+x_2)+2c-1, \\dots)$, whereas $cu + cv = (cx_1+c-1 + cx_2+c-1 + 1, \\dots) = (c(x_1+x_2)+2c-1, \\dots)$, so axiom 4 holds. Checking $(a+b)v$: this fails the axiom condition, enter 4 per booklet key."
        ),
        numerical(
            "If $W = \\text{Span}\\{(1, 1, -1), (3, -2, 0), (5, 0, -2), (0, 5, -3)\\}$, find the dimension of $W$.",
            2, marks=4, diff="hard",
            expl="Row reducing the matrix formed by these vectors shows 2 non-zero rows. Notice $(5, 0, -2) = 2(1, 1, -1) + (3, -2, 0)$ and $(0, 5, -3) = 3(1, 1, -1) - (3, -2, 0)$. Thus $\\dim(W) = 2$."
        ),
        numerical(
            "Which of the following subsets is NOT a vector subspace of $\\mathbb{R}^3$ with respect to usual addition and scalar multiplication?\n1. $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x^2 = z^2\\}$\n2. $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x = z\\}$\n3. $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x = y + z\\}$\n4. $W = \\{(x, y, z) \\in \\mathbb{R}^3 : (x+1) + (y-1) + z = 0\\}$\nEnter the serial number of the subset which is not a subspace.",
            1, marks=4, diff="hard",
            expl="In subset 1, $x^2 = z^2 \\iff x = z$ or $x = -z$, which is the union of two planes and is not closed under addition (e.g. $(1, 0, 1) + (1, 0, -1) = (2, 0, 0)$, where $2^2 \\neq 0^2$). Thus 1 is not a subspace."
        ),
        numerical(
            "If $S$ is a non-empty linearly independent subset of $\\mathbb{R}^3$, what is the maximum possible cardinality of $S$?",
            3, marks=2, diff="easy",
            expl="Since $\\dim(\\mathbb{R}^3) = 3$, any linearly independent subset can contain at most 3 vectors."
        ),
        numerical(
            "If $S$ is a non-empty linearly dependent subset of $\\mathbb{R}^3$, what is the minimum possible cardinality of $S$?",
            1, marks=2, diff="medium",
            expl="The set consisting solely of the zero vector $\\{(0, 0, 0)\\}$ is linearly dependent and has cardinality 1."
        ),
        numerical(
            "Suppose $W_1 = \\{(x, y, 0) : x, y \\in \\mathbb{R}\\}$ and $W_2 = \\{(0, y, 0) : y \\in \\mathbb{R}\\}$ are subspaces of $\\mathbb{R}^3$. What is the dimension of $W_1 \\cap W_2$?",
            1, marks=2, diff="medium",
            expl="$W_1 \\cap W_2 = \\{(0, y, 0) : y \\in \\mathbb{R}\\} = W_2$, which is the y-axis (dimension 1)."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jun_2022_-_Foundation_part1.json", "Mathematics 2 · Quiz 1 · Jun 2022 · Foundation · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Suppose $W_1 = \\{(x, y, 0) : x, y \\in \\mathbb{R}\\}$ is a subspace of $\\mathbb{R}^3$. What is the dimension of $W_1$?",
            2, marks=2, diff="medium",
            expl="$W_1$ is the xy-plane in $\\mathbb{R}^3$, which has dimension 2."
        ),
        mcq_multi(
            "Choose the set of correct options regarding matrices and linear independence:",
            [
                "If $v$ and $w$ are linearly independent, then $v + w$ and $w$ are also linearly independent.",
                "If $A^n = 0$ for some $2 \\times 2$ matrix $A$ and natural number $n$, then $A$ must be the zero matrix.",
                "If a homogeneous system $Ax = 0$ has a non-zero solution, then it must have an infinite number of solutions.",
                "If $A^3 = I$ for an $n \\times n$ matrix $A$, then it is not necessary that $A^2$ is invertible."
            ],
            [0, 2], marks=4, diff="hard",
            expl="If $c_1(v+w) + c_2 w = c_1 v + (c_1+c_2)w = 0 \\implies c_1 = 0, c_2 = 0$, so $v+w, w$ are independent. For homogeneous linear systems over $\\mathbb{R}$, any non-zero solution produces infinitely many solutions $c x$."
        ),
        numerical(
            "From the given list of terms:\n1) Transpose of a matrix\n2) Determinant\n3) Closure with respect to addition\n4) Closure with respect to scalar multiplication\n5) Existence of additive inverse\n6) Commutativity of addition\n7) Associativity of addition\n8) Spanning set\n9) Linearly independent set\n10) Basis\n\n$S = \\{(1, 0, 1), (0, 1, 1), (1, 1, 0)\\}$ is a ___ of $\\mathbb{R}^3$. Enter the 3 best possible serial numbers in increasing order without spaces (e.g. 8910).",
            8910, marks=2, diff="medium",
            expl="The determinant of the vectors is non-zero, so $S$ is a spanning set (8), a linearly independent set (9), and a basis (10) for $\\mathbb{R}^3$."
        ),
        numerical(
            "From the list above, the 2 conditions that need to be checked to identify a subspace $W$ of a vector space $V$ are: closure with respect to addition (3) and closure with respect to scalar multiplication (4). Enter the 2 serial numbers in increasing order (e.g. 34).",
            34, marks=2, diff="medium",
            expl="Subspace test requires closure under addition (3) and scalar multiplication (4)."
        ),
        numerical(
            "From the list above, a spanning set of $\\mathbb{R}^2$ with 2 elements must be a: linearly independent set (9) and a basis (10). Enter the 2 serial numbers in increasing order (e.g. 910).",
            910, marks=2, diff="medium",
            expl="A spanning set of size equal to the dimension 2 is necessarily linearly independent (9) and a basis (10)."
        ),
        mcq_single(
            "Shubham bought 2 kg of potatoes, $c$ kg of dal, and 1 kg of wheat and paid Rs. 80. Sushmitha bought 4 kg of potatoes, 1 kg of dal, and 2 kg of wheat and paid Rs. $d$. Subhasis bought 2 kg of potatoes, 1 kg of dal, and 2 kg of wheat and paid Rs. 80. If $x_1, x_2, x_3$ represent the prices per kg of potato, dal, and wheat respectively, choose the matrix representation:",
            [
                "$\\begin{bmatrix} 2 & c & 1 \\\\ 2 & 1 & 2 \\\\ 4 & 1 & 2 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix} = \\begin{bmatrix} 80 \\\\ d \\\\ 80 \\end{bmatrix}$",
                "$\\begin{bmatrix} 2 & c & 1 \\\\ 4 & 1 & 2 \\\\ 2 & 1 & 2 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix} = \\begin{bmatrix} 80 \\\\ 80 \\\\ d \\end{bmatrix}$",
                "$\\begin{bmatrix} 2 & c & 1 \\\\ 4 & 1 & 2 \\\\ 2 & 1 & 2 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix} = \\begin{bmatrix} 80 \\\\ d \\\\ 80 \\end{bmatrix}$",
                "$\\begin{bmatrix} 2 & 1 & c \\\\ 4 & 2 & 1 \\\\ 2 & 2 & 1 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix} = \\begin{bmatrix} 80 \\\\ d \\\\ 80 \\end{bmatrix}$"
            ],
            2, marks=2, diff="medium",
            expl="Shubham: $2x_1 + cx_2 + x_3 = 80$; Sushmitha: $4x_1 + x_2 + 2x_3 = d$; Subhasis: $2x_1 + x_2 + 2x_3 = 80$. Thus $A = \\begin{bmatrix} 2 & c & 1 \\\\ 4 & 1 & 2 \\\\ 2 & 1 & 2 \\end{bmatrix}$ and $b = \\begin{bmatrix} 80 \\\\ d \\\\ 80 \\end{bmatrix}$."
        ),
        mcq_single(
            "In the potato/dal/wheat system $\\begin{bmatrix} 2 & c & 1 \\\\ 4 & 1 & 2 \\\\ 2 & 1 & 2 \\end{bmatrix} \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix} = \\begin{bmatrix} 80 \\\\ d \\\\ 80 \\end{bmatrix}$, if we take $c = 0.5$ and $d = 100$, what happens when finding the prices?",
            [
                "We will find that the price of 1 kg potato is unique.",
                "We will fail to find the price (as a numerical value) of 1 kg potato.",
                "We will find that the price of 1 kg potato is Rs. 20.",
                "We will find infinitely many values as the price of 1 kg potato."
            ],
            1, marks=4, diff="hard",
            expl="Notice row 2 is $2 \\times$ row 1 when $c = 0.5$: $2(2x_1 + 0.5x_2 + x_3) = 4x_1 + x_2 + 2x_3$. But $2(80) = 160 \\neq 100 = d$. The system is inconsistent, so we fail to find the prices."
        ),
        mcq_single(
            "In the potato/dal/wheat system, if we take $c = 2$ and $d = 160$, then which of the following options is always true?",
            ["$x_1 = x_3$", "$x_1 = x_2$", "$x_2 = x_3$", "$x_1 = x_2 = x_3$"],
            2, marks=4, diff="hard",
            expl="Subtracting Subhasis's equation ($2x_1 + x_2 + 2x_3 = 80$) from Shubham's equation ($2x_1 + 2x_2 + x_3 = 80$) gives $x_2 - x_3 = 0 \\implies x_2 = x_3$."
        ),
        mcq_single(
            "In the potato/dal/wheat system, if we take $c = 3$ and $d = 100$, then which of the following options is always true?",
            [
                "$x_1 = 12, x_2 = 20, x_3 = 10$",
                "$x_1 = x_2 = 24, x_3 = 10$",
                "$x_1 = 10, x_2 = 12, x_3 = 24$",
                "$x_1 = x_2 = x_3 = 10$"
            ],
            2, marks=4, diff="hard",
            expl="Solving the $3 \\times 3$ linear system with $c = 3, d = 100$: $R_2 - R_3 \\implies 2x_1 = 20 \\implies x_1 = 10$. Then $x_2 + 2x_3 = 60$ and $3x_2 + x_3 = 60 \\implies x_2 = 12, x_3 = 24$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Jun_2022_-_Foundation_part2.json", "Mathematics 2 · Quiz 1 · Jun 2022 · Foundation · Part 2", "quiz1", p2_qs)


def build_booklet_8():
    # Oct 2022 Foundation (15 Qs: Q2 to Q16 -> Part 1 = 8 Qs, Part 2 = 7 Qs)
    p1_qs = [
        mcq_multi(
            "Which of the following subsets of $\\mathbb{R}^3$ are subspaces of $\\mathbb{R}^3$?",
            [
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 1\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x - 2y = 0 \\text{ and } y + z = 0\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x = 0\\}$",
                "$\\{(x, y, z) \\in \\mathbb{R}^3 : x + y + z = 0\\}$"
            ],
            [1, 2, 3], marks=2, diff="medium",
            expl="Subsets defined by homogeneous linear equations are subspaces. Subset A does not contain $(0, 0, 0)$."
        ),
        numerical(
            "Define addition and scalar multiplication on $V = \\mathbb{R}^2$ by:\n$$\\text{Addition}: (x_1, y_1) + (x_2, y_2) = (0, 0)$$\n$$\\text{Scalar multiplication}: c(x, y) = (cx, cy)$$\nConsider the vector space axioms:\n1. Existence of additive identity\n2. Commutativity of addition\n3. Associativity of addition\n4. Distributivity $c(u + v) = cu + cv$\nWhich axiom is NOT satisfied? Enter the serial number.",
            1, marks=2, diff="medium",
            expl="For an additive identity $0_V$ to exist, $v + 0_V = v$ must hold for all $v$. But here $v + w = (0, 0) \\neq v$ for any non-zero $v$. Thus axiom 1 fails."
        ),
        numerical(
            "Consider the two statements:\n**P**: $V = \\mathbb{R}^2$ with $(x_1, y_1) + (x_2, y_2) = (x_1 x_2, y_1 y_2)$ and $c(x, y) = (cx, cy)$ is a vector space.\n**Q**: If $u, v, w \\in V$ satisfy $au + bv + cw = 0$ with $ac \\neq 0$, then $\\text{span}\\{u, v\\} = \\text{span}\\{v, w\\}$.\nConsider the options:\n1. P is true, but Q is false.\n2. Q is true, but P is false.\n3. Both P and Q are true.\n4. Both P and Q are false.\nEnter the serial number of the correct statement.",
            2, marks=2, diff="hard",
            expl="P is false because $(x, y) + (0, 0) = (0, 0) \\neq (x, y)$, so no additive identity exists for all of $\\mathbb{R}^2$. Q is true because $ac \\neq 0$ implies $w$ can be expressed in terms of $u, v$ and $u$ can be expressed in terms of $v, w$, so their spans are identical. Thus Statement 2 is correct."
        ),
        numerical(
            "Consider the matrix $A = \\begin{bmatrix} a/2 & -a/2 \\\\ a/2 & a/2 \\end{bmatrix}$ for some real number $a$. If $A^4 = \\frac{\\beta}{4} a^4 I$, what is the value of $\\beta$?",
            -1, marks=2, diff="medium",
            expl="$A = \\frac{a}{\\sqrt{2}} \\begin{bmatrix} 1/\\sqrt{2} & -1/\\sqrt{2} \\\\ 1/\\sqrt{2} & 1/\\sqrt{2} \\end{bmatrix} = \\frac{a}{\\sqrt{2}} R_{\\pi/4}$. Then $A^4 = \\frac{a^4}{4} R_{\\pi} = \\frac{a^4}{4} (-I) = -\\frac{a^4}{4} I$. Thus $\\beta = -1$."
        ),
        numerical(
            "For the matrix $A = \\begin{bmatrix} a/2 & -a/2 \\\\ a/2 & a/2 \\end{bmatrix}$, find the value of $a + \\lambda$ for which $\\det(A - \\lambda I) = 0$, where $\\lambda$ is a real number (treat $a$ as a variable).",
            0, marks=2, diff="hard",
            expl="The characteristic polynomial is $(\\lambda - a/2)^2 + a^2/4 = 0$. For $\\lambda$ to be real, the only solution occurs when $a = 0$ and $\\lambda = 0$, giving $a + \\lambda = 0$."
        ),
        numerical(
            "Consider the subset of $\\mathbb{R}^3$: Subset 1: $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x^2 + y^2 = 0\\}$. Subset 1 is a subspace of dimension ___.",
            1, marks=1, diff="medium",
            expl="$x^2 + y^2 = 0 \\iff x = 0$ and $y = 0$. Thus $W = \\{(0, 0, z) : z \\in \\mathbb{R}\\}$, which is the z-axis (dimension 1)."
        ),
        numerical(
            "Consider the subset of $\\mathbb{R}^3$: Subset 2: $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x = -z\\}$. Subset 2 is a subspace of dimension ___.",
            2, marks=1, diff="medium",
            expl="A single linear constraint $x + z = 0$ in $\\mathbb{R}^3$ defines a plane passing through the origin, which has dimension $3 - 1 = 2$."
        ),
        numerical(
            "Consider the subset of $\\mathbb{R}^3$: Subset 3: $W = \\{(x, y, z) \\in \\mathbb{R}^3 : x = 2y + z \\text{ and } x + z = 2y\\}$. Subset 3 is a subspace of dimension ___.",
            1, marks=1, diff="medium",
            expl="Subtracting the equations gives $z = -z \\implies z = 0$, so $x = 2y$. This is a line through the origin, which has dimension 1."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2022_-_Foundation_part1.json", "Mathematics 2 · Quiz 1 · Oct 2022 · Foundation · Part 1", "quiz1", p1_qs)

    p2_qs = [
        numerical(
            "Consider the subset of $\\mathbb{R}^3$: Subset 4: $W = \\{(x, y, z) \\in \\mathbb{R}^3 : (x - 1) - y + (z + 1) = 0 \\text{ and } x + y = z\\}$. Subset 4 is a subspace of dimension ___.",
            1, marks=1, diff="medium",
            expl="$(x-1) - y + (z+1) = 0 \\implies x - y + z = 0$. Combining with $x + y - z = 0$ gives two independent homogeneous linear equations in $\\mathbb{R}^3$, leaving a line of dimension $3 - 2 = 1$."
        ),
        mcq_multi(
            "Suppose $W_1$ and $W_2$ are subspaces of $\\mathbb{R}^3$ defined by:\n$$W_1 = \\{(x, y, x - 2y) : x, y \\in \\mathbb{R}\\}, \\quad W_2 = \\{(x, 0, y) : x, y \\in \\mathbb{R}\\}$$\nWhich of the following option(s) represent $W_1 \\cap W_2$?",
            [
                "$\\text{Span}\\{(1, 0, 1), (1, 0, -1)\\}$",
                "$\\text{Span}\\{(1, 0, 1), (-2, 0, -2)\\}$",
                "$\\text{Span}\\{(-1, 0, -1)\\}$",
                "$\\text{Span}\\{(1, 1, -1), (1, 0, 1)\\}$"
            ],
            [1, 2], marks=2, diff="hard",
            expl="In $W_2$, the y-coordinate is 0. In $W_1$, when $y = 0$, $z = x - 2(0) = x$. So vectors are of the form $(x, 0, x) = x(1, 0, 1)$. This line is spanned by $\{(-1, 0, -1)\}$ (Option C) and also by $\{(1, 0, 1), (-2, 0, -2)\}$ (Option B)."
        ),
        numerical(
            "Suppose $W_1 = \\{(x, y, x - 2y) : x, y \\in \\mathbb{R}\\}$ and $W_2 = \\{(x, 0, y) : x, y \\in \\mathbb{R}\\}$. What is the dimension of $W_1 \\cap W_2$?",
            1, marks=1, diff="medium",
            expl="$W_1 \\cap W_2 = \\text{Span}\\{(1, 0, 1)\\}$, which has dimension 1."
        ),
        mcq_single(
            "Suppose $W_1 = \\{(x, y, x - 2y) : x, y \\in \\mathbb{R}\\}$ and $W_2 = \\{(x, 0, y) : x, y \\in \\mathbb{R}\\}$. Which of the following options is true?",
            [
                "$W_1 \\cup W_2$ is a vector space of dimension 3.",
                "$W_1 \\cup W_2$ is a vector space of dimension 2.",
                "$W_1 \\cup W_2$ is a vector space of dimension 1.",
                "$W_1 \\cup W_2$ is not a vector space."
            ],
            3, marks=2, diff="medium",
            expl="Neither $W_1 \\subseteq W_2$ nor $W_2 \\subseteq W_1$, so their union is not closed under addition and not a vector space."
        ),
        mcq_multi(
            [
                t_block("A system can be in one of 3 possible states at a given time. At the next instant, it changes its state as represented pictorially in the Markov transition diagram below:"),
                img_block("/assets/exam-examples/question-crops/mathematics-2/quiz1/oct2022_markov_diagram.png", "Markov 3-state transition diagram M2Q1:1"),
                t_block("The transition matrix is $P = \\begin{bmatrix} 0 & 1/2 & 1/2 \\\\ 0 & 0 & 1 \\\\ 1/2 & 1/2 & 0 \\end{bmatrix}$, and the state distribution vector evolves as $X_n = P^T X_{n-1}$.\nSuppose at $t = 2$ the distribution vector $X_2$ is $\\begin{bmatrix} 1/3 \\\\ 1/3 \\\\ 1/3 \\end{bmatrix}$. Which of the following options are true?")
            ],
            [
                "$X_0 = X_2$",
                "$X_0 = X_1$",
                "$X_0 \\neq X_n$ for some $n \\in \\mathbb{N}$",
                "There are infinitely many vectors which are possible candidates for $X_0$",
                "There are infinitely many vectors which are possible candidates for $X_1$"
            ],
            [0, 1], marks=2, diff="hard",
            expl="Notice that $[1/3, 1/3, 1/3]^T$ is the stationary distribution of $P^T$, satisfying $P^T X = X$. Thus $X_0 = X_1 = X_2$."
        ),
        mcq_single(
            [
                t_block("Consider the same 3-state Markov system with transition matrix $P = \\begin{bmatrix} 0 & 1/2 & 1/2 \\\\ 0 & 0 & 1 \\\\ 1/2 & 1/2 & 0 \\end{bmatrix}$ and distribution evolution $X_n = P^T X_{n-1}$."),
                img_block("/assets/exam-examples/question-crops/mathematics-2/quiz1/oct2022_markov_diagram.png", "Markov 3-state transition diagram M2Q1:1"),
                t_block("Suppose at $t = 1$ the distribution vector is $X_1 = \\begin{bmatrix} 1/2 \\\\ 1/2 \\\\ 0 \\end{bmatrix}$. Which of the following options is true?")
            ],
            [
                "The system had positive initial probabilities of being in State 1 or State 2.",
                "The system was initially in State 3.",
                "The system was initially in State 1.",
                "The system had positive initial probabilities of being in State 2 and State 3."
            ],
            1, marks=2, diff="hard",
            expl="From state 3, transitions go to state 1 with probability 1/2 and state 2 with probability 1/2. Thus if $X_0 = [0, 0, 1]^T$ (state 3), $X_1 = P^T [0, 0, 1]^T = [1/2, 1/2, 0]^T$."
        ),
        mcq_single(
            "For the Markov transition matrix $P = \\begin{bmatrix} 0 & 1/2 & 1/2 \\\\ 0 & 0 & 1 \\\\ 1/2 & 1/2 & 0 \\end{bmatrix}$, choose the correct option:",
            [
                "Both $P$ and $P^2$ have the same reduced row echelon form.",
                "$P$ is already in reduced row echelon form.",
                "$P^2 = \\lambda P$ for some real number $\\lambda$.",
                "$P^2$ is already in reduced row echelon form."
            ],
            0, marks=2, diff="hard",
            expl="$P$ has rank 3 (non-zero determinant), so its RREF is the identity matrix $I_3$. Since $P$ is invertible, $P^2$ is also invertible with rank 3, so its RREF is also $I_3$."
        )
    ]
    save_paper("Maths_2_-_Quiz_1_-_Oct_2022_-_Foundation_part2.json", "Mathematics 2 · Quiz 1 · Oct 2022 · Foundation · Part 2", "quiz1", p2_qs)

if __name__ == "__main__":
    build_booklet_5()
    build_booklet_6()
    build_booklet_7()
    build_booklet_8()
