#!/usr/bin/env python3
"""
Restructure Quiz Lab Question Papers according to user requirements:
1. Every paper has MAX 10 questions. If a paper has > 10 questions, split into balanced
   parts of 5-10 questions each (Part 1, Part 2, etc.).
2. If papers have < 5 questions (e.g. 1-2 questions), merge papers of the same subject
   and section into a single combined paper (e.g. End Term Combined PYQ).
3. If the merged pool for a section still has < 5 questions, supplement high-quality
   syllabus questions so that every single paper strictly has between 5 and 10 questions.
4. Clean up duplicate booklet files and broken folder names.
"""

import os
import glob
import json
import math
import re
import shutil
from collections import defaultdict

SECTION_DISPLAY = {
    'quiz1': 'Quiz 1',
    'quiz2': 'Quiz 2',
    'endterm': 'End Term',
    'practice_graded': 'Graded Assignment',
    'practice': 'Practice Assignment',
    'mock_test': 'Mock Test'
}

# Dedicated question pools for subjects that need supplements
SUPPLEMENT_POOLS = {
    'Business Data Management': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In relational database design, which normal form eliminates transitive functional dependencies on the primary key?"}],
            "options": [
                [{"kind": "text", "value": "Third Normal Form (3NF)"}],
                [{"kind": "text", "value": "First Normal Form (1NF)"}],
                [{"kind": "text", "value": "Second Normal Form (2NF)"}],
                [{"kind": "text", "value": "Boyce-Codd Normal Form (BCNF)"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "3NF requires the relation to be in 2NF and have no non-prime attribute transitively dependent on any candidate key."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which schema design in data warehousing contains a centralized fact table connected directly to non-normalized dimension tables?"}],
            "options": [
                [{"kind": "text", "value": "Star schema"}],
                [{"kind": "text", "value": "Snowflake schema"}],
                [{"kind": "text", "value": "Galaxy schema"}],
                [{"kind": "text", "value": "3NF relational schema"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "In a star schema, dimension tables are completely denormalized and directly reference a central fact table."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In an OLAP environment, which operation reduces the dimensionality of data by aggregating data along a specific dimension (e.g., from days to months)?"}],
            "options": [
                [{"kind": "text", "value": "Roll-up (Drill-up)"}],
                [{"kind": "text", "value": "Drill-down"}],
                [{"kind": "text", "value": "Slice and Dice"}],
                [{"kind": "text", "value": "Pivot"}],
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Roll-up aggregates data along dimension hierarchies, moving from fine-grained to coarser granularity."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which SQL clause is used to filter aggregated records produced by a `GROUP BY` statement?"}],
            "options": [
                [{"kind": "text", "value": "HAVING"}],
                [{"kind": "text", "value": "WHERE"}],
                [{"kind": "text", "value": "QUALIFY"}],
                [{"kind": "text", "value": "ORDER BY"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "HAVING filters groups after aggregation, whereas WHERE filters individual rows before grouping."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In a transactional database (OLTP) versus an analytical database (OLAP), which characteristic is typical of OLTP systems?"}],
            "options": [
                [{"kind": "text", "value": "Frequent, short, atomic read-write operations (high concurrency)"}],
                [{"kind": "text", "value": "Heavy multi-table aggregation across historical decades"}],
                [{"kind": "text", "value": "Batch ETL loads conducted once per week with no updates"}],
                [{"kind": "text", "value": "Denormalized star schemas optimized for columnar storage"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "OLTP is designed for day-to-day transactional throughput with ACID guarantees and high concurrency."}]
        }
    ],
    'Deep Learning': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which activation function is most susceptible to the 'dying neuron' problem where neurons become permanently inactive during backpropagation?"}],
            "options": [
                [{"kind": "text", "value": "Standard ReLU: $f(x) = \\max(0, x)$"}],
                [{"kind": "text", "value": "Leaky ReLU: $f(x) = \\max(0.01x, x)$"}],
                [{"kind": "text", "value": "Parametric ReLU (PReLU)"}],
                [{"kind": "text", "value": "Exponential Linear Unit (ELU)"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "For $x < 0$, ReLU has gradient 0. If a large gradient updates weights such that the neuron is negative for all inputs, it never fires again."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In a Convolutional Neural Network, what is the spatial output dimension given an input of size $W \\times W$, filter size $F$, padding $P$, and stride $S$?"}],
            "options": [
                [{"kind": "text", "value": "$\\lfloor \\frac{W - F + 2P}{S} \\rfloor + 1$"}],
                [{"kind": "text", "value": "$\\lfloor \\frac{W - F + P}{S} \\rfloor + 1$"}],
                [{"kind": "text", "value": "$\\lfloor \\frac{W + F - 2P}{S} \\rfloor$"}],
                [{"kind": "text", "value": "$\\frac{W \\times F}{S} + P$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "The formula for output dimension with padding P and stride S is ((W - F + 2P) / S) + 1."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary benefit of Batch Normalization during deep neural network training?"}],
            "options": [
                [{"kind": "text", "value": "Reduces internal covariate shift and allows higher learning rates with stable gradient flow"}],
                [{"kind": "text", "value": "Guarantees that the global minimum of non-convex loss is always reached"}],
                [{"kind": "text", "value": "Replaces backpropagation with closed-form matrix inversion"}],
                [{"kind": "text", "value": "Eliminates the need for any non-linear activation functions"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Batch Normalization stabilizes layer inputs across mini-batches, smoothing the loss landscape."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In the scaled dot-product attention formula $\\text{Attention}(Q, K, V) = \\text{softmax}\\left(\\frac{QK^T}{\\sqrt{d_k}}\\right)V$, why is the division by $\\sqrt{d_k}$ crucial?"}],
            "options": [
                [{"kind": "text", "value": "To prevent large dot products that push the softmax function into regions with extremely small gradients"}],
                [{"kind": "text", "value": "To enforce that the attention weights sum to zero"}],
                [{"kind": "text", "value": "To convert queries and keys into orthogonal coordinate spaces"}],
                [{"kind": "text", "value": "To invert the dimensionality of the sequence length"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "hard",
            "explanation": [{"kind": "text", "value": "For large $d_k$, dot products grow large, causing softmax to yield near-one-hot distributions with vanishing gradients."}]
        }
    ],
    'Dlp': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In PyTorch, why is `optimizer.zero_grad()` invoked before `loss.backward()` during training iterations?"}],
            "options": [
                [{"kind": "text", "value": "Because PyTorch accumulates gradients in `.grad` buffers across backwards passes by default"}],
                [{"kind": "text", "value": "To reset layer weights to zero"}],
                [{"kind": "text", "value": "To clear GPU cache memory"}],
                [{"kind": "text", "value": "To initialize the loss computation"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Gradients accumulate by default in PyTorch, so zeroing them ensures each iteration computes gradients strictly for the current batch."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "For image reconstruction and super-resolution, how is Peak Signal-to-Noise Ratio (PSNR) calculated from Mean Squared Error (MSE) for an 8-bit image with $MAX_I = 255$?"}],
            "options": [
                [{"kind": "text", "value": "$\\text{PSNR} = 10 \\cdot \\log_{10}\\left(\\frac{255^2}{\\text{MSE}}\\right)$ dB"}],
                [{"kind": "text", "value": "$\\text{PSNR} = 20 \\cdot \\log_{10}(\\text{MSE})$ dB"}],
                [{"kind": "text", "value": "$\\text{PSNR} = \\frac{255}{\\text{MSE}}$ dB"}],
                [{"kind": "text", "value": "$\\text{PSNR} = 100 \\times (1 - \\text{MSE})$ dB"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "PSNR is defined as 10 * log10(MAX_I^2 / MSE)."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What does the Structural Similarity Index Measure (SSIM) evaluate in computer vision compared to pixel-wise MSE?"}],
            "options": [
                [{"kind": "text", "value": "Luminance, contrast, and structural degradation matching human visual perception"}],
                [{"kind": "text", "value": "The exact number of floating point operations per second"}],
                [{"kind": "text", "value": "The compressed file size in kilobytes"}],
                [{"kind": "text", "value": "The training time per epoch on CUDA devices"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "SSIM captures perceived quality changes in structural information, luminance, and contrast."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In PyTorch `DataLoader`, what configuration accelerates CPU-to-GPU memory transfer when running on CUDA?"}],
            "options": [
                [{"kind": "text", "value": "`pin_memory=True` with `num_workers > 0`"}],
                [{"kind": "text", "value": "`batch_size=1` with `shuffle=False`"}],
                [{"kind": "text", "value": "`drop_last=True` with `num_workers=0`"}],
                [{"kind": "text", "value": "`sampler=None` and `pin_memory=False`"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Pinned page-locked host memory enables fast DMA copies directly to GPU memory."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary role of `torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm)`?"}],
            "options": [
                [{"kind": "text", "value": "Prevents exploding gradients by proportionally scaling down gradient vectors when their norm exceeds `max_norm`"}],
                [{"kind": "text", "value": "Rounds all gradient values to nearest integer"}],
                [{"kind": "text", "value": "Sets negative gradients to zero like a ReLU"}],
                [{"kind": "text", "value": "Doubles the learning rate when gradients become small"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Gradient clipping stabilizes recurrent and deep networks by capping the total gradient norm."}]
        }
    ],
    'Dlgenai': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In Low-Rank Adaptation (LoRA) for fine-tuning Large Language Models, what is the weight update decomposition for a weight matrix $W_0 \\in \\mathbb{R}^{d \\times k}$ with rank $r \\ll \\min(d, k)$?"}],
            "options": [
                [{"kind": "text", "value": "$\\Delta W = B \\times A$, where $B \\in \\mathbb{R}^{d \\times r}$ and $A \\in \\mathbb{R}^{r \\times k}$"}],
                [{"kind": "text", "value": "$\\Delta W = B + A$, where $B, A \\in \\mathbb{R}^{d \\times k}$"}],
                [{"kind": "text", "value": "$\\Delta W = W_0^{-1} \\cdot r$"}],
                [{"kind": "text", "value": "$\\Delta W = \\text{diag}(r) \\cdot W_0$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "LoRA freezes $W_0$ and trains low-rank matrices $A$ and $B$, drastically reducing trainable parameters."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In autoregressive text generation from an LLM, what does a temperature setting $T \\to 0$ produce?"}],
            "options": [
                [{"kind": "text", "value": "Greedy decoding, selecting the token with the highest logit at every step"}],
                [{"kind": "text", "value": "Completely uniform random token selection"}],
                [{"kind": "text", "value": "Higher diversity with elevated hallucinations"}],
                [{"kind": "text", "value": "Zero probability for all vocabulary items"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "As temperature approaches zero, softmax approaches an argmax (greedy sampling)."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary objective of Rotary Position Embedding (RoPE) in modern LLM architectures like LLaMA?"}],
            "options": [
                [{"kind": "text", "value": "Encoding absolute and relative positional information by rotating query and key vectors in complex space"}],
                [{"kind": "text", "value": "Compressing vocabulary embeddings into 8-bit integers"}],
                [{"kind": "text", "value": "Replacing multi-head attention with causal convolutions"}],
                [{"kind": "text", "value": "Removing positional dependence entirely for permutation invariance"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "hard",
            "explanation": [{"kind": "text", "value": "RoPE applies an orthogonal rotation to queries and keys such that their inner product naturally captures relative token distance."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In Retrieval-Augmented Generation (RAG), which metric is standard for comparing the semantic similarity between query and passage dense vector embeddings?"}],
            "options": [
                [{"kind": "text", "value": "Cosine similarity: $\\frac{u \\cdot v}{\\|u\\| \\|v\\|}$"}],
                [{"kind": "text", "value": "Levenshtein edit distance"}],
                [{"kind": "text", "value": "Hamming distance on one-hot vectors"}],
                [{"kind": "text", "value": "Jaccard coefficient on character n-grams"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Dense embeddings encode semantic similarity as the cosine of the angle between normalized vector representations."}]
        }
    ],
    'Game Theory And Strategy': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In game theory, what is a Nash Equilibrium?"}],
            "options": [
                [{"kind": "text", "value": "A profile of strategies where no player can strictly benefit by unilaterally deviating"}],
                [{"kind": "text", "value": "An outcome where the sum of payoffs across all players is maximized"}],
                [{"kind": "text", "value": "A strategy profile where every player receives identical payoff"}],
                [{"kind": "text", "value": "The outcome reached only when players coordinate through binding contracts"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "At a Nash Equilibrium, each player's chosen strategy is a best response to the strategies chosen by all other players."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In the classical Prisoner's Dilemma, what is the dominant strategy for each prisoner?"}],
            "options": [
                [{"kind": "text", "value": "Defect (Confess), regardless of what the other prisoner chooses"}],
                [{"kind": "text", "value": "Cooperate (Stay Silent), provided the other prisoner stays silent"}],
                [{"kind": "text", "value": "Randomize 50-50 between Cooperating and Defecting"}],
                [{"kind": "text", "value": "Alternate between Cooperating and Defecting across rounds"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Defection strictly dominates Cooperation because it yields a better individual payoff whether the opponent confesses or remains silent."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "According to the Minimax Theorem for two-player zero-sum games with finite strategies, what is guaranteed to exist?"}],
            "options": [
                [{"kind": "text", "value": "A unique game value $V$ achievable in mixed (or pure) strategies where $\\max \\min = \\min \\max$"}],
                [{"kind": "text", "value": "A strictly positive total payoff for both players combined"}],
                [{"kind": "text", "value": "At least one pure strategy Nash equilibrium with no randomization"}],
                [{"kind": "text", "value": "A Pareto-optimal cooperative agreement"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Von Neumann's Minimax theorem establishes that every finite zero-sum game has a minimax value in mixed strategies."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In a sequential game represented in extensive form, what backward-induction equilibrium concept refines Nash equilibria by eliminating non-credible threats?"}],
            "options": [
                [{"kind": "text", "value": "Subgame Perfect Nash Equilibrium (SPNE)"}],
                [{"kind": "text", "value": "Correlated Equilibrium"}],
                [{"kind": "text", "value": "Weakly Dominated Equilibrium"}],
                [{"kind": "text", "value": "Evolutionary Stable Strategy (ESS)"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "An SPNE induces a Nash equilibrium in every proper subgame, ruling out incredible threats off the equilibrium path."}]
        }
    ],
    'Machine Learning Practice': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "When evaluating a classifier on an imbalanced dataset where false negatives are critically dangerous (such as cancer detection), which metric should be prioritized?"}],
            "options": [
                [{"kind": "text", "value": "Recall (Sensitivity): $\\frac{TP}{TP + FN}$"}],
                [{"kind": "text", "value": "Precision: $\\frac{TP}{TP + FP}$"}],
                [{"kind": "text", "value": "Accuracy: $\\frac{TP + TN}{TP + TN + FP + FN}$"}],
                [{"kind": "text", "value": "Specificity: $\\frac{TN}{TN + FP}$"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Recall penalizes false negatives, ensuring that the model captures as many actual positive cases as possible."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In scikit-learn, why must `fit_transform()` be called ONLY on training data, while test data is processed using `transform()` alone?"}],
            "options": [
                [{"kind": "text", "value": "To prevent data leakage by computing statistics (mean, variance) strictly from the training distribution"}],
                [{"kind": "text", "value": "Because `fit_transform()` always shuffles rows randomly"}],
                [{"kind": "text", "value": "To accelerate matrix multiplication during inference"}],
                [{"kind": "text", "value": "Because `fit_transform()` discards categorical column headers"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "Fitting scalers on test data leaks test distribution information into model preprocessing."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which regularization technique adds an L1 penalty proportional to the absolute values of the coefficients, thereby inducing feature sparsity?"}],
            "options": [
                [{"kind": "text", "value": "Lasso Regression (L1)"}],
                [{"kind": "text", "value": "Ridge Regression (L2)"}],
                [{"kind": "text", "value": "Ordinary Least Squares"}],
                [{"kind": "text", "value": "Polynomial Regression"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Lasso (L1) drives uninformative feature weights strictly to zero, effectively acting as embedded feature selection."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary role of the ROC-AUC score in binary classification?"}],
            "options": [
                [{"kind": "text", "value": "Measures the model's ability to rank positive instances above negative instances across all decision thresholds"}],
                [{"kind": "text", "value": "Measures calibrated probability error at a fixed threshold of 0.5"}],
                [{"kind": "text", "value": "Computes the exact fraction of correctly predicted test labels"}],
                [{"kind": "text", "value": "Calculates the ratio of true negatives to false positives at 95% confidence"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "ROC-AUC computes the area under the True Positive Rate vs False Positive Rate curve, evaluating threshold-independent ranking."}]
        }
    ],
    'Modern Application Development 1': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In RESTful API conventions, which HTTP verb and status code represent a successful update that modifies an existing resource completely?"}],
            "options": [
                [{"kind": "text", "value": "PUT with HTTP 200 OK (or 204 No Content)"}],
                [{"kind": "text", "value": "GET with HTTP 201 Created"}],
                [{"kind": "text", "value": "POST with HTTP 304 Not Modified"}],
                [{"kind": "text", "value": "DELETE with HTTP 405 Method Not Allowed"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "PUT is idempotent and replaces an existing target resource with the requested payload, returning 200 OK or 204 No Content."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In Flask / Jinja2 web applications, what mechanism prevents Cross-Site Request Forgery (CSRF) on form submissions?"}],
            "options": [
                [{"kind": "text", "value": "Embedding a cryptographically signed, session-tied CSRF token in the form verified server-side"}],
                [{"kind": "text", "value": "Storing all passwords in client-side localStorage"}],
                [{"kind": "text", "value": "Allowing wildcard `Access-Control-Allow-Origin: *` headers on POST endpoints"}],
                [{"kind": "text", "value": "Encrypting the database connection string with MD5"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "CSRF tokens ensure that state-changing requests originate from an authentic user session inside the web application."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In SQLite / SQLAlchemy, what command or constraint ensures that deleting a parent record automatically removes all associated child records?"}],
            "options": [
                [{"kind": "text", "value": "`ON DELETE CASCADE` on the foreign key constraint"}],
                [{"kind": "text", "value": "`ON DELETE SET NULL` on the primary key"}],
                [{"kind": "text", "value": "`CHECK (child_id IS NULL)`"}],
                [{"kind": "text", "value": "`UNIQUE INDEX` on the parent primary key"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "CASCADE triggers automatic deletion of dependent foreign key rows when the referenced parent row is deleted."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In client-server web architecture, what is the key difference between Server-Side Rendering (SSR) and Single Page Applications (SPA)?"}],
            "options": [
                [{"kind": "text", "value": "In SSR, full HTML is rendered on the server per request; in SPAs, the browser dynamically updates the DOM using JSON from an API"}],
                [{"kind": "text", "value": "In SSR, no database is required; in SPAs, all data must reside in browser cookies"}],
                [{"kind": "text", "value": "SSR cannot use CSS; SPAs cannot use JavaScript"}],
                [{"kind": "text", "value": "SPAs execute SQL queries directly from client-side JavaScript"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "SSR builds complete HTML on the backend, while SPAs load a static shell and fetch data via REST APIs."}]
        }
    ],
    'Modern Application Development 2': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In Vue 3 Composition API, what is the fundamental difference between `ref()` and `reactive()`?"}],
            "options": [
                [{"kind": "text", "value": "`ref()` wraps primitives or objects and requires `.value` access in script; `reactive()` takes only objects and provides direct property access"}],
                [{"kind": "text", "value": "`ref()` is immutable; `reactive()` is mutable"}],
                [{"kind": "text", "value": "`reactive()` cannot be used inside template expressions"}],
                [{"kind": "text", "value": "`ref()` only works for integers and booleans, not arrays"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "`ref()` creates a reactive reference with a `.value` getter/setter, while `reactive()` returns a deep reactive Proxy of an object."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In JSON Web Token (JWT) authentication, what prevents a client from tampering with the payload claims (e.g. changing `user_id` or `role`)?"}],
            "options": [
                [{"kind": "text", "value": "The cryptographic signature verified by the server using its secret key"}],
                [{"kind": "text", "value": "The base64url encoding of the payload"}],
                [{"kind": "text", "value": "Storing the token in a cookie with the `SameSite=None` flag"}],
                [{"kind": "text", "value": "The expiration timestamp (exp) claim"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "The signature is computed over header and payload with a server secret; altering the payload invalidates the signature."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What asynchronous background task queue is standard in modern Python web architectures (such as Flask or Django) for running long jobs without blocking HTTP responses?"}],
            "options": [
                [{"kind": "text", "value": "Celery with Redis or RabbitMQ as the message broker"}],
                [{"kind": "text", "value": "Synchronous `time.sleep()` in the request handler"}],
                [{"kind": "text", "value": "In-memory global dictionaries in the WSGI worker"}],
                [{"kind": "text", "value": "Direct client-side setTimeout loops"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Celery offloads CPU-bound or I/O-heavy tasks to distributed worker processes backed by a message broker."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "What is the primary role of an API Gateway in a microservices deployment?"}],
            "options": [
                [{"kind": "text", "value": "Routing client requests, handling SSL termination, rate limiting, and centralized authentication"}],
                [{"kind": "text", "value": "Executing raw SQL statements across all microservice databases"}],
                [{"kind": "text", "value": "Compiling Vue single-file components into WebAssembly"}],
                [{"kind": "text", "value": "Replacing database foreign key constraints"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "API Gateways serve as a reverse proxy, decoupling client entrypoints from internal microservices."}]
        }
    ],
    'System Commands': [
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In Linux bash, what does the syntax `command > output.txt 2>&1` accomplish?"}],
            "options": [
                [{"kind": "text", "value": "Redirects both standard output (stdout) and standard error (stderr) to `output.txt`"}],
                [{"kind": "text", "value": "Appends output to `output.txt` twice"}],
                [{"kind": "text", "value": "Sends standard input from file descriptor 2 to file descriptor 1"}],
                [{"kind": "text", "value": "Runs the command in background mode with process ID 2"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "medium",
            "explanation": [{"kind": "text", "value": "`> output.txt` redirects fd 1 (stdout) to the file, and `2>&1` redirects fd 2 (stderr) to the same destination as fd 1."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which octal permission mode gives the file owner read, write, and execute permissions, while group and others receive only read and execute permissions?"}],
            "options": [
                [{"kind": "text", "value": "755 (`rwxr-xr-x`)"}],
                [{"kind": "text", "value": "644 (`rw-r--r--`)"}],
                [{"kind": "text", "value": "777 (`rwxrwxrwx`)"}],
                [{"kind": "text", "value": "700 (`rwx------`)"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Owner: 4+2+1=7; Group: 4+0+1=5; Others: 4+0+1=5. Result: 755."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "Which signal number is sent by default when running `kill <PID>` in Linux?"}],
            "options": [
                [{"kind": "text", "value": "SIGTERM (signal 15) allowing clean termination"}],
                [{"kind": "text", "value": "SIGKILL (signal 9) forcing immediate termination"}],
                [{"kind": "text", "value": "SIGHUP (signal 1) indicating terminal hangup"}],
                [{"kind": "text", "value": "SIGINT (signal 2) from Ctrl+C"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "Default kill signal is 15 (SIGTERM), which requests graceful cleanup. Signal 9 (SIGKILL) cannot be caught or ignored."}]
        },
        {
            "type": "mcq_single",
            "prompt": [{"kind": "text", "value": "In bash, what does the special variable `$?` hold?"}],
            "options": [
                [{"kind": "text", "value": "The exit status code of the most recently executed foreground command (0 for success)"}],
                [{"kind": "text", "value": "The process ID (PID) of the current shell"}],
                [{"kind": "text", "value": "The number of arguments passed to the script"}],
                [{"kind": "text", "value": "The PID of the last background command"}]
            ],
            "correct_answer": 0,
            "marks": 2,
            "difficulty": "easy",
            "explanation": [{"kind": "text", "value": "`$?` evaluates to the numeric exit code of the last command; 0 means successful completion."}]
        }
    ]
}

def clean_subject(name):
    name = re.sub(r'[\r\n\t]+', ' ', name).strip()
    name = re.sub(r'\s+', ' ', name)
    return name

def balance_split(questions, max_len=10):
    n = len(questions)
    if n <= max_len:
        return [questions]
    k = math.ceil(n / float(max_len))
    b = n // k
    r = n % k
    chunks = []
    idx = 0
    for i in range(k):
        size = b + 1 if i < r else b
        chunks.append(questions[idx:idx + size])
        idx += size
    return chunks

def get_supplement_for_subject(subj_clean, needed_count, existing_prompts):
    # Try exact pool first
    pool = SUPPLEMENT_POOLS.get(subj_clean, [])
    # If not found, try keyword match
    if not pool:
        for k, v in SUPPLEMENT_POOLS.items():
            if k.lower() in subj_clean.lower() or subj_clean.lower() in k.lower():
                pool = v
                break
    
    # Also check foundation JSON files for Math, Stats, CT, Python
    if len(pool) < needed_count:
        borrowed = borrow_from_foundation(subj_clean, existing_prompts)
        pool = list(pool) + borrowed

    added = []
    for q in pool:
        prompt_txt = json.dumps(q.get('prompt', []))
        if prompt_txt not in existing_prompts:
            added.append(q)
            existing_prompts.add(prompt_txt)
            if len(added) >= needed_count:
                break
    return added

_FOUNDATION_CACHE = {}
def borrow_from_foundation(subj_clean, existing_prompts):
    global _FOUNDATION_CACHE
    subj_lower = subj_clean.lower()
    target_folder = None
    if 'math' in subj_lower and '2' in subj_lower:
        target_folder = 'bulk_quizzes/Mathematics 2'
    elif 'math' in subj_lower:
        target_folder = 'bulk_quizzes/Mathematics 1'
    elif 'stat' in subj_lower and '2' in subj_lower:
        target_folder = 'bulk_quizzes/Statistics 2'
    elif 'stat' in subj_lower:
        target_folder = 'bulk_quizzes/Statistics 1'
    elif 'comp' in subj_lower or 'ct' in subj_lower:
        target_folder = 'bulk_quizzes/Computational Thinking'
    elif 'py' in subj_lower:
        target_folder = 'bulk_quizzes/Python'

    if not target_folder or not os.path.isdir(target_folder):
        return []

    if target_folder not in _FOUNDATION_CACHE:
        qs = []
        for f in glob.glob(f"{target_folder}/*.json"):
            if "booklet" in f: continue
            try:
                with open(f, 'r', encoding='utf-8') as fp:
                    d = json.load(fp)
                for q in d.get('questions', []):
                    qs.append(q)
            except Exception:
                pass
        _FOUNDATION_CACHE[target_folder] = qs

    res = []
    for q in _FOUNDATION_CACHE[target_folder]:
        ptxt = json.dumps(q.get('prompt', []))
        if ptxt not in existing_prompts:
            res.append(q)
            if len(res) >= 10:
                break
    return res

def run_restructuring():
    print("=== STARTING QUIZ RESTRUCTURING ===")
    
    # Step 1: Remove exact booklet duplicates in bulk_quizzes/Python/
    py_booklets = glob.glob("bulk_quizzes/Python/* - booklet.json")
    for b in py_booklets:
        os.remove(b)
    print(f"Removed {len(py_booklets)} duplicate Python booklet files.")

    # Step 2: Handle broken folders in Diploma
    broken_folders = [
        ("bulk_quizzes/Diploma/Hello Admin", "bulk_quizzes/Diploma/Machine Learning Foundations", "Machine Learning Foundations"),
        ("bulk_quizzes/Diploma/False", "bulk_quizzes/Diploma/Business Data Management", "Business Data Management")
    ]
    for pattern, target_dir, correct_subj in broken_folders:
        matching = glob.glob(pattern + "*")
        for mdir in matching:
            if os.path.isdir(mdir):
                for f in glob.glob(f"{mdir}/*.json"):
                    dest = os.path.join(target_dir, os.path.basename(f))
                    # fix content subject
                    with open(f, 'r', encoding='utf-8') as fp:
                        d = json.load(fp)
                    d['subject'] = correct_subj
                    with open(dest, 'w', encoding='utf-8') as fp:
                        json.dump(d, fp, indent=2, ensure_ascii=False)
                shutil.rmtree(mdir)
                print(f"Cleaned up broken directory {mdir} -> moved files to {target_dir}")

    # Step 3: Scan all JSON files by directory and section
    all_files = sorted(glob.glob("bulk_quizzes/**/*.json", recursive=True))
    groups = defaultdict(list)
    for f in all_files:
        try:
            with open(f, 'r', encoding='utf-8') as fp:
                d = json.load(fp)
            sec = str(d.get('section') or d.get('type') or 'quiz1').strip().lower()
            if sec not in SECTION_DISPLAY:
                sec = 'quiz1'
            groups[(os.path.dirname(f), sec)].append((f, d))
        except Exception as e:
            print(f"Error reading {f}: {e}")

    # Process each (directory, section) group
    total_merged_files_created = 0
    total_split_files_created = 0
    total_files_deleted = 0

    for (dirpath, sec), items in sorted(groups.items()):
        under_5 = [it for it in items if len(it[1].get('questions', [])) < 5]
        normal_files = [it for it in items if len(it[1].get('questions', [])) >= 5]

        # Handle papers with < 5 questions: MERGE THEM
        if under_5:
            merged_questions = []
            seen_prompts = set()
            raw_subj = under_5[0][1].get('subject') or os.path.basename(dirpath)
            clean_subj = clean_subject(raw_subj)
            sec_display = SECTION_DISPLAY.get(sec, sec.capitalize())

            # Pool all questions
            for fpath, doc in under_5:
                for q in doc.get('questions', []):
                    ptxt = json.dumps(q.get('prompt', []))
                    if ptxt not in seen_prompts:
                        seen_prompts.add(ptxt)
                        merged_questions.append(q)

            # If merged total is < 5, supplement to reach at least 5 (aim 6-8)
            if len(merged_questions) < 5:
                needed = max(5, min(8, 5 - len(merged_questions) + 3))
                supplements = get_supplement_for_subject(clean_subj, needed, seen_prompts)
                merged_questions.extend(supplements)

            # Now we have merged_questions with len >= 5
            # Split if > 10
            chunks = balance_split(merged_questions, max_len=10)
            
            # Delete old under_5 files
            for fpath, _ in under_5:
                os.remove(fpath)
                total_files_deleted += 1

            # Write merged file(s)
            safe_subj = re.sub(r'[^a-zA-Z0-9_-]+', '_', clean_subj).strip('_')
            if len(chunks) == 1:
                new_title = f"{clean_subj} · {sec_display} · Combined PYQ"
                out_path = os.path.join(dirpath, f"{safe_subj}_{sec}_combined_pyq.json")
                out_doc = {
                    "schema_version": "1.1",
                    "quiz_title": new_title,
                    "title": new_title,
                    "subject": clean_subj,
                    "section": sec,
                    "questions": chunks[0]
                }
                with open(out_path, 'w', encoding='utf-8') as fp:
                    json.dump(out_doc, fp, indent=2, ensure_ascii=False)
                total_merged_files_created += 1
                print(f"[MERGED] {clean_subj} ({sec_display}): merged {len(under_5)} files into 1 file ({len(chunks[0])} Qs) -> {out_path}")
            else:
                for i, chunk in enumerate(chunks, 1):
                    new_title = f"{clean_subj} · {sec_display} · Combined PYQ · Part {i}"
                    out_path = os.path.join(dirpath, f"{safe_subj}_{sec}_combined_pyq_part{i}.json")
                    out_doc = {
                        "schema_version": "1.1",
                        "quiz_title": new_title,
                        "title": new_title,
                        "subject": clean_subj,
                        "section": sec,
                        "questions": chunk
                    }
                    with open(out_path, 'w', encoding='utf-8') as fp:
                        json.dump(out_doc, fp, indent=2, ensure_ascii=False)
                    total_merged_files_created += 1
                print(f"[MERGED & SPLIT] {clean_subj} ({sec_display}): merged {len(under_5)} files into {len(chunks)} parts ({[len(c) for c in chunks]} Qs)")

        # Handle normal files: SPLIT IF > 10 questions
        for fpath, doc in normal_files:
            qs = doc.get('questions', [])
            if len(qs) > 10:
                chunks = balance_split(qs, max_len=10)
                base_title = doc.get('quiz_title') or doc.get('title') or os.path.splitext(os.path.basename(fpath))[0]
                base_title = re.sub(r'\s*·\s*Part\s*\d+', '', base_title, flags=re.I).strip()
                base_path = os.path.splitext(fpath)[0]

                # Delete original file
                os.remove(fpath)
                total_files_deleted += 1

                for i, chunk in enumerate(chunks, 1):
                    new_title = f"{base_title} · Part {i}"
                    out_path = f"{base_path}_part{i}.json"
                    new_doc = dict(doc)
                    new_doc['quiz_title'] = new_title
                    new_doc['title'] = new_title
                    new_doc['questions'] = chunk
                    with open(out_path, 'w', encoding='utf-8') as fp:
                        json.dump(new_doc, fp, indent=2, ensure_ascii=False)
                    total_split_files_created += 1
                print(f"[SPLIT] {os.path.basename(fpath)} ({len(qs)} Qs) -> {len(chunks)} parts ({[len(c) for c in chunks]} Qs)")

    print(f"\n=== SUMMARY ===")
    print(f"Merged papers created: {total_merged_files_created}")
    print(f"Split papers created: {total_split_files_created}")
    print(f"Old files deleted: {total_files_deleted}")

if __name__ == '__main__':
    run_restructuring()
