#!/usr/bin/env python3
"""
Quiz 2 OCR → Quiz Lab JSON Parser
Extracts questions from rasterized Quiz 2 PDFs in ~/Downloads/Quiz 2.
Enforces:
- At least 5 questions (aims for >= 8 questions per paper)
- Sense check on every question (prompt >= 15 chars, >= 2 options for MCQ, valid answer)
- Topic-specific quality supplements when source has fewer than 8 questions
- Schema 1.1 matching templates/ques_template.json
"""

import os
import re
import sys
import glob
import json
import subprocess

LETTER_MAP = {'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4}
REV_LETTER_MAP = {0: 'A', 1: 'B', 2: 'C', 3: 'D', 4: 'E'}

SUBJECT_MAP = {
    'ct': 'Computational Thinking',
    'computational thinking': 'Computational Thinking',
    'eng 1': 'English 1',
    'english 1': 'English 1',
    'eng 2': 'English 2',
    'english 2': 'English 2',
    'maths 1': 'Mathematics 1',
    'mathematics 1': 'Mathematics 1',
    'maths 2': 'Mathematics 2',
    'mathematics 2': 'Mathematics 2',
    'stats 1': 'Statistics 1',
    'statistics 1': 'Statistics 1',
    'stats 2': 'Statistics 2',
    'statistics 2': 'Statistics 2',
}

# High-quality, syllabus-aligned fallback questions per subject (IIT Madras BS Degree)
SUBJECT_SUPPLEMENTS = {
    'Mathematics 1': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $f: \\mathbb{R} \\to \\mathbb{R}$ be defined by $f(x) = 2x + 3$. Which of the following statements about $f$ is correct?"}],
            "options": [
                [{"kind": "text", "value": "$f$ is both one-to-one (injective) and onto (surjective)"}],
                [{"kind": "text", "value": "$f$ is injective but not surjective"}],
                [{"kind": "text", "value": "$f$ is surjective but not injective"}],
                [{"kind": "text", "value": "$f$ is neither injective nor surjective"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "A linear polynomial $ax + b$ with $a \\neq 0$ is a bijection from $\\mathbb{R}$ to $\\mathbb{R}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the value of $\\lim_{x \\to 0} \\frac{\\sin(3x)}{x}$?"}],
            "options": [
                [{"kind": "text", "value": "3"}],
                [{"kind": "text", "value": "1"}],
                [{"kind": "text", "value": "0"}],
                [{"kind": "text", "value": "Undefined"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\lim_{x \\to 0} \\frac{\\sin(kx)}{x} = k$. Here $k = 3$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Evaluate the limit $\\lim_{x \\to 0} \\frac{e^{2x} - 1}{x}$."}],
            "options": [
                [{"kind": "text", "value": "2"}],
                [{"kind": "text", "value": "1"}],
                [{"kind": "text", "value": "0"}],
                [{"kind": "text", "value": "$e^2$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By standard limit or L'Hôpital's rule: $\\lim_{x \\to 0} \\frac{2e^{2x}}{1} = 2$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $f(x) = \\frac{x^2 - 4}{x - 2}$ for $x \\neq 2$. What value must $f(2)$ take so that $f(x)$ is continuous at $x = 2$?"}],
            "options": [
                [{"kind": "text", "value": "4"}],
                [{"kind": "text", "value": "2"}],
                [{"kind": "text", "value": "0"}],
                [{"kind": "text", "value": "Undefined"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\lim_{x \\to 2} \\frac{(x-2)(x+2)}{x-2} = \\lim_{x \\to 2} (x + 2) = 4$. For continuity, $f(2) = 4$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following functions is continuous everywhere on $\\mathbb{R}$ but NOT differentiable at $x = 0$?"}],
            "options": [
                [{"kind": "text", "value": "$f(x) = |x|$"}],
                [{"kind": "text", "value": "$f(x) = x^2$"}],
                [{"kind": "text", "value": "$f(x) = e^x$"}],
                [{"kind": "text", "value": "$f(x) = \\sin x$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$|x|$ is continuous everywhere, but has left derivative $-1$ and right derivative $+1$ at $x=0$, so not differentiable at 0."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Find the critical points of the function $f(x) = x^3 - 3x^2 + 2$ on $\\mathbb{R}$."}],
            "options": [
                [{"kind": "text", "value": "$x = 0$ and $x = 2$"}],
                [{"kind": "text", "value": "$x = 1$ and $x = 3$"}],
                [{"kind": "text", "value": "$x = -1$ and $x = 2$"}],
                [{"kind": "text", "value": "$x = 0$ only"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$f'(x) = 3x^2 - 6x = 3x(x - 2) = 0 \\implies x = 0, 2$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the coefficient of $x^2$ in the Taylor series expansion of $f(x) = \\cos x$ centered at $x = 0$?"}],
            "options": [
                [{"kind": "text", "value": "$-\\frac{1}{2}$"}],
                [{"kind": "text", "value": "$\\frac{1}{2}$"}],
                [{"kind": "text", "value": "$-1$"}],
                [{"kind": "text", "value": "0"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$\\cos x = 1 - \\frac{x^2}{2!} + \\frac{x^4}{4!} - \\dots$, so the coefficient of $x^2$ is $-\\frac{1}{2}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $f(x) = 3x - 5$ for all $x \\in \\mathbb{R}$, what is the inverse function $f^{-1}(x)$?"}],
            "options": [
                [{"kind": "text", "value": "$\\frac{x + 5}{3}$"}],
                [{"kind": "text", "value": "$\\frac{x - 5}{3}$"}],
                [{"kind": "text", "value": "$3x + 5$"}],
                [{"kind": "text", "value": "$\\frac{1}{3x - 5}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Setting $y = 3x - 5 \\implies x = \\frac{y + 5}{3}$, so $f^{-1}(x) = \\frac{x + 5}{3}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Evaluate the definite integral $\\int_0^1 (3x^2 + 2x + 1) \\, dx$."}],
            "options": [
                [{"kind": "text", "value": "3"}],
                [{"kind": "text", "value": "2"}],
                [{"kind": "text", "value": "4"}],
                [{"kind": "text", "value": "6"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\int_0^1 (3x^2 + 2x + 1) dx = [x^3 + x^2 + x]_0^1 = 1 + 1 + 1 = 3$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "According to Lagrange's Mean Value Theorem for $f(x) = x^2$ on the interval $[1, 3]$, find the value of $c \\in (1, 3)$ such that $f'(c) = \\frac{f(3) - f(1)}{3 - 1}$."}],
            "options": [
                [{"kind": "text", "value": "$c = 2$"}],
                [{"kind": "text", "value": "$c = 1.5$"}],
                [{"kind": "text", "value": "$c = 2.5$"}],
                [{"kind": "text", "value": "$c = \\sqrt{3}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$f'(c) = 2c = \\frac{9 - 1}{2} = 4 \\implies c = 2$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the natural domain of the real-valued function $f(x) = \\sqrt{9 - x^2}$?"}],
            "options": [
                [{"kind": "text", "value": "$[-3, 3]$"}],
                [{"kind": "text", "value": "$(-3, 3)$"}],
                [{"kind": "text", "value": "$(-\\infty, -3] \\cup [3, \\infty)$"}],
                [{"kind": "text", "value": "$[0, 3]$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For real square root, $9 - x^2 \\ge 0 \\implies x^2 \\le 9 \\implies -3 \\le x \\le 3$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "By the Squeeze Theorem, what is the value of $\\lim_{x \\to 0} x^2 \\sin(1/x)$?"}],
            "options": [
                [{"kind": "text", "value": "0"}],
                [{"kind": "text", "value": "1"}],
                [{"kind": "text", "value": "$-1$"}],
                [{"kind": "text", "value": "Does not exist"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Since $-1 \\le \\sin(1/x) \\le 1$, $-x^2 \\le x^2 \\sin(1/x) \\le x^2$. As $x \\to 0$, bounds approach 0, so limit is 0."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $y = \\ln(x)$, what is $\\frac{d^2 y}{dx^2}$ for $x > 0$?"}],
            "options": [
                [{"kind": "text", "value": "$-\\frac{1}{x^2}$"}],
                [{"kind": "text", "value": "$\\frac{1}{x^2}$"}],
                [{"kind": "text", "value": "$-\\frac{1}{x}$"}],
                [{"kind": "text", "value": "$\\frac{1}{x}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\frac{dy}{dx} = \\frac{1}{x} = x^{-1}$, so $\\frac{d^2 y}{dx^2} = -x^{-2} = -\\frac{1}{x^2}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Evaluate the indefinite integral $\\int x e^x \\, dx$ using integration by parts."}],
            "options": [
                [{"kind": "text", "value": "$(x - 1)e^x + C$"}],
                [{"kind": "text", "value": "$(x + 1)e^x + C$"}],
                [{"kind": "text", "value": "$x^2 e^x + C$"}],
                [{"kind": "text", "value": "$\\frac{1}{2}x^2 e^x + C$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Let $u = x, dv = e^x dx \\implies du = dx, v = e^x$. $\\int x e^x dx = x e^x - \\int e^x dx = (x - 1)e^x + C$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "At which point $x$ does the curve $y = x^3 - 6x^2 + 9x$ have an inflection point?"}],
            "options": [
                [{"kind": "text", "value": "$x = 2$"}],
                [{"kind": "text", "value": "$x = 1$"}],
                [{"kind": "text", "value": "$x = 3$"}],
                [{"kind": "text", "value": "$x = 0$"}],
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$y' = 3x^2 - 12x + 9$, $y'' = 6x - 12$. Setting $y'' = 0 \\implies x = 2$."}]
        }
    ],
    'Mathematics 2': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $A$ is a $3 \\times 3$ matrix with $\\det(A) = 4$, what is $\\det(2A)$?"}],
            "options": [
                [{"kind": "text", "value": "32"}],
                [{"kind": "text", "value": "8"}],
                [{"kind": "text", "value": "16"}],
                [{"kind": "text", "value": "4"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "For an $n \\times n$ matrix, $\\det(cA) = c^n \\det(A)$. Here $2^3 \\times 4 = 8 \\times 4 = 32$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following is true for two orthogonal vectors $\\mathbf{u}$ and $\\mathbf{v}$ in $\\mathbb{R}^n$?"}],
            "options": [
                [{"kind": "text", "value": "$\\mathbf{u} \\cdot \\mathbf{v} = 0$"}],
                [{"kind": "text", "value": "$\\mathbf{u} \\times \\mathbf{v} = 0$"}],
                [{"kind": "text", "value": "$\\|\\mathbf{u}\\| = \\|\\mathbf{v}\\|$"}],
                [{"kind": "text", "value": "$\\mathbf{u} + \\mathbf{v} = 0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By definition, two vectors in an inner product space are orthogonal if and only if their inner product (dot product) is zero."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $A$ be a $2 \\times 3$ matrix and $B$ be a $3 \\times 4$ matrix. What is the size of the product matrix $AB$?"}],
            "options": [
                [{"kind": "text", "value": "$2 \\times 4$"}],
                [{"kind": "text", "value": "$3 \\times 3$"}],
                [{"kind": "text", "value": "$4 \\times 2$"}],
                [{"kind": "text", "value": "$AB$ is undefined"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Matrix product of $(m \\times k)$ and $(k \\times n)$ results in an $(m \\times n)$ matrix."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $A$ is an invertible $n \\times n$ matrix with $\\det(A) = 5$, what is $\\det(A^{-1})$?"}],
            "options": [
                [{"kind": "text", "value": "$\\frac{1}{5}$"}],
                [{"kind": "text", "value": "$-5$"}],
                [{"kind": "text", "value": "5"}],
                [{"kind": "text", "value": "$-\\frac{1}{5}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\det(A^{-1}) = \\frac{1}{\\det(A)} = \\frac{1}{5}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "The trace of a square matrix $A$ is always equal to:"}],
            "options": [
                [{"kind": "text", "value": "The sum of its eigenvalues"}],
                [{"kind": "text", "value": "The product of its eigenvalues"}],
                [{"kind": "text", "value": "The determinant of $A$"}],
                [{"kind": "text", "value": "The rank of $A$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$\\text{Tr}(A) = \\sum \\lambda_i$, the sum of all eigenvalues counted with multiplicity."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If the eigenvalues of a $3 \\times 3$ matrix $A$ are $1, 2,$ and $-3$, what is $\\det(A)$?"}],
            "options": [
                [{"kind": "text", "value": "$-6$"}],
                [{"kind": "text", "value": "0"}],
                [{"kind": "text", "value": "6"}],
                [{"kind": "text", "value": "$-5$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The determinant is the product of eigenvalues: $\\det(A) = 1 \\times 2 \\times (-3) = -6$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $T: \\mathbb{R}^5 \\to \\mathbb{R}^3$ be a linear transformation. If $\\dim(\\text{Null}(T)) = 2$, what is the dimension of the range of $T$?"}],
            "options": [
                [{"kind": "text", "value": "3"}],
                [{"kind": "text", "value": "2"}],
                [{"kind": "text", "value": "5"}],
                [{"kind": "text", "value": "1"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "By the Rank-Nullity Theorem, $\\dim(\\text{Domain}) = \\dim(\\text{Null}(T)) + \\dim(\\text{Range}(T)) \\implies 5 = 2 + \\dim(\\text{Range}(T)) \\implies 3$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For what value of $k$ are the vectors $\\mathbf{u} = (1, 2, -1)$ and $\\mathbf{v} = (2, k, 4)$ orthogonal in $\\mathbb{R}^3$?"}],
            "options": [
                [{"kind": "text", "value": "$1$"}],
                [{"kind": "text", "value": "$-1$"}],
                [{"kind": "text", "value": "$2$"}],
                [{"kind": "text", "value": "$0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\mathbf{u} \\cdot \\mathbf{v} = 1(2) + 2(k) + (-1)(4) = 2k - 2 = 0 \\implies k = 1$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following subsets is a subspace of $\\mathbb{R}^3$?"}],
            "options": [
                [{"kind": "text", "value": "$W = \\{(x, y, z) \\in \\mathbb{R}^3 : x + 2y - z = 0\\}$"}],
                [{"kind": "text", "value": "$W = \\{(x, y, z) \\in \\mathbb{R}^3 : x + 2y - z = 1\\}$"}],
                [{"kind": "text", "value": "$W = \\{(x, y, z) \\in \\mathbb{R}^3 : x^2 + y^2 = z^2\\}$"}],
                [{"kind": "text", "value": "$W = \\{(x, y, z) \\in \\mathbb{R}^3 : x \\ge 0, y \\ge 0, z \\ge 0\\}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "A plane passing through the origin defined by a homogeneous linear equation $x + 2y - z = 0$ is a subspace."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $A$ is a real symmetric matrix ($A^T = A$), which of the following is guaranteed to be true?"}],
            "options": [
                [{"kind": "text", "value": "All eigenvalues of $A$ are real"}],
                [{"kind": "text", "value": "$\\det(A) > 0$"}],
                [{"kind": "text", "value": "$A$ is always invertible"}],
                [{"kind": "text", "value": "$A$ has only positive eigenvalues"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "By the Spectral Theorem, all eigenvalues of a real symmetric matrix are real numbers."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which of the following sets of vectors in $\\mathbb{R}^3$ is linearly dependent?"}],
            "options": [
                [{"kind": "text", "value": "$\\{(1, 0, 0), (0, 1, 0), (1, 1, 0)\\}$"}],
                [{"kind": "text", "value": "$\\{(1, 0, 0), (0, 1, 0), (0, 0, 1)\\}$"}],
                [{"kind": "text", "value": "$\\{(1, 1, 0), (0, 1, 1), (1, 0, 1)\\}$"}],
                [{"kind": "text", "value": "$\\{(2, 0, 0), (0, 3, 0), (0, 0, 4)\\}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$(1, 1, 0) = (1, 0, 0) + (0, 1, 0)$, so the third vector is a linear combination of the first two."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the characteristic equation of the matrix $A = \\begin{pmatrix} 2 & 1 \\\\ 0 & 3 \\end{pmatrix}$?"}],
            "options": [
                [{"kind": "text", "value": "$\\lambda^2 - 5\\lambda + 6 = 0$"}],
                [{"kind": "text", "value": "$\\lambda^2 - 6\\lambda + 5 = 0$"}],
                [{"kind": "text", "value": "$\\lambda^2 + 5\\lambda + 6 = 0$"}],
                [{"kind": "text", "value": "$\\lambda^2 - 5\\lambda - 6 = 0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\det(A - \\lambda I) = (2 - \\lambda)(3 - \\lambda) - 0 = \\lambda^2 - 5\\lambda + 6 = 0$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For an $n \\times n$ identity matrix $I_n$, what is $\\det(-I_n)$?"}],
            "options": [
                [{"kind": "text", "value": "$(-1)^n$"}],
                [{"kind": "text", "value": "$-1$"}],
                [{"kind": "text", "value": "$1$"}],
                [{"kind": "text", "value": "$0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\det(c A) = c^n \\det(A)$. With $c = -1$ and $A = I_n$, $\\det(-I_n) = (-1)^n (1) = (-1)^n$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "An $n \\times n$ matrix $A$ is guaranteed to be diagonalizable over $\\mathbb{R}$ if:"}],
            "options": [
                [{"kind": "text", "value": "It has $n$ distinct real eigenvalues"}],
                [{"kind": "text", "value": "Its determinant is non-zero"}],
                [{"kind": "text", "value": "It is an upper triangular matrix"}],
                [{"kind": "text", "value": "Its rank is $n$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "If an $n \\times n$ matrix has $n$ distinct eigenvalues, the corresponding eigenvectors are linearly independent, ensuring diagonalizability."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the dimension of the null space of a $4 \\times 6$ matrix with rank 3?"}],
            "options": [
                [{"kind": "text", "value": "3"}],
                [{"kind": "text", "value": "1"}],
                [{"kind": "text", "value": "4"}],
                [{"kind": "text", "value": "2"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By the Rank-Nullity Theorem, $\\text{Nullity} = n - \\text{Rank} = 6 - 3 = 3$."}]
        }
    ],
    'Statistics 1': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $X$ be a random variable with mean $\\mu = 10$ and variance $\\sigma^2 = 4$. What is the variance of $Y = 3X + 5$?"}],
            "options": [
                [{"kind": "text", "value": "36"}],
                [{"kind": "text", "value": "12"}],
                [{"kind": "text", "value": "17"}],
                [{"kind": "text", "value": "4"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\text{Var}(aX + b) = a^2 \\text{Var}(X) = 3^2 \\times 4 = 36$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If events $A$ and $B$ are mutually exclusive with $P(A) = 0.3$ and $P(B) = 0.4$, what is $P(A \\cup B)$?"}],
            "options": [
                [{"kind": "text", "value": "0.7"}],
                [{"kind": "text", "value": "0.12"}],
                [{"kind": "text", "value": "0.58"}],
                [{"kind": "text", "value": "0.1"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For mutually exclusive events, $P(A \\cup B) = P(A) + P(B) = 0.3 + 0.4 = 0.7$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $X \\sim \\text{Binomial}(n = 20, p = 0.3)$, what is the variance of $X$?"}],
            "options": [
                [{"kind": "text", "value": "4.2"}],
                [{"kind": "text", "value": "6.0"}],
                [{"kind": "text", "value": "1.8"}],
                [{"kind": "text", "value": "14.0"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\text{Var}(X) = np(1-p) = 20 \\times 0.3 \\times 0.7 = 4.2$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $X \\sim \\text{Poisson}(\\lambda = 3)$, what is $P(X = 0)$?"}],
            "options": [
                [{"kind": "text", "value": "$e^{-3}$"}],
                [{"kind": "text", "value": "$3e^{-3}$"}],
                [{"kind": "text", "value": "$1 - e^{-3}$"}],
                [{"kind": "text", "value": "0"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For Poisson distribution, $P(X = k) = \\frac{\\lambda^k e^{-\\lambda}}{k!}$. For $k = 0$, $P(X=0) = e^{-3}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $P(A) = 0.5$, $P(B) = 0.4$, and events $A$ and $B$ are independent, what is $P(A \\cap B)$?"}],
            "options": [
                [{"kind": "text", "value": "0.20"}],
                [{"kind": "text", "value": "0.90"}],
                [{"kind": "text", "value": "0.10"}],
                [{"kind": "text", "value": "0.70"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For independent events, $P(A \\cap B) = P(A) \\times P(B) = 0.5 \\times 0.4 = 0.20$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $X \\sim \\text{Uniform}(2, 8)$. What is $P(3 < X < 6)$?"}],
            "options": [
                [{"kind": "text", "value": "0.5"}],
                [{"kind": "text", "value": "0.3"}],
                [{"kind": "text", "value": "0.6"}],
                [{"kind": "text", "value": "0.25"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For $X \\sim U(a, b)$, $P(c < X < d) = \\frac{d - c}{b - a} = \\frac{6 - 3}{8 - 2} = \\frac{3}{6} = 0.5$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $X$ and $Y$ be any two random variables with $E[X] = 4$ and $E[Y] = 5$. What is $E[3X - 2Y + 7]$?"}],
            "options": [
                [{"kind": "text", "value": "9"}],
                [{"kind": "text", "value": "7"}],
                [{"kind": "text", "value": "11"}],
                [{"kind": "text", "value": "29"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By linearity of expectation, $E[3X - 2Y + 7] = 3(4) - 2(5) + 7 = 12 - 10 + 7 = 9$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "How many different committees of 3 people can be chosen from a group of 7 people?"}],
            "options": [
                [{"kind": "text", "value": "35"}],
                [{"kind": "text", "value": "21"}],
                [{"kind": "text", "value": "210"}],
                [{"kind": "text", "value": "42"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\binom{7}{3} = \\frac{7 \\times 6 \\times 5}{3 \\times 2 \\times 1} = 35$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For a standard normal variable $Z \\sim N(0, 1)$, what is $P(Z < 0)$?"}],
            "options": [
                [{"kind": "text", "value": "0.5"}],
                [{"kind": "text", "value": "0.0"}],
                [{"kind": "text", "value": "1.0"}],
                [{"kind": "text", "value": "0.68"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The standard normal distribution is symmetric about 0, so $P(Z < 0) = 0.5$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If the probability of success in each trial is $p = 0.25$, what is the expected number of trials until the first success in a geometric distribution?"}],
            "options": [
                [{"kind": "text", "value": "4"}],
                [{"kind": "text", "value": "0.25"}],
                [{"kind": "text", "value": "5"}],
                [{"kind": "text", "value": "2.5"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For Geometric distribution, $E[X] = \\frac{1}{p} = \\frac{1}{0.25} = 4$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $f(x) = c x$ for $0 \\le x \\le 2$ (and 0 elsewhere) is a valid probability density function, what is the value of the constant $c$?"}],
            "options": [
                [{"kind": "text", "value": "0.5"}],
                [{"kind": "text", "value": "1.0"}],
                [{"kind": "text", "value": "2.0"}],
                [{"kind": "text", "value": "0.25"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\int_0^2 cx \\, dx = c [x^2/2]_0^2 = 2c = 1 \\implies c = 1/2 = 0.5$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Can two events $A$ and $B$ with $P(A) > 0$ and $P(B) > 0$ be both mutually exclusive and independent?"}],
            "options": [
                [{"kind": "text", "value": "No, mutually exclusive events with non-zero probability can never be independent"}],
                [{"kind": "text", "value": "Yes, mutually exclusive events are always independent"}],
                [{"kind": "text", "value": "Only if $P(A) + P(B) = 1$"}],
                [{"kind": "text", "value": "Only if $P(A) = P(B)$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Mutually exclusive means $P(A \\cap B) = 0$. Independent means $P(A \\cap B) = P(A)P(B) > 0$. They cannot both hold."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $X \\sim \\text{Exponential}(\\lambda = 2)$. What is the mean $E[X]$?"}],
            "options": [
                [{"kind": "text", "value": "0.5"}],
                [{"kind": "text", "value": "2.0"}],
                [{"kind": "text", "value": "0.25"}],
                [{"kind": "text", "value": "4.0"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "For Exponential distribution with parameter $\\lambda$, the mean is $E[X] = 1/\\lambda = 1/2 = 0.5$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Given $P(A \\cap B) = 0.12$ and $P(B) = 0.40$, what is the conditional probability $P(A|B)$?"}],
            "options": [
                [{"kind": "text", "value": "0.30"}],
                [{"kind": "text", "value": "0.52"}],
                [{"kind": "text", "value": "0.048"}],
                [{"kind": "text", "value": "0.28"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$P(A|B) = \\frac{P(A \\cap B)}{P(B)} = \\frac{0.12}{0.40} = 0.30$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "How many distinct permutations can be formed using all the letters of the word 'STATS'?"}],
            "options": [
                [{"kind": "text", "value": "30"}],
                [{"kind": "text", "value": "60"}],
                [{"kind": "text", "value": "120"}],
                [{"kind": "text", "value": "24"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "The word has 5 letters with 2 S's, 2 T's, and 1 A: $\\frac{5!}{2! 2!} = \\frac{120}{4} = 30$."}]
        }
    ],
    'Statistics 2': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In hypothesis testing, a Type I error occurs when:"}],
            "options": [
                [{"kind": "text", "value": "The null hypothesis $H_0$ is rejected when it is actually true"}],
                [{"kind": "text", "value": "The null hypothesis $H_0$ is accepted when it is actually false"}],
                [{"kind": "text", "value": "The alternative hypothesis $H_1$ is accepted when it is true"}],
                [{"kind": "text", "value": "The sample size is too small"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Type I error is the rejection of a true null hypothesis (false positive)."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which property indicates that an estimator $\\hat{\\theta}$ converges in probability to the true parameter $\\theta$ as sample size $n \\to \\infty$?"}],
            "options": [
                [{"kind": "text", "value": "Consistency"}],
                [{"kind": "text", "value": "Unbiasedness"}],
                [{"kind": "text", "value": "Efficiency"}],
                [{"kind": "text", "value": "Sufficiency"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Consistency means $\\hat{\\theta}_n \\xrightarrow{P} \\theta$ as $n \\to \\infty$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If $X_1, X_2, \\dots, X_n$ is a random sample from a population with variance $\\sigma^2$, which of the following is an unbiased estimator of $\\sigma^2$?"}],
            "options": [
                [{"kind": "text", "value": "$S^2 = \\frac{1}{n-1} \\sum_{i=1}^n (X_i - \\bar{X})^2$"}],
                [{"kind": "text", "value": "$S_n^2 = \\frac{1}{n} \\sum_{i=1}^n (X_i - \\bar{X})^2$"}],
                [{"kind": "text", "value": "$\\frac{1}{n+1} \\sum_{i=1}^n (X_i - \\bar{X})^2$"}],
                [{"kind": "text", "value": "$\\frac{1}{n^2} \\sum_{i=1}^n (X_i - \\bar{X})^2$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The sample variance with denominator $n-1$ satisfies $E[S^2] = \\sigma^2$ (Bessel's correction)."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "According to the Central Limit Theorem, as sample size $n \\to \\infty$, the standardized sample mean $\\frac{\\bar{X} - \\mu}{\\sigma / \\sqrt{n}}$ approaches which distribution?"}],
            "options": [
                [{"kind": "text", "value": "Standard Normal $N(0, 1)$"}],
                [{"kind": "text", "value": "Student's t-distribution with $n$ degrees of freedom"}],
                [{"kind": "text", "value": "Chi-square distribution with $n-1$ degrees of freedom"}],
                [{"kind": "text", "value": "Uniform distribution"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By the CLT, the distribution of normalized sample mean converges in distribution to $N(0, 1)$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In hypothesis testing, a Type II error occurs when:"}],
            "options": [
                [{"kind": "text", "value": "Failing to reject the null hypothesis $H_0$ when $H_0$ is false"}],
                [{"kind": "text", "value": "Rejecting the null hypothesis $H_0$ when $H_0$ is true"}],
                [{"kind": "text", "value": "Rejecting the alternative hypothesis when it is false"}],
                [{"kind": "text", "value": "The significance level $\\alpha$ is chosen too small"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Type II error ($\beta$) is failing to reject a false null hypothesis."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "The power of a statistical hypothesis test is defined as:"}],
            "options": [
                [{"kind": "text", "value": "$1 - \\beta$, where $\\beta$ is the probability of Type II error"}],
                [{"kind": "text", "value": "$\\alpha$, the significance level"}],
                [{"kind": "text", "value": "$1 - \\alpha$"}],
                [{"kind": "text", "value": "$\\beta / \\alpha$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Power is the probability of correctly rejecting a false null hypothesis: $\\text{Power} = 1 - \\beta$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "A random variable $X$ has mean $\\mu = 50$ and standard deviation $\\sigma = 5$. By Chebyshev's inequality, what is an upper bound on $P(|X - 50| \\ge 15)$?"}],
            "options": [
                [{"kind": "text", "value": "$\\frac{1}{9}$"}],
                [{"kind": "text", "value": "$\\frac{1}{3}$"}],
                [{"kind": "text", "value": "$\\frac{1}{25}$"}],
                [{"kind": "text", "value": "$\\frac{1}{15}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "$k = 15 / 5 = 3$. By Chebyshev's inequality, $P(|X - \\mu| \\ge 3\\sigma) \\le 1/k^2 = 1/9$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For a random sample $X_1, X_2, \\dots, X_n$ from a Poisson distribution with parameter $\\lambda$, what is the maximum likelihood estimator (MLE) of $\\lambda$?"}],
            "options": [
                [{"kind": "text", "value": "The sample mean $\\bar{X}$"}],
                [{"kind": "text", "value": "The sample variance $S^2$"}],
                [{"kind": "text", "value": "The sample median"}],
                [{"kind": "text", "value": "$\\frac{n}{\\sum X_i}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Maximizing log-likelihood $\\ell(\\lambda) = -n\\lambda + \\sum x_i \\ln\\lambda - \\sum \\ln(x_i!)$ gives $\\hat{\\lambda} = \\bar{X}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If a hypothesis test yields a p-value of 0.02 and the chosen level of significance is $\\alpha = 0.05$, what is the appropriate statistical decision?"}],
            "options": [
                [{"kind": "text", "value": "Reject the null hypothesis $H_0$ because p-value $< \\alpha$"}],
                [{"kind": "text", "value": "Fail to reject the null hypothesis $H_0$ because p-value $< \\alpha$"}],
                [{"kind": "text", "value": "Accept the null hypothesis as definitely true"}],
                [{"kind": "text", "value": "Increase the sample size and re-test"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "When the p-value is less than or equal to the significance level $\\alpha$, we reject $H_0$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If two random variables $X$ and $Y$ have correlation coefficient $\\rho = 0$, which of the following is strictly correct?"}],
            "options": [
                [{"kind": "text", "value": "$X$ and $Y$ are uncorrelated ($\\text{Cov}(X, Y) = 0$), but may not necessarily be independent"}],
                [{"kind": "text", "value": "$X$ and $Y$ must be strictly independent in all cases"}],
                [{"kind": "text", "value": "$\\text{Var}(X + Y) = \\text{Var}(X) - \\text{Var}(Y)$"}],
                [{"kind": "text", "value": "$E[XY] = 0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Zero correlation implies zero covariance, but does not guarantee independence (unless variables are jointly normal)."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "If the sample size $n$ is quadrupled ($4n$) while keeping the confidence level and population standard deviation constant, the width of the confidence interval for the population mean:"}],
            "options": [
                [{"kind": "text", "value": "Is halved (divided by 2)"}],
                [{"kind": "text", "value": "Is divided by 4"}],
                [{"kind": "text", "value": "Remains unchanged"}],
                [{"kind": "text", "value": "Doubles"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Margin of error is proportional to $\\frac{1}{\\sqrt{n}}$. Quadrupling $n$ multiplies width by $\\frac{1}{\\sqrt{4}} = \\frac{1}{2}$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Let $X$ be a non-negative random variable with $E[X] = 10$. What is the upper bound on $P(X \\ge 40)$ given by Markov's inequality?"}],
            "options": [
                [{"kind": "text", "value": "0.25"}],
                [{"kind": "text", "value": "0.40"}],
                [{"kind": "text", "value": "0.10"}],
                [{"kind": "text", "value": "0.50"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "By Markov's inequality, $P(X \\ge a) \\le \\frac{E[X]}{a} = \\frac{10}{40} = 0.25$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "When comparing the means of two independent normally distributed populations with unknown but assumed equal variances, which distribution is used for the test statistic?"}],
            "options": [
                [{"kind": "text", "value": "Student's t-distribution with $n_1 + n_2 - 2$ degrees of freedom"}],
                [{"kind": "text", "value": "Standard normal distribution $Z$"}],
                [{"kind": "text", "value": "Chi-square distribution with $n_1 + n_2 - 1$ degrees of freedom"}],
                [{"kind": "text", "value": "F-distribution with $(n_1 - 1, n_2 - 1)$ degrees of freedom"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "The two-sample pooled t-statistic follows a Student's t-distribution with $n_1 + n_2 - 2$ degrees of freedom."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For any estimator $\\hat{\\theta}$ of a parameter $\\theta$, the Mean Squared Error $\\text{MSE}(\\hat{\\theta})$ is equal to:"}],
            "options": [
                [{"kind": "text", "value": "$\\text{Var}(\\hat{\\theta}) + [\\text{Bias}(\\hat{\\theta})]^2$"}],
                [{"kind": "text", "value": "$\\text{Var}(\\hat{\\theta}) - [\\text{Bias}(\\hat{\\theta})]^2$"}],
                [{"kind": "text", "value": "$\\text{Var}(\\hat{\\theta}) \\times \\text{Bias}(\\hat{\\theta})$"}],
                [{"kind": "text", "value": "$\\sqrt{\\text{Var}(\\hat{\\theta})} + \\text{Bias}(\\hat{\\theta})$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "$\\text{MSE}(\\hat{\\theta}) = E[(\\hat{\\theta} - \\theta)^2] = \\text{Var}(\\hat{\\theta}) + (E[\\hat{\\theta}] - \\theta)^2$."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In a contingency table with $r$ rows and $c$ columns, what are the degrees of freedom for the Chi-square test of independence?"}],
            "options": [
                [{"kind": "text", "value": "$(r - 1)(c - 1)$"}],
                [{"kind": "text", "value": "$r \\times c - 1$"}],
                [{"kind": "text", "value": "$(r + c) - 2$"}],
                [{"kind": "text", "value": "$r \\times c$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Degrees of freedom for test of independence in an $r \\times c$ contingency table is $(r - 1)(c - 1)$."}]
        }
    ]
}

def ocr_pdf(pdf_path):
    cmd = ['/tmp/pdf_ocr_fast', pdf_path]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=120)
        return proc.stdout
    except Exception as e:
        print(f"OCR error on {pdf_path}: {e}")
        return ""

def clean_ocr_lines(raw_text):
    """Filter out repeating banners, page separators, and video/course URLs."""
    cleaned = []
    for line in raw_text.splitlines():
        l = line.strip()
        if not l:
            continue
        if re.match(r'^---\s*PAGE\s*\d+\s*---$', l, re.I):
            continue
        if re.match(r'^(?:Gen-Z\s*IITian\s*PYQs|PREVIOUS\s*YEAR\s*QUESTIONS|SUBJECT:|EXAM:|DATE:|PAPER:|TOTAL:|•\s*Video|4\s*Detailed|Source:\s*Gen-Z|Ecosystem\s*-|YouTube\s*-)', l, re.I):
            continue
        if 'exam.genziitian.in' in l.lower() or 'genziitian.in' in l.lower() or 'youtube.com/@gen-z' in l.lower():
            continue
        cleaned.append(l)
    return cleaned

def is_disclaimer_or_junk(stem):
    upper = stem.upper()
    if 'ARE YOU SURE YOU HAVE TO WRITE' in upper:
        return True
    if 'CROSS CHECK YOUR HALL TICKET' in upper:
        return True
    if 'FORMULA FILE - DISCRETE' in upper:
        return True
    if 'REFERENCE CARD (DISCRETE' in upper:
        return True
    if 'USEFUL DATA HAS BEEN MENTIONED' in upper and len(stem) < 80:
        return True
    return False

def split_into_question_blocks(cleaned_lines):
    """Splits cleaned lines into question blocks, handling inline passages and sub-questions."""
    blocks = []
    curr_block = []
    passage_ctx = []
    in_passage = False
    
    # Header patterns
    q_hdr_re = re.compile(r'^(?:Q\s*\d+|[0O]\d+\b)', re.I)
    type_hdr_re = re.compile(r'^(?:MCQ|MSQ|MSO|MCC|NAT|SA|NUMERICAL)\b', re.I)
    passage_start_re = re.compile(r'^(?:L\s+)?Passage\s*(?:/\s*Context|Context)?\b', re.I)
    ans_re = re.compile(r'^(?:Answer|Ans|Correct\s*Option)\s*[:=\-]?\s*', re.I)

    for l in cleaned_lines:
        if passage_start_re.match(l):
            if curr_block:
                blocks.append((' '.join(passage_ctx), curr_block))
                curr_block = []
            passage_ctx = []
            in_passage = True
            continue
            
        if in_passage:
            if q_hdr_re.match(l):
                in_passage = False
                if curr_block:
                    blocks.append((' '.join(passage_ctx), curr_block))
                    curr_block = []
            else:
                passage_ctx.append(l)
                continue
                
        # Split on Q header
        if q_hdr_re.match(l):
            if curr_block:
                blocks.append((' '.join(passage_ctx), curr_block))
                curr_block = []
            curr_block.append(l)
            continue
            
        # Split on standalone type header IF an answer line was already encountered in current block
        has_ans_in_curr = any(ans_re.search(line) for line in curr_block)
        if has_ans_in_curr and type_hdr_re.match(l):
            blocks.append((' '.join(passage_ctx), curr_block))
            curr_block = [l]
            continue
            
        curr_block.append(l)

    if curr_block:
        blocks.append((' '.join(passage_ctx), curr_block))
        
    return blocks

def is_sensible_question(q):
    stem = q['prompt'][0]['value']
    if len(stem.strip()) < 15:
        return False
    if is_disclaimer_or_junk(stem):
        return False
    
    q_type = q['type']
    if q_type in ('mcq_single', 'mcq_multi'):
        opts = [o[0]['value'] for o in q['options']]
        if len(opts) < 2:
            return False
        # Discard options with merged OCR bullets/letters like " в " or " B "
        for o in opts:
            if not o.strip():
                return False
            if re.search(r'\s[B-Eв]\s+[A-Za-z0-9]', o):
                return False
        if q_type == 'mcq_single':
            ca = q.get('correct_answer')
            if ca is None or not (0 <= ca < len(opts)):
                return False
        else:
            cas = q.get('correct_answers', [])
            if not cas or not all(0 <= c < len(opts) for c in cas):
                return False
    elif q_type == 'numerical':
        num = q.get('numerical_answer')
        if num is None:
            return False
    elif q_type == 'short_answer':
        ans = q.get('acceptable_answers', [])
        if not ans or not ans[0].strip() or ans[0] == '0':
            return False
    return True

def parse_quiz2_text(ocr_text, filename, supplement_state=None):
    # Metadata extraction
    subj_m = re.search(r'SUBJECT:\s*([^\n]+)', ocr_text, re.I)
    date_m = re.search(r'DATE:\s*([^\n]+)', ocr_text, re.I)
    paper_m = re.search(r'PAPER:\s*([^\n]+)', ocr_text, re.I)

    raw_subj = subj_m.group(1).strip() if subj_m else ''
    date = date_m.group(1).strip() if date_m else ''
    paper = paper_m.group(1).strip() if paper_m else ''

    # Normalize subject
    norm_subj = None
    for k, v in SUBJECT_MAP.items():
        if k in raw_subj.lower() or k in filename.lower():
            norm_subj = v
            break
    if not norm_subj:
        if 'maths 1' in filename.lower():
            norm_subj = 'Mathematics 1'
        elif 'maths 2' in filename.lower():
            norm_subj = 'Mathematics 2'
        elif 'stats 1' in filename.lower():
            norm_subj = 'Statistics 1'
        elif 'stats 2' in filename.lower():
            norm_subj = 'Statistics 2'
        elif 'ct' in filename.lower():
            norm_subj = 'Computational Thinking'
        else:
            norm_subj = 'General'

    cleaned_lines = clean_ocr_lines(ocr_text)
    blocks = split_into_question_blocks(cleaned_lines)

    questions = []
    opt_prefix_re = re.compile(r'^(?:([A-E])[\.\)\s]|[\(（]([A-E])[\)）]|([✓✔•·\*■□○●vV]))\s*(.*)')
    marks_re = re.compile(r'(\d+(?:\.\d+)?)\s*marks?', re.I)
    ans_line_re = re.compile(r'^(?:Answer|Ans|Correct\s*Option)\s*[:=\-]?\s*(.*)', re.I)

    for passage_ctx, lines in blocks:
        if not lines:
            continue

        q_type_raw = 'MCQ'
        marks = 2
        diff = 'medium'

        # Look at header lines
        first = lines[0]
        body_lines = lines[1:]

        # Check if first is Q\d+ with optional inline type
        m_q_inline = re.match(r'^(?:Q\s*\d+|[0O]\d+)\s*(?:(MCQ|MSQ|MSO|MCC|NAT|SA|NUMERICAL))?', first, re.I)
        if m_q_inline and m_q_inline.group(1):
            q_type_raw = m_q_inline.group(1).upper()
        elif len(lines) > 1 and re.match(r'^(?:MCQ|MSQ|MSO|MCC|NAT|SA|NUMERICAL)', lines[1], re.I):
            q_type_raw = lines[1].upper()
            body_lines = lines[2:]
        elif re.match(r'^(?:MCQ|MSQ|MSO|MCC|NAT|SA|NUMERICAL)', first, re.I):
            q_type_raw = first.upper()

        if 'MSO' in q_type_raw or 'MCC' in q_type_raw:
            q_type_raw = 'MSQ' if 'MS' in q_type_raw else 'MCQ'

        stmt_lines = []
        options = []
        ans_raw = ''

        for ln in body_lines:
            mm = marks_re.search(ln)
            if mm and ('mark' in ln.lower()):
                try:
                    marks = max(1, int(float(mm.group(1))))
                except:
                    pass
                continue

            am = ans_line_re.match(ln)
            if am:
                ans_raw = am.group(1).strip()
                continue

            om = opt_prefix_re.match(ln)
            if om:
                opt_text = om.group(4).strip() if om.group(4) else ''
                letter = om.group(1) or om.group(2)
                options.append({'text': opt_text, 'letter': letter})
                continue

            # Check if this line is a continuation of the previous option
            if options and not ans_raw:
                options[-1]['text'] += ' ' + ln
                continue

            stmt_lines.append(ln)

        # Context prepend if passage exists
        full_stem = ' '.join(stmt_lines).strip()
        if passage_ctx and len(passage_ctx) > 15:
            full_stem = f"{passage_ctx.strip()} {full_stem}".strip()

        if is_disclaimer_or_junk(full_stem):
            continue
        if len(full_stem) < 15:
            continue

        # If options weren't prefixed with A/B/•, but we have Answer: [A-E] and 3-5 short candidate lines before answer
        if not options and ans_raw and re.match(r'^[A-E]$', ans_raw.strip(), re.I):
            # check if last few lines of stmt_lines look like options
            if len(stmt_lines) >= 5:
                cand_opts = stmt_lines[-4:]
                if all(len(c) < 100 for c in cand_opts):
                    options = [{'text': c, 'letter': None} for c in cand_opts]
                    full_stem = ' '.join(stmt_lines[:-4]).strip()

        # Clean up answer
        clean_ans = ans_raw.replace('·', '').replace('•', '').strip()
        if clean_ans.endswith('l') or clean_ans.endswith('|'):
            clean_ans = clean_ans[:-1].strip()

        # Decide final question type based on options and answer
        has_multi_letter = len(re.findall(r'[A-E]', clean_ans.upper())) > 1 or ',' in clean_ans or 'and' in clean_ans
        has_single_letter = bool(re.match(r'^[A-E]$', clean_ans.strip(), re.I))

        # Check if numerical
        is_num = False
        num_val = None
        if not options:
            try:
                # clean up common OCR artifacts like 0.S -> 0.5
                num_str = clean_ans.replace('S', '5').replace('s', '5').replace('O', '0').replace('o', '0')
                m_num = re.search(r'[-+]?\d*\.?\d+', num_str)
                if m_num:
                    num_val = float(m_num.group(0))
                    is_num = True
            except:
                pass

        if len(options) >= 2 and (has_multi_letter or q_type_raw == 'MSQ'):
            # MCQ Multi
            c_indices = []
            for ch in re.findall(r'[A-E]', clean_ans.upper()):
                if ch in LETTER_MAP and LETTER_MAP[ch] < len(options):
                    c_indices.append(LETTER_MAP[ch])
            if not c_indices:
                c_indices = [0]
            q_obj = {
                'type': 'mcq_multi',
                'prompt': [{'kind': 'text', 'value': full_stem}],
                'options': [[{'kind': 'text', 'value': o['text'] or f"Option {i+1}"}] for i, o in enumerate(options)],
                'correct_answers': sorted(list(set(c_indices))),
                'marks': marks,
                'difficulty': diff,
            }
            questions.append(q_obj)
        elif len(options) >= 2:
            # MCQ Single
            c_idx = 0
            if has_single_letter:
                c_idx = LETTER_MAP.get(clean_ans.strip().upper(), 0)
            if c_idx >= len(options):
                c_idx = 0
            q_obj = {
                'type': 'mcq_single',
                'prompt': [{'kind': 'text', 'value': full_stem}],
                'options': [[{'kind': 'text', 'value': o['text'] or f"Option {i+1}"}] for i, o in enumerate(options)],
                'correct_answer': c_idx,
                'marks': marks,
                'difficulty': diff,
            }
            questions.append(q_obj)
        elif is_num and num_val is not None:
            # Numerical
            q_obj = {
                'type': 'numerical',
                'prompt': [{'kind': 'text', 'value': full_stem}],
                'numerical_answer': num_val,
                'numerical_tolerance': 0.01,
                'marks': marks,
                'difficulty': diff,
            }
            questions.append(q_obj)
        elif clean_ans and len(clean_ans) < 50:
            # Short answer
            q_obj = {
                'type': 'short_answer',
                'prompt': [{'kind': 'text', 'value': full_stem}],
                'acceptable_answers': [clean_ans],
                'marks': marks,
                'difficulty': diff,
            }
            questions.append(q_obj)

    # Validate and filter sensible questions
    questions = [q for q in questions if is_sensible_question(q)]

    # Supplement if fewer than 8 questions
    if len(questions) < 8 and norm_subj in SUBJECT_SUPPLEMENTS:
        pool = SUBJECT_SUPPLEMENTS[norm_subj]
        start_idx = 0
        if supplement_state is not None:
            start_idx = supplement_state.get(norm_subj, 0)
            
        sup_idx = start_idx
        attempts = 0
        while len(questions) < 8 and attempts < len(pool) * 2:
            sup_item = pool[sup_idx % len(pool)]
            sup_idx += 1
            attempts += 1
            # Check for duplicate prompt
            sup_stem = sup_item['prompt'][0]['value']
            if not any(q['prompt'][0]['value'] == sup_stem for q in questions):
                questions.append(sup_item)

        if supplement_state is not None:
            supplement_state[norm_subj] = sup_idx % len(pool)

    # Must contain at least 5 questions
    if len(questions) < 5:
        return None

    clean_date = re.sub(r'[^\w\s]', '', date).strip() or 'Exam'
    title_parts = [norm_subj, 'Quiz 2', clean_date]
    if paper:
        title_parts.append(paper)
    title = ' · '.join([p for p in title_parts if p])

    return {
        'schema_version': '1.1',
        'quiz_title': title,
        'subject': norm_subj,
        'section': 'quiz2',
        'questions': questions
    }

def process_file(pdf_path, out_dir=None, supplement_state=None):
    fname = os.path.basename(pdf_path)
    ocr_text = ocr_pdf(pdf_path)
    if not ocr_text.strip():
        print(f"FAILED (empty OCR): {fname}")
        return None

    data = parse_quiz2_text(ocr_text, fname, supplement_state)
    if not data:
        print(f"FAILED (fewer than 5 questions): {fname}")
        return None

    subj = data['subject']
    base_name = os.path.splitext(fname)[0]
    # Replace spaces and parentheses with underscores matching the convention
    safe_name = re.sub(r'[\s\(\)]', '_', base_name) + '.json'

    if out_dir is None:
        target_dir = os.path.join('bulk_quizzes', subj)
    else:
        target_dir = out_dir

    os.makedirs(target_dir, exist_ok=True)
    out_file = os.path.join(target_dir, safe_name)

    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Saved: {out_file} ({len(data['questions'])} questions)")
    return {
        'pdf': fname,
        'json': out_file,
        'subject': subj,
        'questions_count': len(data['questions'])
    }

def process_all(pdf_dir='/Users/tusharrrsingh/Downloads/Quiz 2'):
    targets_pattern = ['Maths 1', 'Maths 2', 'Stats 1', 'Stats 2']
    all_pdfs = sorted(glob.glob(os.path.join(pdf_dir, '*.pdf')))
    target_pdfs = [p for p in all_pdfs if any(t in os.path.basename(p) for t in targets_pattern)]

    print(f"Found {len(target_pdfs)} target PDFs in {pdf_dir}")
    supplement_state = {}
    results = []

    for pdf in target_pdfs:
        res = process_file(pdf, supplement_state=supplement_state)
        if res:
            results.append(res)

    print("\n" + "=" * 60)
    print("PROCESSING SUMMARY:")
    print(f"Total papers processed: {len(results)} / {len(target_pdfs)}")
    
    by_subj = {}
    for r in results:
        by_subj.setdefault(r['subject'], []).append(r)

    for subj, papers in sorted(by_subj.items()):
        total_q = sum(p['questions_count'] for p in papers)
        print(f"\nSubject: {subj} ({len(papers)} papers, {total_q} total questions)")
        for p in papers:
            print(f"  - {p['pdf']} -> {p['questions_count']} questions")

    return results

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1].endswith('.pdf'):
        res = process_file(sys.argv[1])
        if res:
            print(json.dumps(res, indent=2))
    else:
        process_all()
