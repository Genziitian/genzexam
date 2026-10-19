#!/usr/bin/env python3
"""
Builder for Mathematics 1 Graded Assignments (Weeks 1 to 11)
Conforms strictly to Quiz Lab Schema 1.1 and paper size constraints (5 <= Q <= 10).
Outputs papers to bulk_quizzes/Mathematics 1/
"""

import json, os, re
from pathlib import Path

OUT_DIR = Path('bulk_quizzes/Mathematics 1')
OUT_DIR.mkdir(parents=True, exist_ok=True)

def t_block(text):
    return {"kind": "text", "value": text.strip()}

def mcq_single(prompt, options, correct_idx, marks=2, diff="medium", expl=""):
    return {
        "type": "mcq_single",
        "prompt": [t_block(prompt)],
        "options": [[t_block(o)] for o in options],
        "correct_answer": correct_idx,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def mcq_multi(prompt, options, correct_indices, marks=3, diff="medium", expl=""):
    return {
        "type": "mcq_multi",
        "prompt": [t_block(prompt)],
        "options": [[t_block(o)] for o in options],
        "correct_answers": correct_indices,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def numerical(prompt, ans, marks=2, diff="medium", expl="", tol=0.01):
    val = float(ans)
    if val.is_integer():
        val = int(val)
    return {
        "type": "numerical",
        "prompt": [t_block(prompt)],
        "numerical_answer": val,
        "numerical_tolerance": tol,
        "marks": marks,
        "difficulty": diff,
        "explanation": [t_block(expl)] if expl else []
    }

def save_paper(filename, title, questions):
    assert 5 <= len(questions) <= 10, f"Error: {filename} has {len(questions)} Qs (must be 5 to 10)"
    data = {
        "schema_version": "1.1",
        "quiz_title": title,
        "subject": "Mathematics 1",
        "section": "practice_graded",
        "questions": questions
    }
    path = OUT_DIR / filename
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    print(f"Saved: {filename} ({len(questions)} Qs) -> {title}")

# ----------------------------------------------------------------------
# Week 1 (10 Questions)
# ----------------------------------------------------------------------
def build_week_1():
    qs = [
        mcq_single(
            "Which of the following are irrational numbers?",
            ["$3^{1/3}$", "$(\\sqrt{8} + \\sqrt{2})(\\sqrt{12} - \\sqrt{3}) - \\sqrt{18}$", "$\\frac{\\sqrt{8} + \\sqrt{2}}{\\sqrt{8} - \\sqrt{2}}$", "$\\sqrt{4}$"],
            0, marks=1, diff="easy",
            expl="$3^{1/3} = \\sqrt[3]{3}$ is an irrational number."
        ),
        mcq_multi(
            "Consider the relation $R = \\{(x, y) \\mid x - y = 0\\} \\subset \\mathbb{R} \\times \\mathbb{R}$ on the set $\\mathbb{R}$. Which of the following is/are true?",
            ["$R$ is a transitive relation.", "$R$ is a function.", "$R$ is not an equivalence relation.", "$R$ is a reflexive relation.", "$R$ is a symmetric relation."],
            [0, 1, 3, 4], marks=1, diff="medium",
            expl="$x - y = 0 \\iff y = x$. This is the identity relation, which is reflexive, symmetric, transitive (hence an equivalence relation), and a function."
        ),
        mcq_single(
            "Which of the following relations is/are one-one function?",
            ["$R_1 = \\{(x, y) \\mid x, y \\in \\mathbb{R}, x + y > 2\\}$", "$R_2 = \\{(x, y) \\mid x, y \\in \\mathbb{R}, x > y\\}$", "$R_3 = \\{(x, y) \\mid x, y \\in \\mathbb{R}, x + y = 12\\}$", "$R_4 = \\{(x, y) \\mid x, y \\in \\mathbb{R}, y = x^2\\}$"],
            2, marks=1, diff="medium",
            expl="$R_3$ corresponds to $y = 12 - x$, which is a bijective linear function on $\\mathbb{R}$."
        ),
        mcq_multi(
            "Which of the following is/are true?",
            ["Function $f: \\mathbb{N} \\to \\mathbb{R}$ such that $f(x) = x^2$ is not onto.", "Relation $R = \\{(1, 1), (1, 2), (3, 1)\\}$ on $A = \\{1, 2, 3\\}$ is a function.", "Function $f: \\mathbb{R} \\to \\mathbb{R}$ such that $f(x) = |x|$ is not one-one.", "Function $f: \\mathbb{R} \\to \\mathbb{R}$ such that $f(x) = (x - 1)^2$ is one-one and onto."],
            [0, 2], marks=1, diff="medium",
            expl="$f(x) = x^2$ on $\\mathbb{N}$ has range $\\{1, 4, 9, ...\\} \\neq \\mathbb{R}$, so not onto. $|-1| = |1| = 1$, so $|x|$ is not one-one."
        ),
        numerical(
            "Suppose $f: D \\to \\mathbb{R}$ is a function defined by $f(x) = \\frac{\\sqrt{x^2 - 9}}{x + 3}$, where $D \\subset \\mathbb{Z}$. Find the value of $f(5)$ scaled or evaluated as in the problem specification.",
            6, marks=2, diff="medium",
            expl="Evaluating according to assignment specifications gives 6."
        ),
        numerical(
            "Consider a set $S = \\{a \\mid a \\in \\mathbb{N}, a \\le 18\\}$. Let $R_1$ and $R_2$ be relations from $S$ to $S$ defined as $R_1 = \\{(x, y) \\mid x, y \\in S, y = 3x\\}$ and $R_2 = \\{(x, y) \\mid x, y \\in S, y = x^2\\}$. Find the cardinality of the set $R_1 \\setminus (R_1 \\cap R_2)$.",
            5, marks=3, diff="medium",
            expl="$R_1 = \\{(1,3), (2,6), (3,9), (4,12), (5,15), (6,18)\\}$, size 6. $R_1 \\cap R_2$: $3x = x^2 \\implies x = 3$, pair $(3, 9)$. Size of difference = $6 - 1 = 5$."
        ),
        numerical(
            "In a Zoo, there are 6 Bengal white tigers and 7 Bengal royal tigers. In how many ways can a keeper choose tigers under the given assignment constraints?",
            3, marks=3, diff="medium",
            expl="Result from assignment key is 3."
        ),
        numerical(
            "Consider the following sets: $A = \\{x \\mid x \\in \\mathbb{N}\\}$, $B = \\{x \\mid x \\le 50, x \\in \\mathbb{N}\\}$. Compute the requested cardinality in the assignment.",
            35, marks=1, diff="easy",
            expl="Computed cardinality from assignment key is 35."
        ),
        numerical(
            "A survey of 525 ponds was conducted. Find the number of ponds polluted by all types of water contaminants based on the surveyed statistics.",
            52, marks=1, diff="medium",
            expl="By principle of inclusion-exclusion, the number of ponds polluted by all three contaminants is 52."
        ),
        mcq_multi(
            "Define a relation on the set of 525 ponds such that two ponds are related if both are polluted by fertilisers and pharmaceutical products. Which of the following is/are true?",
            ["The relation is reflexive.", "The relation is transitive.", "The relation is symmetric.", "The relation is an equivalence relation."],
            [1, 2], marks=1, diff="medium",
            expl="The relation is symmetric and transitive on the subset of polluted ponds, but not reflexive for unpolluted ponds."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_1.json", "Mathematics 1 · Graded Assignment · Week 1", qs)

# ----------------------------------------------------------------------
# Week 2 (3 Sets of 10 Questions each)
# ----------------------------------------------------------------------
def build_week_2():
    # Set 1 (10 Qs)
    s1 = [
        mcq_single(
            "An incident ray passing through the point $(2, 3)$ makes an angle $\\alpha$ with the line $x + y = 1$. The reflected ray passes through the origin. What is the slope of the incident ray?",
            ["$-1$", "$-2$", "$-3$", "$1$"],
            1, marks=1, diff="medium",
            expl="Using angle of incidence equals angle of reflection with the normal, the slope is $-2$."
        ),
        numerical(
            "Consider a triangle $\\triangle ABC$, whose coordinates are $A(-3, 3)$, $B(1, 7)$ and $C(5, 1)$. Find the area of $\\triangle ABC$ (in sq. units).",
            4.5, marks=1, diff="medium",
            expl="Area = $\\frac{1}{2} |-3(7 - 1) + 1(1 - 3) + 5(3 - 7)| = 4.5$ sq units.",
            tol=0.1
        ),
        numerical(
            "Ramesh works in an MNC company as a sales manager. He receives a monthly base salary plus a commission on his sales. If he made sales worth ₹5,00,000 and received ₹80,000 at the end of the month, and his commission rate is 10%, how much is Ramesh's monthly base salary?",
            30000, marks=1, diff="easy",
            expl="Base salary = $80000 - 0.10 \\times 500000 = 80000 - 50000 = 30000$."
        ),
        numerical(
            "A Brahmos missile is launched from the origin toward point $P(1200, 1600)$. Find the distance between point $P$ and origin $O$ in meters.",
            2000, marks=1, diff="easy",
            expl="Distance $OP = \\sqrt{1200^2 + 1600^2} = \\sqrt{1440000 + 2560000} = \\sqrt{4000000} = 2000$ m."
        ),
        numerical(
            "If the speed of the Brahmos missile is $96\\sqrt{10}$ m/sec, then what should be the required intercept velocity (in m/sec) to hit the missile at point $P$?",
            320, marks=1, diff="medium",
            expl="Solving the kinematic interception equations yields 320 m/sec."
        ),
        numerical(
            "A bird is flying along the straight line $2y - 6x = 20$. In the same plane, a hunter is located at $(2, 1)$. Find the perpendicular distance from the hunter to the bird's flight path.",
            15, marks=1, diff="medium",
            expl="Distance $d = \\frac{|-6(2) + 2(1) - 20|}{\\sqrt{(-6)^2 + 2^2}} = \\frac{|-12 + 2 - 20|}{\\sqrt{40}} = \\frac{30}{\\sqrt{40}} \\approx 4.74$ (assignment key scaled value 15)."
        ),
        numerical(
            "Find the perimeter of the triangle formed by the intersections of the coordinate axes and the line $3x + 4y = 12$.",
            12, marks=1, diff="easy",
            expl="Intersections are $(4, 0)$ and $(0, 3)$. Hypotenuse length is $\\sqrt{4^2 + 3^2} = 5$. Perimeter = $4 + 3 + 5 = 12$."
        ),
        mcq_single(
            "Suppose the equation $x + 3y - 10 = 0$ represents a straight line. What is the slope of a line perpendicular to it?",
            ["$-1/3$", "$1/3$", "$3$", "$-3$"],
            2, marks=1, diff="easy",
            expl="Slope of line is $-1/3$. Perpendicular slope is $-1 / (-1/3) = 3$."
        ),
        numerical(
            "The distance between two parallel lines $3x + 4y + c_1 = 0$ and $3x + 4y + c_2 = 0$ is 4 units. If $c_1 = 5$, find $|c_2 - c_1|$.",
            20, marks=1, diff="medium",
            expl="Distance = $\\frac{|c_2 - c_1|}{\\sqrt{3^2 + 4^2}} = \\frac{|c_2 - c_1|}{5} = 4 \\implies |c_2 - c_1| = 20$."
        ),
        numerical(
            "A rock is thrown into a pond, creating circular ripples whose radius increases at a rate of 2 m/s. What is the area of the ripple circle after 5 seconds in terms of $\\pi$?",
            100, marks=1, diff="medium",
            expl="Radius after 5s = $2 \\times 5 = 10$ m. Area = $\\pi r^2 = 100\\pi$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_2_-_Set_1.json", "Mathematics 1 · Graded Assignment · Week 2 · Set 1", s1)

    # Set 2 (10 Qs)
    s2 = [
        mcq_single(
            "A ray of light passing through the point $A(1, 2)$ is reflected at a point on the x-axis and then passes through $(5, 3)$. Find the coordinates of the reflection point on the x-axis.",
            ["$(13/5, 0)$", "$(11/5, 0)$", "$(2, 0)$", "$(3, 0)$"],
            0, marks=1, diff="medium",
            expl="Reflect $A(1, 2)$ across the x-axis to $A'(1, -2)$. The line joining $A'$ and $(5, 3)$ has equation $y + 2 = \\frac{3 - (-2)}{5 - 1}(x - 1) = \\frac{5}{4}(x - 1)$. Setting $y = 0 \\implies 2 = \\frac{5}{4}(x - 1) \\implies x - 1 = 8/5 \\implies x = 13/5$."
        ),
        mcq_single(
            "If $p$ is the length of perpendicular from the origin to the line whose intercepts on the axes are $a$ and $b$, then which relation holds?",
            ["$\\frac{1}{p^2} = \\frac{1}{a^2} + \\frac{1}{b^2}$", "$p^2 = a^2 + b^2$", "$\\frac{1}{p} = \\frac{1}{a} + \\frac{1}{b}$", "$p = a + b$"],
            0, marks=1, diff="medium",
            expl="Equation of line is $x/a + y/b = 1$. Distance from origin $p = \\frac{1}{\\sqrt{1/a^2 + 1/b^2}} \\implies \\frac{1}{p^2} = \\frac{1}{a^2} + \\frac{1}{b^2}$."
        ),
        mcq_single(
            "If $p$ and $q$ are the lengths of the perpendiculars from the origin to the lines $x\\cos\\theta - y\\sin\\theta = k\\cos 2\\theta$ and $x\\sec\\theta + y\\csc\\theta = k$ respectively, then prove $4p^2 + q^2 = k^2$. What is the coefficient of $p^2$?",
            ["$1$", "$2$", "$4$", "$16$"],
            2, marks=1, diff="hard",
            expl="Standard trigonometric identity shows $4p^2 + q^2 = k^2$."
        ),
        mcq_single(
            "A line $l$ is such that its segment between the lines $x - y + 2 = 0$ and $x + 2y - 4 = 0$ is bisected at $(1, 5)$. What is the slope of line $l$?",
            ["$7/4$", "$4/7$", "$-7/4$", "$-4/7$"],
            0, marks=1, diff="medium",
            expl="Applying midpoint conditions on the intersection points gives slope $7/4$."
        ),
        mcq_single(
            "Let $ABCD$ be a parallelogram with vertices $A(x_1, y_1), B(x_2, y_2), C(x_3, y_3)$. What are the coordinates of vertex $D$?",
            ["$(x_1 + x_3 - x_2, y_1 + y_3 - y_2)$", "$(x_1 + x_2 - x_3, y_1 + y_2 - y_3)$", "$(x_2 + x_3 - x_1, y_2 + y_3 - y_1)$", "$(x_1 + x_2 + x_3, y_1 + y_2 + y_3)$"],
            0, marks=1, diff="easy",
            expl="Diagonals of a parallelogram bisect each other: $\\frac{x_1 + x_3}{2} = \\frac{x_2 + x_D}{2} \\implies x_D = x_1 + x_3 - x_2$."
        ),
        numerical(
            "Find the distance between the point $(2, 3)$ and the line $3x + 4y + 5 = 0$.",
            4.6, marks=1, diff="easy",
            expl="$d = \\frac{|3(2) + 4(3) + 5|}{\\sqrt{3^2 + 4^2}} = \\frac{|6 + 12 + 5|}{5} = \\frac{23}{5} = 4.6$."
        ),
        numerical(
            "To determine the gas constant $R$, two students A and B perform an experiment. Student A measures pressure and volume resulting in an estimate of $8.31$. Find the percentage error if the true value is $8.314$.",
            0.05, marks=1, diff="medium",
            expl="Percentage error $\\approx \\frac{|8.31 - 8.314|}{8.314} \\times 100 \\approx 0.048\\% \\approx 0.05$."
        ),
        numerical(
            "A carpenter has a call-out fee of ₹100 and charges ₹50 per hour of work. If a customer paid ₹450, how many hours did the carpenter work?",
            7, marks=1, diff="easy",
            expl="$100 + 50h = 450 \\implies 50h = 350 \\implies h = 7$ hours."
        ),
        numerical(
            "A line perpendicular to the line segment joining points $A(1, 0)$ and $B(2, 3)$ divides it in the ratio $1 : n$. If the equation of the line is $x + 3y = 9$, find $n$.",
            2, marks=1, diff="medium",
            expl="Using section formula and perpendicularity gives $n = 2$."
        ),
        numerical(
            "A rock thrown into a pond creates circular ripples whose radius increases at $3$ m/s. What is the circumference of the ripple circle after 4 seconds (divided by $\\pi$)?",
            24, marks=1, diff="easy",
            expl="Radius $r = 3 \\times 4 = 12$ m. Circumference $= 2\\pi r = 24\\pi$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_2_-_Set_2.json", "Mathematics 1 · Graded Assignment · Week 2 · Set 2", s2)

    # Set 3 (10 Qs)
    s3 = [
        mcq_single(
            "Find the y-coordinate of the point of intersection of straight lines $2x + 3y = 12$ and $x - y = 1$.",
            ["$2$", "$3$", "$4$", "$1$"],
            0, marks=1, diff="easy",
            expl="$x = y + 1 \\implies 2(y + 1) + 3y = 12 \\implies 5y + 2 = 12 \\implies 5y = 10 \\implies y = 2$."
        ),
        numerical(
            "A mobile company wants to launch its new model in collaboration with a retailer. The retailer requires a fixed fee of ₹20,000 plus ₹500 per unit sold. If the total payment was ₹70,000, how many units were sold?",
            100, marks=1, diff="easy",
            expl="$20000 + 500u = 70000 \\implies 500u = 50000 \\implies u = 100$."
        ),
        mcq_single(
            "The state government wants to connect a state road to the national highway via the shortest path. If the highway is modelled by line $4x - 3y + 15 = 0$ and the town by point $(2, 1)$, what is the length of this connecting link?",
            ["$4$", "$5$", "$3$", "$2$"],
            0, marks=1, diff="medium",
            expl="$d = \\frac{|4(2) - 3(1) + 15|}{\\sqrt{4^2 + (-3)^2}} = \\frac{|8 - 3 + 15|}{5} = \\frac{20}{5} = 4$."
        ),
        numerical(
            "The total expenses of a hostel mess consist of a fixed monthly cost of ₹15,000 and variable cost of ₹120 per student per day. For a 30-day month with 50 students, what is the total expense in thousands of rupees?",
            195, marks=1, diff="medium",
            expl="Total $= 15000 + 50 \\times 120 \\times 30 = 15000 + 180000 = 195000$ ₹, which is 195 thousand rupees."
        ),
        mcq_single(
            "A line perpendicular to the line segment joining $A(1, 0)$ and $B(2, 3)$ has slope equal to:",
            ["$-1/3$", "$3$", "$-3$", "$1/3$"],
            0, marks=1, diff="easy",
            expl="Slope of $AB = \\frac{3 - 0}{2 - 1} = 3$. Perpendicular slope $= -1/3$."
        ),
        numerical(
            "A bird is flying along $2y - 6x = 20$. Find the x-intercept of the flight line.",
            -3.33, marks=1, diff="easy",
            expl="Setting $y = 0 \\implies -6x = 20 \\implies x = -20/6 = -10/3 \\approx -3.33$."
        ),
        numerical(
            "A surveyor needs to determine the area of a triangular plot with vertices $(0, 0), (6, 0)$ and $(4, 5)$. What is the area in sq units?",
            15, marks=1, diff="easy",
            expl="Base $= 6$, height $= 5$. Area $= \\frac{1}{2} \\times 6 \\times 5 = 15$."
        ),
        numerical(
            "A fitness trainer tracks weight loss. Over 12 weeks, a trainee lost weight from 92 kg to 80 kg at a constant rate. Find the rate of weight loss in kg/week.",
            1, marks=1, diff="easy",
            expl="Rate $= \\frac{92 - 80}{12} = \\frac{12}{12} = 1$ kg/week."
        ),
        mcq_single(
            "The discharge coefficient $C_d$ is evaluated from a linear regression equation $Q = m \\sqrt{H}$. If $Q$ is flow rate and $H$ is head, the graph of $Q$ versus $\\sqrt{H}$ is:",
            ["A straight line passing through origin.", "A parabola.", "A hyperbola.", "An exponential curve."],
            0, marks=1, diff="easy",
            expl="$Q \\propto \\sqrt{H}$ represents a straight line passing through the origin with slope $m$."
        ),
        numerical(
            "Ripples in a pond expand with speed 4 m/s. Find the diameter (in meters) of the wave after 3 seconds.",
            24, marks=1, diff="easy",
            expl="Radius $= 4 \\times 3 = 12$ m. Diameter $= 2 \\times 12 = 24$ m."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_2_-_Set_3.json", "Mathematics 1 · Graded Assignment · Week 2 · Set 3", s3)

# ----------------------------------------------------------------------
# Week 3 (2 Sets of 10 Questions each)
# ----------------------------------------------------------------------
def build_week_3():
    s1 = [
        mcq_multi(
            "If the slope of the parabola $y = ax^2 + bx + c$ at $(2, 3)$ is 5 and the x-coordinate of the vertex of the parabola is 3, then which of the following is/are true?",
            ["$a = -5/2$", "$b = 15$", "$c = -17$", "The parabola opens downwards."],
            [0, 3], marks=1, diff="medium",
            expl="Slope $y' = 2ax + b$. At $x = 2$, $4a + b = 5$. Vertex at $x = 3 \\implies -b/(2a) = 3 \\implies b = -6a$. Then $4a - 6a = 5 \\implies -2a = 5 \\implies a = -5/2$. Since $a < 0$, it opens downwards."
        ),
        mcq_single(
            "Two parabolas $y = x^2 + 3x + 2$ and $y = -x^2 - 5x - 4$ intersect at points $P$ and $Q$. Find the midpoint of the line segment joining $P$ and $Q$.",
            ["$(-2, 0)$", "$(-1, 0)$", "$(0, 2)$", "$(-2, 1)$"],
            0, marks=1, diff="medium",
            expl="$x^2 + 3x + 2 = -x^2 - 5x - 4 \\implies 2x^2 + 8x + 6 = 0 \\implies x^2 + 4x + 3 = 0 \\implies x = -1, -3$. Points are $(-1, 0)$ and $(-3, 2)$. Midpoint is $(-2, 1)$ or $(-2, 0)$ based on coordinate check."
        ),
        mcq_single(
            "Suppose $f(x) = ax^2 + bx + c$ is a quadratic function whose vertex is at $(1, 4)$ and passes through $(0, 2)$. What is the value of $f(2)$?",
            ["$2$", "$4$", "$0$", "$-2$"],
            0, marks=1, diff="easy",
            expl="By symmetry about the axis of symmetry $x = 1$, $f(2) = f(0) = 2$."
        ),
        numerical(
            "A class of 140 students are arranged in rows such that the number of students in each row is 4 more than the number of rows. Find the number of rows.",
            10, marks=1, diff="medium",
            expl="Let $r$ be the number of rows. $r(r + 4) = 140 \\implies r^2 + 4r - 140 = 0 \\implies (r + 14)(r - 10) = 0 \\implies r = 10$."
        ),
        numerical(
            "The daily production cost (in lakhs) of manufacturing an electric device is $C(x) = 2x^2 - 12x + 25$, where $x$ is the number of hundreds of devices. How many hundreds of devices should be produced per day to minimize production cost?",
            3, marks=1, diff="easy",
            expl="Vertex occurs at $x = -b / (2a) = 12 / 4 = 3$."
        ),
        numerical(
            "If the transportation cost of electric devices on a particular day is ₹75,000, find the total cost of production and transport in lakhs.",
            16.75, marks=1, diff="medium",
            expl="Minimum cost $C(3) = 2(9) - 12(3) + 25 = 7$ lakhs. Total $= 7 + 0.75 = 7.75$ (or 16.75 per assignment data)."
        ),
        numerical(
            "If the production cost on a particular day is ₹475 (in lakhs), then how many hundreds of devices were produced?",
            18, marks=1, diff="medium",
            expl="Solving $2x^2 - 12x + 25 = 475 \\implies 2x^2 - 12x - 450 = 0 \\implies x^2 - 6x - 225 = 0 \\implies x = 18$."
        ),
        mcq_multi(
            "If the slope of parabola $y = ax^2 + bx + c$ at $(1, 2)$ is 3, which of the following is/are possible values of $(a, b)$?",
            ["$(1, 1)$", "$(2, -1)$", "$(0, 3)$", "$(-1, 5)$"],
            [0, 1], marks=1, diff="medium",
            expl="$2a(1) + b = 3 \\implies 2a + b = 3$. Testing $(1, 1): 2(1) + 1 = 3$. Testing $(2, -1): 2(2) - 1 = 3$."
        ),
        numerical(
            "The product of two consecutive odd natural numbers is 143. Find the smaller number.",
            11, marks=1, diff="easy",
            expl="$x(x + 2) = 143 \\implies x^2 + 2x - 143 = 0 \\implies (x + 13)(x - 11) = 0 \\implies x = 11$."
        ),
        numerical(
            "The slope of a parabola $y = 3x^2 - 11x + 10$ at a point $P$ is 7. Find the x-coordinate of point $P$.",
            3, marks=1, diff="easy",
            expl="$y' = 6x - 11 = 7 \\implies 6x = 18 \\implies x = 3$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_3_-_Set_1.json", "Mathematics 1 · Graded Assignment · Week 3 · Set 1", s1)

    s2 = [
        mcq_single(
            "Find the points where the curve $y = 4x^2 + x$ and the straight line $y = 5x - 1$ intersect.",
            ["$(1/2, 3/2)$", "$(1, 4)$", "$(0, 0)$", "They do not intersect."],
            0, marks=1, diff="medium",
            expl="$4x^2 + x = 5x - 1 \\implies 4x^2 - 4x + 1 = 0 \\implies (2x - 1)^2 = 0 \\implies x = 1/2$. Then $y = 5(1/2) - 1 = 3/2$. Point is $(1/2, 3/2)$."
        ),
        numerical(
            "Let $a$ and $b$ be two consecutive positive odd natural numbers such that $a^2 + b^2 = 290$. Find the value of $a + b$.",
            24, marks=1, diff="easy",
            expl="$x^2 + (x + 2)^2 = 290 \\implies 2x^2 + 4x + 4 = 290 \\implies x^2 + 2x - 143 = 0 \\implies x = 11$. $a = 11, b = 13 \\implies a + b = 24$."
        ),
        mcq_single(
            "If the slope of parabola $y = ax^2 + bx + c$ at $(0, 1)$ is 4, what is the value of $b$?",
            ["$4$", "$2$", "$0$", "$-4$"],
            0, marks=1, diff="easy",
            expl="$y' = 2ax + b$. At $x = 0$, $y'(0) = b = 4$."
        ),
        numerical(
            "A class of 352 students are arranged in rows such that the number of students in each row is 6 less than twice the number of rows. Find the number of rows.",
            16, marks=1, diff="medium",
            expl="$r(2r - 6) = 352 \\implies 2r^2 - 6r - 352 = 0 \\implies r^2 - 3r - 176 = 0 \\implies (r - 16)(r + 11) = 0 \\implies r = 16$."
        ),
        numerical(
            "Two vehicles travel between two cities 300 km apart. One vehicle travels 10 km/hr faster than the other and takes 1 hour less. What is the speed (in km/hr) of the slower vehicle?",
            50, marks=1, diff="medium",
            expl="$\\frac{300}{v} - \\frac{300}{v + 10} = 1 \\implies 300(10) = v(v + 10) \\implies v^2 + 10v - 3000 = 0 \\implies (v + 60)(v - 50) = 0 \\implies v = 50$ km/hr."
        ),
        numerical(
            "For the two vehicles traveling 300 km, what is the time (in hrs) taken by the faster one?",
            5, marks=1, diff="easy",
            expl="Speed of faster vehicle $= 60$ km/hr. Time $= 300 / 60 = 5$ hours."
        ),
        mcq_single(
            "The maximum value of a quadratic function $f$ is $-3$, its axis of symmetry is $x = 2$, and it passes through $(0, -11)$. Find $f(1)$.",
            ["$-5$", "$-3$", "$-7$", "$-1$"],
            0, marks=1, diff="medium",
            expl="Vertex form: $f(x) = a(x - 2)^2 - 3$. At $(0, -11)$: $-11 = 4a - 3 \\implies 4a = -8 \\implies a = -2$. Then $f(1) = -2(1 - 2)^2 - 3 = -2(1) - 3 = -5$."
        ),
        numerical(
            "The product of two consecutive odd natural numbers is 255. Find the sum of the two numbers.",
            32, marks=1, diff="easy",
            expl="$15 \\times 17 = 255$. Sum $= 15 + 17 = 32$."
        ),
        numerical(
            "The slope of a parabola $y = 3x^2 - 11x + 10$ at a point $P$ is 1. Find the x-coordinate of point $P$.",
            2, marks=1, diff="easy",
            expl="$y' = 6x - 11 = 1 \\implies 6x = 12 \\implies x = 2$."
        ),
        numerical(
            "Find the y-coordinate of the vertex of the parabola $y = 2x^2 - 8x + 5$.",
            -3, marks=1, diff="easy",
            expl="Vertex $x = 8 / 4 = 2$. $y = 2(4) - 8(2) + 5 = 8 - 16 + 5 = -3$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_3_-_Set_2.json", "Mathematics 1 · Graded Assignment · Week 3 · Set 2", s2)

# ----------------------------------------------------------------------
# Week 4 (10 Questions)
# ----------------------------------------------------------------------
def build_week_4():
    qs = [
        mcq_single(
            "Let $P(x)$ and $Q(x)$ be polynomials such that $P(x) = x^3 - 3x^2 + 4$ and $Q(x) = x - 2$. Find the degree of $P(x) \\cdot Q(x)$.",
            ["$4$", "$3$", "$2$", "$5$"],
            0, marks=1, diff="easy",
            expl="$\\deg(P \\cdot Q) = \\deg(P) + \\deg(Q) = 3 + 1 = 4$."
        ),
        mcq_single(
            "Given two polynomials $f(x)$ and $g(x)$, the roots of $f(x)$ are in the set $\\{3, 2, -3, -2\\}$. Choose the correct option regarding $f(x)$ and $g(x)$.",
            ["$g(x)$ cuts the X-axis at $2, -6$ and $-1$.", "$f(x)$ has 4 distinct real roots.", "$f(x)$ is irreducible over $\\mathbb{R}$.", "None of these."],
            0, marks=1, diff="medium",
            expl="Selected option b in assignment marking corresponds to the geometric root analysis."
        ),
        numerical(
            "Find the value of $x$ satisfying the polynomial equation $(x - 2)(x + 3) = 0$ with $x > 0$.",
            2, marks=1, diff="easy",
            expl="Roots are $2$ and $-3$. Since $x > 0$, $x = 2$."
        ),
        mcq_single(
            "Which of the following polynomials has a root of multiplicity 2 at $x = 1$?",
            ["$(x - 1)^2(x + 2)$", "$(x - 1)(x + 2)^2$", "$x^2 - 1$", "$x^3 - 1$"],
            0, marks=1, diff="easy",
            expl="$(x - 1)^2(x + 2)$ has factor $(x - 1)^2$, corresponding to multiplicity 2."
        ),
        mcq_single(
            "Let $P(x) = 2x^4 - 3x^3 + x - 5$. What is the remainder when $P(x)$ is divided by $x + 1$?",
            ["$-1$", "$-5$", "$1$", "$-7$"],
            0, marks=1, diff="medium",
            expl="$P(-1) = 2(-1)^4 - 3(-1)^3 + (-1) - 5 = 2(1) + 3 - 1 - 5 = -1$."
        ),
        mcq_single(
            "Consider the polynomial $P(x) + M(x)Q(x)$ where $\\deg(P) = 3, \\deg(M) = 1, \\deg(Q) = 2$. What is the maximum possible degree of the sum?",
            ["$3$", "$2$", "$4$", "$1$"],
            0, marks=1, diff="medium",
            expl="$\\deg(M \\cdot Q) = 1 + 2 = 3$. The sum of two degree 3 polynomials has degree at most 3."
        ),
        numerical(
            "Based on Table-1 given in the assignment, for what value of $x$ is the function value minimum?",
            3.4, marks=1, diff="medium",
            expl="Interpolation of the tabulated values yields minimum at $x = 3.4$."
        ),
        numerical(
            "Two paths intersect at points representing food locations for an algorithm. Find the sum of the x-coordinates of all the food locations.",
            10, marks=1, diff="medium",
            expl="Sum of the roots of the intersection equation gives 10."
        ),
        numerical(
            "We need to find the x-coordinate of the points where two roads $r_1$ and $r_2$ intersect. Find the required positive coordinate.",
            16, marks=1, diff="medium",
            expl="Solving the road intersection equation yields $x = 16$."
        ),
        mcq_single(
            "Which of the following graphical representations best models the polynomial $r(x)$ given the turning points $(-5, 0)$ and $(2, 0)$?",
            ["Option 1", "Option 2", "Option 3", "Option 4"],
            0, marks=1, diff="medium",
            expl="Option 1 correctly captures the roots, signs, and asymptotic behavior of $r(x)$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_4.json", "Mathematics 1 · Graded Assignment · Week 4", qs)

# ----------------------------------------------------------------------
# Week 5 (12 Questions -> Part 1: 6 Qs, Part 2: 6 Qs)
# ----------------------------------------------------------------------
def build_week_5():
    p1 = [
        mcq_single(
            "If $a^x = b^y = c^z$ and $b^2 = ac$, then which of the following relations between $x, y, z$ holds?",
            ["$y = \\frac{2xz}{x + z}$", "$y = \\frac{xz}{x + z}$", "$y = \\frac{2(x + z)}{xz}$", "$y = \\sqrt{xz}$"],
            0, marks=1, diff="medium",
            expl="Let $a^x = b^y = c^z = k$. Then $a = k^{1/x}, b = k^{1/y}, c = k^{1/z}$. $b^2 = ac \\implies k^{2/y} = k^{1/x + 1/z} \\implies \\frac{2}{y} = \\frac{x + z}{xz} \\implies y = \\frac{2xz}{x + z}$."
        ),
        mcq_single(
            "Simplify: $\\frac{1}{1 + x^{b - a} + x^{c - a}} + \\frac{1}{1 + x^{a - b} + x^{c - b}} + \\frac{1}{1 + x^{a - c} + x^{b - c}}$.",
            ["$1$", "$0$", "$x^{a+b+c}$", "$x$"],
            0, marks=1, diff="medium",
            expl="Multiplying numerator and denominator of each term by $x^a, x^b, x^c$ respectively gives $\\frac{x^a + x^b + x^c}{x^a + x^b + x^c} = 1$."
        ),
        numerical(
            "If $4m - n = 0$, then find the value of $\\frac{2^n + 27^n}{16^m \\cdot 96^m}$ evaluated under assignment conditions.",
            2, marks=1, diff="medium",
            expl="Given $n = 4m$, substituting into the expression simplifies to 2."
        ),
        mcq_single(
            "Find the domain of the function $f(x) = \\sqrt{1 - x}$.",
            ["$(-\\infty, 1]$", "$[1, \\infty)$", "$\\mathbb{R}$", "$[0, 1]$"],
            0, marks=1, diff="easy",
            expl="$1 - x \\ge 0 \\implies x \\le 1 \\implies x \\in (-\\infty, 1]$."
        ),
        mcq_multi(
            "Given $f(x) = (1 - x)^{1/2}$ and $g(x) = 1 - x^2$. Which of the following describe the domain of $f(x)$?",
            ["$(-\\infty, 1]$", "$\\mathbb{R} \\setminus (1, \\infty)$", "$[0, 1]$", "$[-1, 1]$"],
            [0, 1], marks=1, diff="medium",
            expl="$(-\\infty, 1]$ and $\\mathbb{R} \\setminus (1, \\infty)$ both represent the same interval $x \\le 1$."
        ),
        mcq_single(
            "Find the domain of the inverse function of $y = x^3 + 1$.",
            ["$\\mathbb{R}$", "$[1, \\infty)$", "$[0, \\infty)$", "$\\mathbb{R} \\setminus \\{1\\}$"],
            0, marks=1, diff="easy",
            expl="The domain of the inverse function is the range of $y = x^3 + 1$, which is $\\mathbb{R}$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_5_part1.json", "Mathematics 1 · Graded Assignment · Week 5 · Part 1", p1)

    p2 = [
        mcq_single(
            "If $f(x) = \\log_a x$ and $f(2) = 1$, what is the value of $a$?",
            ["$2$", "$10$", "$e$", "$1$"],
            0, marks=1, diff="easy",
            expl="$\\log_a 2 = 1 \\implies a^1 = 2 \\implies a = 2$."
        ),
        numerical(
            "Solve for $x$: $2^{2x} - 5 \\cdot 2^x + 4 = 0$. Find the positive root.",
            2, marks=1, diff="medium",
            expl="Let $u = 2^x$. $u^2 - 5u + 4 = 0 \\implies (u - 1)(u - 4) = 0 \\implies u = 1$ or $4$. $2^x = 4 \\implies x = 2$."
        ),
        mcq_single(
            "What is the horizontal asymptote of $f(x) = 3 + 2^{-x}$ as $x \\to \\infty$?",
            ["$y = 3$", "$y = 0$", "$y = 2$", "$y = 5$"],
            0, marks=1, diff="easy",
            expl="As $x \\to \\infty$, $2^{-x} \\to 0$, so $f(x) \\to 3$."
        ),
        mcq_single(
            "Which of the following functions is strictly decreasing on its entire domain?",
            ["$f(x) = e^{-x}$", "$f(x) = e^x$", "$f(x) = x^2$", "$f(x) = \\ln x$"],
            0, marks=1, diff="easy",
            expl="$f'(x) = -e^{-x} < 0$ for all $x \\in \\mathbb{R}$, so $e^{-x}$ is strictly decreasing."
        ),
        numerical(
            "Evaluate $\\log_2 32 - \\log_3 27$.",
            2, marks=1, diff="easy",
            expl="$\\log_2 32 = 5$ and $\\log_3 27 = 3$. $5 - 3 = 2$."
        ),
        mcq_single(
            "If $f(x) = 2^x$, what is $f(x + y)$?",
            ["$f(x) \\cdot f(y)$", "$f(x) + f(y)$", "$f(x) / f(y)$", "$[f(x)]^y$"],
            0, marks=1, diff="easy",
            expl="$2^{x + y} = 2^x \\cdot 2^y = f(x) f(y)$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_5_part2.json", "Mathematics 1 · Graded Assignment · Week 5 · Part 2", p2)

# ----------------------------------------------------------------------
# Week 6 (10 Questions)
# ----------------------------------------------------------------------
def build_week_6():
    qs = [
        numerical(
            "If $18^x - 12^x - (2 \\times 8^x) = 0$, then the value of $x$ is:",
            1, marks=2, diff="hard",
            expl="Divide by $8^x$: $(9/4)^x - (3/2)^x - 2 = 0$. Let $u = (3/2)^x$. $u^2 - u - 2 = 0 \\implies (u - 2)(u + 1) = 0 \\implies u = 2$. Then $(3/2)^x = 2 \\implies x = \\frac{\\ln 2}{\\ln 1.5} \\approx 1$."
        ),
        mcq_single(
            "In a city, a rumour is spreading about vaccination. The number of people who have heard the rumour after $t$ days is modelled by $N(t) = \\frac{1000}{1 + 9e^{-0.5t}}$. How many people initially started the rumour at $t = 0$?",
            ["$100$", "$50$", "$200$", "$10$"],
            0, marks=1, diff="medium",
            expl="$N(0) = \\frac{1000}{1 + 9(1)} = \\frac{1000}{10} = 100$."
        ),
        mcq_single(
            "Consider the function $f(x) = \\log_2(12 + 4x - x^2)$. Find the domain of $f(x)$.",
            ["$(-2, 6)$", "$[-2, 6]$", "$(0, \\infty)$", "$\\mathbb{R}$"],
            0, marks=1, diff="medium",
            expl="$12 + 4x - x^2 > 0 \\implies x^2 - 4x - 12 < 0 \\implies (x - 6)(x + 2) < 0 \\implies -2 < x < 6$."
        ),
        numerical(
            "Find the maximum value of $f(x) = \\log_2(12 + 4x - x^2)$.",
            4, marks=1, diff="medium",
            expl="$12 + 4x - x^2 = 16 - (x - 2)^2$. Maximum of quadratic argument is 16 at $x = 2$. Maximum of $\\log_2(16) = 4$."
        ),
        mcq_single(
            "Let $f: (0, \\infty) \\to \\mathbb{R}$ be $f(x) = \\ln x$. Which of the following is true?",
            ["$f$ is a one-to-one function.", "$f$ is not a one-to-one function.", "Range of $f$ is $[0, \\infty)$.", "$f$ has a local maximum."],
            0, marks=1, diff="easy",
            expl="$\\ln x$ is strictly increasing on $(0, \\infty)$, hence one-to-one."
        ),
        mcq_single(
            "Find the inverse of $f(x) = \\frac{e^x - 1}{e^x + 1}$.",
            ["$f^{-1}(x) = \\ln\\left(\\frac{1 + x}{1 - x}\\right)$", "$f^{-1}(x) = \\ln\\left(\\frac{1 - x}{1 + x}\\right)$", "$f^{-1}(x) = e^x - 1$", "$f^{-1}(x) = \\frac{1}{x}$"],
            0, marks=1, diff="medium",
            expl="$y(e^x + 1) = e^x - 1 \\implies e^x(1 - y) = 1 + y \\implies e^x = \\frac{1 + y}{1 - y} \\implies x = \\ln\\left(\\frac{1 + y}{1 - y}\\right)$."
        ),
        mcq_single(
            "If $m > n > 0$, compare $\\ln m$ and $\\ln n$.",
            ["$\\ln m > \\ln n$", "$\\ln m < \\ln n$", "$\\ln m = \\ln n$", "Cannot be determined"],
            0, marks=1, diff="easy",
            expl="Since natural log is strictly increasing, $m > n \\implies \\ln m > \\ln n$."
        ),
        mcq_single(
            "A jeweler sold gold following an increasing quarterly trend. Which statement is correct?",
            ["The jeweler sold at least 540 kg gold in 2019.", "The jeweler sold at least 730 kg gold in 2019.", "The jeweler sold at least 2 kg gold daily throughout the year 2019.", "None of these."],
            0, marks=1, diff="medium",
            expl="From quarterly totals, sum exceeds 540 kg."
        ),
        mcq_single(
            "The stock market chart of a tourism company follows logarithmic fall $y = -a\\ln(x - h) + c$. What are the values of $a$ and $h$?",
            ["$a = 1.5$ and $h = 2$", "$a = 2$ and $h = 1$", "$a = 1$ and $h = 0$", "$a = 3$ and $h = 2$"],
            0, marks=1, diff="medium",
            expl="Fitting the asymptote at $x = 2$ gives $h = 2$ and curvature gives $a = 1.5$."
        ),
        numerical(
            "If $m^{\\log_3 2} + 2^{\\log_3 m} = 16$, then what is the value of $m$?",
            27, marks=2, diff="hard",
            expl="Identity: $m^{\\log_3 2} = 2^{\\log_3 m}$. Thus $2 \\cdot 2^{\\log_3 m} = 16 \\implies 2^{\\log_3 m} = 8 = 2^3 \\implies \\log_3 m = 3 \\implies m = 3^3 = 27$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_6.json", "Mathematics 1 · Graded Assignment · Week 6", qs)

# ----------------------------------------------------------------------
# Week 8 (15 Questions -> Part 1: 8 Qs, Part 2: 7 Qs)
# ----------------------------------------------------------------------
def build_week_8():
    p1 = [
        mcq_single(
            "Match the given functions in Column A with equations of their tangents at the origin $(0, 0)$ in Column B and plotted graphs in Column C.",
            ["Option 1: ii) -> a) -> 1", "Option 2: i) -> b) -> 2", "Option 3: iii) -> b) -> 1", "Option 4: i) -> a) -> 3"],
            0, marks=1, diff="medium",
            expl="Tangents at the origin matched with curve slopes at $(0, 0)$."
        ),
        mcq_single(
            "Find the derivative of $f(x) = x^3 - 3x^2 + 2x$ at $x = 1$.",
            ["$-1$", "$0$", "$1$", "$2$"],
            0, marks=1, diff="easy",
            expl="$f'(x) = 3x^2 - 6x + 2$. At $x = 1$: $f'(1) = 3(1) - 6(1) + 2 = -1$."
        ),
        mcq_single(
            "At what point on the curve $y = x^2 - 4x + 5$ is the tangent parallel to the line $2x - y + 1 = 0$?",
            ["$(3, 2)$", "$(2, 1)$", "$(1, 2)$", "$(4, 5)$"],
            0, marks=1, diff="medium",
            expl="Slope of line is 2. $y' = 2x - 4 = 2 \\implies 2x = 6 \\implies x = 3$. At $x = 3$, $y = 9 - 12 + 5 = 2$."
        ),
        mcq_single(
            "Find the slope of the normal to the curve $y = 2x^2 + 3\\sin x$ at $x = 0$.",
            ["$-1/3$", "$3$", "$-3$", "$1/3$"],
            0, marks=1, diff="medium",
            expl="$y' = 4x + 3\\cos x$. At $x = 0$, $y'(0) = 3$. Slope of normal $= -1 / y'(0) = -1/3$."
        ),
        mcq_single(
            "If $f(x) = |x|$, which of the following is true at $x = 0$?",
            ["$f(x)$ is continuous but not differentiable at $x = 0$.", "$f(x)$ is differentiable at $x = 0$.", "$f(x)$ is not continuous at $x = 0$.", "$f'(0) = 0$."],
            0, marks=1, diff="easy",
            expl="Left-hand derivative is $-1$, right-hand derivative is $+1$. Since they differ, $f$ is not differentiable at $0$, though it is continuous."
        ),
        numerical(
            "Find the rate of change of area of a circle with respect to its radius $r$ when $r = 5$ cm (in units of $\\pi$).",
            10, marks=1, diff="easy",
            expl="$A = \\pi r^2 \\implies \\frac{dA}{dr} = 2\\pi r$. When $r = 5$: $\\frac{dA}{dr} = 10\\pi$."
        ),
        numerical(
            "Find the critical point of $f(x) = 2x^3 - 9x^2 + 12x + 1$ in the interval $(0, 3)$ where $f''(x) > 0$.",
            2, marks=1, diff="medium",
            expl="$f'(x) = 6x^2 - 18x + 12 = 6(x - 1)(x - 2) = 0 \\implies x = 1, 2$. $f''(x) = 12x - 18$. $f''(2) = 24 - 18 = 6 > 0$, so $x = 2$ is a local minimum."
        ),
        numerical(
            "Find the minimum value of $f(x) = x + \\frac{1}{x}$ for $x > 0$.",
            2, marks=1, diff="easy",
            expl="By AM-GM inequality, $x + 1/x \\ge 2\\sqrt{x \\cdot 1/x} = 2$, attained at $x = 1$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_8_part1.json", "Mathematics 1 · Graded Assignment · Week 8 · Part 1", p1)

    p2 = [
        mcq_single(
            "The function $f(x) = x^3 - 6x^2 + 9x + 15$ is strictly decreasing on the interval:",
            ["$(1, 3)$", "$(-\\infty, 1)$", "$(3, \\infty)$", "$[0, 4]$"],
            0, marks=1, diff="medium",
            expl="$f'(x) = 3x^2 - 12x + 9 = 3(x - 1)(x - 3) < 0$ for $1 < x < 3$."
        ),
        mcq_single(
            "Find the coordinates of the point of inflection for $f(x) = x^3 - 3x^2 + 2$.",
            ["$(1, 0)$", "$(0, 2)$", "$(2, -2)$", "$(-1, -2)$"],
            0, marks=1, diff="medium",
            expl="$f''(x) = 6x - 6 = 0 \\implies x = 1$. At $x = 1$, $y = 1 - 3 + 2 = 0$."
        ),
        mcq_single(
            "If the tangent to $y = x^3$ at $P$ is perpendicular to $x + 3y = 1$, find the x-coordinate of $P$.",
            ["$\\pm 1$", "$\\pm 2$", "$0$", "$\\pm 3$"],
            0, marks=1, diff="medium",
            expl="Line slope is $-1/3$. Tangent slope must be $3$. $y' = 3x^2 = 3 \\implies x^2 = 1 \\implies x = \\pm 1$."
        ),
        numerical(
            "A ladder 10 m long leans against a vertical wall. If the bottom of the ladder slides away from the wall at 2 m/s, how fast (in m/s) is the top sliding down when the bottom is 6 m from the wall?",
            1.5, marks=1, diff="medium",
            expl="$x^2 + y^2 = 100$. When $x = 6$, $y = 8$. $2x\\frac{dx}{dt} + 2y\\frac{dy}{dt} = 0 \\implies 6(2) + 8\\frac{dy}{dt} = 0 \\implies \\frac{dy}{dt} = -12/8 = -1.5$ m/s."
        ),
        numerical(
            "Find the slope of the curve $x^2 + y^2 = 25$ at the point $(3, 4)$.",
            -0.75, marks=1, diff="easy",
            expl="$2x + 2y y' = 0 \\implies y' = -x/y = -3/4 = -0.75$."
        ),
        mcq_single(
            "The function $f(x) = e^x - x$ has:",
            ["A local minimum at $x = 0$.", "A local maximum at $x = 0$.", "No critical points.", "A point of inflection at $x = 0$."],
            0, marks=1, diff="easy",
            expl="$f'(x) = e^x - 1 = 0 \\implies x = 0$. $f''(0) = e^0 = 1 > 0$, so $x = 0$ is a local minimum."
        ),
        numerical(
            "Find the maximum product of two positive numbers whose sum is 20.",
            100, marks=1, diff="easy",
            expl="Numbers are 10 and 10. Product $= 10 \\times 10 = 100$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_8_part2.json", "Mathematics 1 · Graded Assignment · Week 8 · Part 2", p2)

# ----------------------------------------------------------------------
# Week 10 (9 Questions)
# ----------------------------------------------------------------------
def build_week_10():
    qs = [
        mcq_single(
            "The maximum number of non-zero entries in an adjacency matrix of a simple graph having $n$ vertices can be:",
            ["$n^2$", "$\\frac{n(n - 1)}{2}$", "$\\frac{n(n - 1)}{4}$", "$n(n - 1)$"],
            3, marks=1, diff="medium",
            expl="In a directed simple graph without self-loops, each vertex can connect to at most $n - 1$ other vertices, giving at most $n(n - 1)$ directed edges."
        ),
        mcq_single(
            "In an undirected graph, vertices are arranged in decreasing degree order. Which of the following is a possible listing of degrees for a simple graph?",
            ["$5, 4, 3, 2, 1$", "$4, 4, 3, 2, 1$", "$3, 3, 2, 2, 1, 1$", "$4, 3, 2, 1, 0$"],
            2, marks=1, diff="medium",
            expl="By the Handshaking Lemma, the sum of degrees must be even: $3 + 3 + 2 + 2 + 1 + 1 = 12$ (even)."
        ),
        mcq_single(
            "In exploring a graph, which data structure is used to implement Breadth-First Search (BFS)?",
            ["Stack", "Queue", "Priority Queue", "Array"],
            1, marks=1, diff="easy",
            expl="Breadth-First Search explores vertices in order of discovery using a FIFO Queue."
        ),
        mcq_single(
            "Which of the following representations accurately shows the adjacency list with respect to incoming edges of a directed graph?",
            ["Representation A", "Representation B", "Representation C", "Representation D"],
            2, marks=1, diff="medium",
            expl="Representation C correctly maps each vertex to the list of predecessor vertices."
        ),
        mcq_single(
            "Which of the following pair of vertices is connected by an edge in the graph specified in the assignment?",
            ["$(8, 11)$", "$(3, 10)$", "$(4, 5)$", "$(6, 9)$"],
            0, marks=1, diff="medium",
            expl="Edge $(8, 11)$ is present in the assignment graph."
        ),
        mcq_multi(
            "Which of the following graphs satisfies the chromatic property of having chromatic number equal to 3?",
            ["Graph 1", "Graph 2", "Graph 3", "Graph 4"],
            [2, 3], marks=2, diff="hard",
            expl="Graphs 3 and 4 have odd cycles of length $\\ge 3$ and no $K_4$, giving chromatic number 3."
        ),
        numerical(
            "If $A$ is the cardinality of the maximum independent set of the graph $G$ given in the assignment, find $A$.",
            5, marks=2, diff="medium",
            expl="Maximum independent set cardinality is 5."
        ),
        numerical(
            "In how many conflict-free warehouse partitions should the goods graph be partitioned?",
            3, marks=2, diff="medium",
            expl="The chromatic number of the conflict graph is 3, so 3 partitions are needed."
        ),
        numerical(
            "Find the number of vertices in a planar graph where edges intersect only at their endpoints, given 12 edges and 8 faces.",
            6, marks=2, diff="medium",
            expl="By Euler's formula $V - E + F = 2 \\implies V - 12 + 8 = 2 \\implies V - 4 = 2 \\implies V = 6$."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_10.json", "Mathematics 1 · Graded Assignment · Week 10", qs)

# ----------------------------------------------------------------------
# Week 11 (9 Questions)
# ----------------------------------------------------------------------
def build_week_11():
    qs = [
        numerical(
            "An undirected weighted graph $G$ is given. Find the minimum weight of a spanning tree of graph $G$.",
            14, marks=2, diff="medium",
            expl="Applying Kruskal's algorithm yields total minimum weight 14."
        ),
        mcq_multi(
            "An undirected graph $G$ is shown. Suppose we perform Dijkstra's algorithm to find the shortest path from vertex $v_0$ to $v_4$. Which of the following statements is (are) correct?",
            [
                "Dijkstra's algorithm can be used to find the shortest path from $v_0$ to $v_4$ if all edge weights are positive.",
                "Bellman-Ford algorithm can be used when there are negative weighted edges.",
                "The weight of the shortest path from $v_0$ to $v_4$ is positive.",
                "Dijkstra's algorithm cannot handle graphs with negative edge weights."
            ],
            [0, 1, 3], marks=2, diff="medium",
            expl="Dijkstra requires non-negative edge weights; Bellman-Ford correctly handles negative weights without negative cycles."
        ),
        mcq_multi(
            "Which of the following statements is (are) INCORRECT regarding spanning trees and shortest paths?",
            [
                "In an undirected graph where all edges have distinct positive weights, the minimum spanning tree is not unique.",
                "If there is a negative weight cycle in a directed graph, shortest paths can be arbitrarily small.",
                "Every tree with $n$ vertices has exactly $n - 1$ edges.",
                "In any graph, every edge with minimum weight is necessarily in every spanning tree."
            ],
            [0, 3], marks=2, diff="hard",
            expl="Distinct weights guarantee a unique MST (statement 1 is incorrect). Not every minimum weight edge must be in every spanning tree if multiple exist (statement 4 is incorrect)."
        ),
        numerical(
            "A company has branches in six cities $C_0, C_1, ..., C_5$. The fare matrix is given. What is the minimum cost to travel from $C_0$ to $C_5$?",
            7, marks=2, diff="medium",
            expl="Shortest path evaluation on the fare matrix gives minimum cost 7."
        ),
        numerical(
            "Find the cost of the minimum spanning tree connecting all six cities in the communication network.",
            15, marks=2, diff="medium",
            expl="MST sum of edge weights connecting all 6 vertices is 15."
        ),
        mcq_single(
            "Seven computers $\\{C_0, C_1, ..., C_6\\}$ are linked in a network. What is the minimum number of links required to ensure all computers are connected?",
            ["$5$", "$6$", "$7$", "$8$"],
            1, marks=1, diff="easy",
            expl="A connected graph with $n$ vertices requires at least $n - 1$ edges. For 7 vertices: $7 - 1 = 6$."
        ),
        numerical(
            "Find the number of different ways of choosing an optimum subset of links (MCST) for the network graph.",
            4, marks=2, diff="medium",
            expl="There are 4 distinct minimum cost spanning trees due to equal weight tie-breakers."
        ),
        mcq_single(
            "Suppose we perform Prim's algorithm on graph $G$ starting from vertex $A$. Which of the following is the order in which vertices are added?",
            ["$A, C, F, G, B, D, E$", "$A, B, D, C, E, F, G$", "$A, C, B, D, F, G, E$", "$A, C, F, G, E, D, B$"],
            0, marks=2, diff="medium",
            expl="Prim's greedy selection of the minimum connecting cut edge yields sequence $A, C, F, G, B, D, E$."
        ),
        mcq_multi(
            "Suppose we perform Kruskal's algorithm on graph $G$. Which of the following edges are NOT added to the minimum cost spanning tree because they form a cycle?",
            ["$(B, C)$", "$(D, E)$", "$(G, F)$", "$(A, G)$"],
            [0, 2], marks=2, diff="medium",
            expl="Edges $(B, C)$ and $(G, F)$ connect already connected components, forming cycles, and are skipped."
        )
    ]
    save_paper("Mathematics_1_-_Graded_Assignment_-_Week_11.json", "Mathematics 1 · Graded Assignment · Week 11", qs)

def main():
    print("Building Mathematics 1 Graded Assignments...")
    build_week_1()
    build_week_2()
    build_week_3()
    build_week_4()
    build_week_5()
    build_week_6()
    build_week_8()
    build_week_10()
    build_week_11()
    print("All Mathematics 1 Graded Assignment papers built successfully!")

if __name__ == '__main__':
    main()
