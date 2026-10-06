<?php

namespace App\Services;

use Illuminate\Validation\ValidationException;

/**
 * Validates and scores the question JSON used by proctored exams.
 *
 * The public schema deliberately keeps the import field names so callers can
 * store and render the same normalized object without translating answer
 * keys. Rich content is represented as a list of safe blocks.
 */
class ProctoredQuestionService
{
    private const TYPES = ['mcq_single', 'mcq_multi', 'true_false', 'numerical', 'short_answer', 'comprehension'];
    private const BLOCK_KINDS = ['text', 'code', 'image', 'table', 'math'];
    private const MAX_QUESTIONS = 500;
    private const MAX_BLOCKS = 100;
    private const MAX_TEXT_LENGTH = 20000;
    private const MAX_OPTIONS = 20;
    private const MAX_TOTAL_BYTES = 5242880;

    /** @throws ValidationException */
    public function normalize(array $questions): array
    {
        $errors = [];
        $normalized = [];
        $seenIds = [];

        if (! array_is_list($questions)) {
            throw ValidationException::withMessages(['questions' => 'Questions must be a JSON array.']);
        }
        if ($questions === []) {
            throw ValidationException::withMessages(['questions' => 'At least one question is required.']);
        }
        if (count($questions) > self::MAX_QUESTIONS) {
            throw ValidationException::withMessages(['questions' => 'An exam may contain at most '.self::MAX_QUESTIONS.' questions.']);
        }
        $encodedQuestions = json_encode($questions, JSON_INVALID_UTF8_SUBSTITUTE);
        if (is_string($encodedQuestions) && strlen($encodedQuestions) > self::MAX_TOTAL_BYTES) {
            throw ValidationException::withMessages(['questions' => 'The complete question set must be at most 5 MB.']);
        }

        foreach ($questions as $index => $raw) {
            if (! is_array($raw)) {
                $this->addError($errors, $index, 'question', 'Each question must be a JSON object.');
                continue;
            }

            $row = $raw;
            if (! array_key_exists('prompt', $row)) {
                if (array_key_exists('passage', $row)) {
                    $row['prompt'] = $row['passage'];
                } elseif (array_key_exists('stem', $row) || array_key_exists('stem_code', $row) || array_key_exists('stem_table', $row)) {
                    $legacyBlocks = [];
                    if (isset($row['stem']) && is_string($row['stem']) && trim($row['stem']) !== '') {
                        $legacyBlocks[] = ['kind' => 'text', 'value' => $row['stem']];
                    }
                    if (isset($row['stem_code']) && is_string($row['stem_code']) && trim($row['stem_code']) !== '') {
                        $legacyBlocks[] = ['kind' => 'code', 'language' => $row['stem_code_language'] ?? 'text', 'value' => $row['stem_code']];
                    }
                    if (is_array($row['stem_table'] ?? null)) {
                        $legacyBlocks[] = ['kind' => 'table', ...$row['stem_table']];
                    }
                    $row['prompt'] = $legacyBlocks;
                }
            }
            if (! is_string($row['type'] ?? null)) {
                $this->addError($errors, $index, 'type', 'Question type must be a string.');
                continue;
            }
            $type = strtolower(trim($row['type']));
            $type = match ($type) {
                'mcq' => 'mcq_single',
                'multi_select' => 'mcq_multi',
                default => $type,
            };
            if (! in_array($type, self::TYPES, true)) {
                $this->addError($errors, $index, 'type', 'Use mcq_single, mcq_multi, true_false, numerical, short_answer, or comprehension.');
                continue;
            }
            $row['type'] = $type;

            $rawId = $row['id'] ?? null;
            $id = $rawId === null ? 'q'.($index + 1) : (is_string($rawId) || is_int($rawId) ? trim((string) $rawId) : '');
            if ($id === '' || strlen($id) > 100 || ! preg_match('/^[A-Za-z0-9][A-Za-z0-9_-]*$/', $id)) {
                $this->addError($errors, $index, 'id', 'Question id must be 1 to 100 letters, numbers, underscores, or hyphens, starting with a letter or number.');
            } elseif (isset($seenIds[$id])) {
                $this->addError($errors, $index, 'id', 'Question ids must be unique within an exam.');
            } else {
                $seenIds[$id] = true;
                $row['id'] = $id;
            }

            foreach (['prompt', 'explanation'] as $field) {
                if (! array_key_exists($field, $row) || ($field === 'explanation' && $row[$field] === null)) {
                    continue;
                }
                $row[$field] = $this->normalizeContent($row[$field], $index, $field, $errors);
            }
            $row['prompt'] = $row['prompt'] ?? [];
            if (! $this->contentHasContent($row['prompt'])) {
                $this->addError($errors, $index, 'prompt', 'Question prompt or passage content is required.');
            }

            if (isset($row['section']) && $row['section'] !== null) {
                if (! is_string($row['section']) || strlen($row['section']) > 100) {
                    $this->addError($errors, $index, 'section', 'Section must be a string of at most 100 characters.');
                } else {
                    $row['section'] = trim($row['section']);
                }
            }
            if (isset($row['difficulty'])) {
                $difficulty = is_string($row['difficulty']) ? strtolower(trim($row['difficulty'])) : '';
                if (! in_array($difficulty, ['easy', 'medium', 'hard'], true)) {
                    $this->addError($errors, $index, 'difficulty', 'Difficulty must be easy, medium, or hard.');
                } else {
                    $row['difficulty'] = $difficulty;
                }
            }

            if ($type === 'comprehension') {
                $row['marks'] = 0;
                $row['negative'] = 0;
                unset($row['options'], $row['correct_answer'], $row['correct_answers'], $row['acceptable_answers'], $row['numerical_answer'], $row['numerical_tolerance']);
            } else {
                $row['marks'] = $this->finiteNumber($row['marks'] ?? 1, $index, 'marks', $errors, 0, 10000);
                if ($row['marks'] !== null && $row['marks'] <= 0) {
                    $this->addError($errors, $index, 'marks', 'Marks must be greater than 0 and at most 10000.');
                }
                $row['negative'] = $this->finiteNumber($row['negative'] ?? 0, $index, 'negative', $errors, 0, 10000);
            }

            if (in_array($type, ['mcq_single', 'mcq_multi'], true)) {
                $rawOptions = $row['options'] ?? null;
                if (! is_array($rawOptions) || count($rawOptions) < 2 || count($rawOptions) > self::MAX_OPTIONS) {
                    $this->addError($errors, $index, 'options', 'Provide 2 to '.self::MAX_OPTIONS.' options.');
                    $row['options'] = [];
                } else {
                    $row['options'] = [];
                    foreach ($rawOptions as $optionIndex => $option) {
                        $blocks = $this->normalizeContent($option, $index, 'options.'.$optionIndex, $errors);
                        if (! $this->contentHasContent($blocks)) {
                            $this->addError($errors, $index, 'options.'.$optionIndex, 'Option content cannot be empty.');
                        }
                        $row['options'][] = $blocks;
                    }
                }

                if ($type === 'mcq_single') {
                    $answer = $row['correct_answer'] ?? null;
                    $answerIndex = $this->optionIndex($answer);
                    if ($answerIndex === null || ! isset($row['options'][$answerIndex])) {
                        $this->addError($errors, $index, 'correct_answer', 'correct_answer must be a valid zero-based option index.');
                    } else {
                        $row['correct_answer'] = $answerIndex;
                    }
                    unset($row['correct_answers']);
                } else {
                    $answers = $row['correct_answers'] ?? null;
                    if (! is_array($answers) || $answers === []) {
                        $this->addError($errors, $index, 'correct_answers', 'Select at least one correct option index.');
                    } else {
                        $indices = [];
                        foreach ($answers as $answer) {
                            $answerIndex = $this->optionIndex($answer);
                            if ($answerIndex === null || ! isset($row['options'][$answerIndex])) {
                                $this->addError($errors, $index, 'correct_answers', 'Each correct_answers value must be a valid zero-based option index.');
                                continue;
                            }
                            if (in_array($answerIndex, $indices, true)) {
                                $this->addError($errors, $index, 'correct_answers', 'Correct option indices must not repeat.');
                                continue;
                            }
                            $indices[] = $answerIndex;
                        }
                        sort($indices);
                        $row['correct_answers'] = $indices;
                    }
                    unset($row['correct_answer']);
                }
            } elseif ($type === 'true_false') {
                $answer = $row['correct_answer'] ?? null;
                if (is_bool($answer)) {
                    $row['correct_answer'] = $answer;
                } elseif (is_string($answer) && in_array(strtolower(trim($answer)), ['true', 'false'], true)) {
                    $row['correct_answer'] = strtolower(trim($answer)) === 'true';
                } else {
                    $this->addError($errors, $index, 'correct_answer', 'correct_answer must be true or false.');
                }
                unset($row['options'], $row['correct_answers']);
            } elseif ($type === 'numerical') {
                $row['numerical_answer'] = $this->finiteNumber($row['numerical_answer'] ?? null, $index, 'numerical_answer', $errors, -1.0e15, 1.0e15);
                $row['numerical_tolerance'] = $this->finiteNumber($row['numerical_tolerance'] ?? 0.01, $index, 'numerical_tolerance', $errors, 0, 1.0e15);
                unset($row['options'], $row['correct_answer'], $row['correct_answers']);
            } elseif ($type === 'short_answer') {
                $acceptable = $row['acceptable_answers'] ?? null;
                    if (! is_array($acceptable) || $acceptable === [] || count($acceptable) > 100) {
                $this->addError($errors, $index, 'acceptable_answers', 'Provide 1 to 100 acceptable answers.');
                    $row['acceptable_answers'] = [];
                } else {
                    $row['acceptable_answers'] = [];
                    foreach ($acceptable as $answer) {
                        if (! is_string($answer) || trim($answer) === '' || strlen($answer) > 1000) {
                            $this->addError($errors, $index, 'acceptable_answers', 'Answers must be non-empty strings of at most 1000 characters.');
                            continue;
                        }
                        $row['acceptable_answers'][] = trim($answer);
                    }
                    if ($row['acceptable_answers'] === []) {
                        $this->addError($errors, $index, 'acceptable_answers', 'At least one acceptable answer is required.');
                    }
                }
                unset($row['options'], $row['correct_answer'], $row['correct_answers']);
            }

            // Do not pass arbitrary imported fields through to clients or persistence.
            $allowed = ['id', 'type', 'prompt', 'options', 'correct_answer', 'correct_answers', 'acceptable_answers', 'numerical_answer', 'numerical_tolerance', 'marks', 'negative', 'section', 'explanation', 'difficulty'];
            $normalized[] = array_intersect_key($row, array_flip($allowed));
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $normalized;
    }

    /** Validate candidate answers and return the same keyed answer map. */
    public function validateAnswers(array $questions, array $answers): array
    {
        $errors = [];
        $known = [];
        $validated = [];
        foreach ($questions as $index => $question) {
            if (! is_array($question) || ($question['type'] ?? '') === 'comprehension') {
                continue;
            }
            $id = (string) ($question['id'] ?? 'q'.($index + 1));
            $known[$id] = true;
            if (! array_key_exists($id, $answers)) {
                continue;
            }
            $answer = $answers[$id];
            if ($answer === null || $answer === '' || $answer === []) {
                continue;
            }
            $type = $question['type'] ?? '';
            if (in_array($type, ['mcq_single', 'mcq_multi'], true)) {
                $values = $type === 'mcq_multi' ? $answer : [$answer];
                if (! is_array($values) || $values === []) {
                    $this->answerError($errors, $id, 'Select valid option indices.');
                    continue;
                }
                $indices = [];
                foreach ($values as $value) {
                    $optionIndex = $this->optionIndex($value);
                    if ($optionIndex === null || ! isset($question['options'][$optionIndex])) {
                        $this->answerError($errors, $id, 'Answer contains an invalid option index.');
                        continue;
                    }
                    $indices[] = $optionIndex;
                }
                if ($type === 'mcq_single' && count($indices) !== 1) {
                    $this->answerError($errors, $id, 'Select exactly one option.');
                } elseif ($type === 'mcq_multi' && count(array_unique($indices)) !== count($indices)) {
                    $this->answerError($errors, $id, 'An option cannot be selected more than once.');
                } elseif (! isset($errors['answers.'.$id])) {
                    $validated[$id] = $type === 'mcq_single' ? $indices[0] : $indices;
                }
            } elseif ($type === 'true_false') {
                if (is_bool($answer)) {
                    $validated[$id] = $answer;
                } elseif (is_string($answer) && in_array(strtolower(trim($answer)), ['true', 'false'], true)) {
                    $validated[$id] = strtolower(trim($answer)) === 'true';
                } else {
                    $this->answerError($errors, $id, 'Answer must be true or false.');
                }
            } elseif ($type === 'numerical') {
                if (! is_numeric($answer) || ! is_finite((float) $answer) || strlen((string) $answer) > 100) {
                    $this->answerError($errors, $id, 'Answer must be a finite number.');
                } else {
                    $validated[$id] = (float) $answer;
                }
            } elseif ($type === 'short_answer') {
                if (! is_string($answer) || strlen($answer) > 2000) {
                    $this->answerError($errors, $id, 'Answer must be a string of at most 2000 characters.');
                } else {
                    $validated[$id] = trim($answer);
                }
            }
        }

        if (count($answers) > self::MAX_QUESTIONS) {
            $errors['answers'][] = 'An answer set may contain at most '.self::MAX_QUESTIONS.' entries.';
        }
        foreach ($answers as $id => $_answer) {
            if (! isset($known[(string) $id])) {
                $errors['answers.'.(string) $id][] = 'Answer refers to an unknown question.';
            }
        }
        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $validated;
    }

    /** Score validated answers using exact set matching for multi-select. */
    public function score(array $questions, array $answers): array
    {
        $answers = $this->validateAnswers($questions, $answers);
        $score = 0.0;
        $totalMarks = 0.0;
        $breakdown = [];

        foreach ($questions as $index => $question) {
            $id = (string) ($question['id'] ?? 'q'.($index + 1));
            $type = $question['type'] ?? '';
            if ($type === 'comprehension') {
                $breakdown[$id] = ['attempted' => false, 'correct' => null, 'score' => 0.0, 'marks' => 0.0];
                continue;
            }
            $marks = (float) ($question['marks'] ?? 1);
            $negative = (float) ($question['negative'] ?? 0);
            $totalMarks += $marks;
            $attempted = array_key_exists($id, $answers) && $answers[$id] !== '' && $answers[$id] !== [];
            $correct = false;
            if ($attempted) {
                $answer = $answers[$id];
                $correct = match ($type) {
                    'mcq_single' => $answer === (int) ($question['correct_answer'] ?? -1),
                    'mcq_multi' => $this->sameIndexSet($answer, $question['correct_answers'] ?? []),
                    'true_false' => $answer === (bool) ($question['correct_answer'] ?? false),
                    'numerical' => abs($answer - (float) ($question['numerical_answer'] ?? INF)) <= (float) ($question['numerical_tolerance'] ?? 0),
                    'short_answer' => $this->matchesShortAnswer($answer, $question['acceptable_answers'] ?? []),
                    default => false,
                };
            }
            $questionScore = ! $attempted ? 0.0 : ($correct ? $marks : -$negative);
            $score += $questionScore;
            $breakdown[$id] = ['attempted' => $attempted, 'correct' => $correct, 'score' => $questionScore, 'marks' => $marks];
        }

        return ['score' => max(0.0, $score), 'total_marks' => $totalMarks, 'breakdown' => $breakdown];
    }

    private function normalizeContent(mixed $content, int $row, string $field, array &$errors): array
    {
        if (is_string($content)) {
            $content = [['kind' => 'text', 'value' => $content]];
        }
        if (! is_array($content)) {
            $this->addError($errors, $row, $field, 'Content must be a string or an array of rich-content blocks.');
            return [];
        }
        if ($content !== [] && ! array_is_list($content)) {
            // A single `{kind, ...}` block is also accepted.
            $content = [$content];
        }
        if (count($content) > self::MAX_BLOCKS) {
            $this->addError($errors, $row, $field, 'Content may contain at most '.self::MAX_BLOCKS.' blocks.');
            return [];
        }

        $blocks = [];
        foreach ($content as $blockIndex => $block) {
            if (is_string($block)) {
                $block = ['kind' => 'text', 'value' => $block];
            }
            if (! is_array($block)) {
                $this->addError($errors, $row, $field.'.'.$blockIndex, 'Each content block must be an object or string.');
                continue;
            }
            $rawKind = $block['kind'] ?? $block['type'] ?? 'text';
            $kind = is_string($rawKind) ? strtolower(trim($rawKind)) : '';
            if (! in_array($kind, self::BLOCK_KINDS, true)) {
                $this->addError($errors, $row, $field.'.'.$blockIndex.'.kind', 'Unsupported rich-content block kind.');
                continue;
            }
            $normalized = ['kind' => $kind];
            if (in_array($kind, ['text', 'code', 'math'], true)) {
                $value = $block['value'] ?? '';
                if (! is_string($value) || strlen($value) > self::MAX_TEXT_LENGTH) {
                    $this->addError($errors, $row, $field.'.'.$blockIndex.'.value', 'Block value must be a string of at most '.self::MAX_TEXT_LENGTH.' characters.');
                    continue;
                }
                $normalized['value'] = $value;
                if ($kind === 'code') {
                    $language = $block['language'] ?? 'text';
                    if (! is_string($language)) {
                        $this->addError($errors, $row, $field.'.'.$blockIndex.'.language', 'Code language must be a string.');
                        continue;
                    }
                    if (! preg_match('/^[a-zA-Z0-9_+.-]{1,32}$/', $language)) {
                        $this->addError($errors, $row, $field.'.'.$blockIndex.'.language', 'Code language contains unsupported characters.');
                        continue;
                    }
                    $normalized['language'] = strtolower($language);
                }
                if ($kind === 'math') {
                    $normalized['display'] = (bool) ($block['display'] ?? false);
                }
            } elseif ($kind === 'image') {
                $url = $block['url'] ?? $block['asset'] ?? null;
                if (is_string($url) && preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/', $url) && ! str_contains($url, '..')) {
                    $url = '/uploads/'.$url;
                }
                if (! is_string($url) || ! $this->isSafeImageUrl($url)) {
                    $this->addError($errors, $row, $field.'.'.$blockIndex.'.url', 'Image URL must use HTTPS or an allowed same-origin upload path.');
                    continue;
                }
                $normalized['url'] = $url;
                foreach (['alt', 'caption'] as $textField) {
                    if (isset($block[$textField])) {
                        if (! is_string($block[$textField]) || strlen($block[$textField]) > 500) {
                            $this->addError($errors, $row, $field.'.'.$blockIndex.'.'.$textField, $textField.' must be a string of at most 500 characters.');
                            continue 2;
                        }
                        $normalized[$textField] = $block[$textField];
                    }
                }
            } else {
                $headers = $block['headers'] ?? null;
                $rows = $block['rows'] ?? null;
                if (! is_array($headers) || $headers === [] || count($headers) > 30 || ! is_array($rows) || count($rows) > 500) {
                    $this->addError($errors, $row, $field.'.'.$blockIndex, 'Table requires 1 to 30 headers and at most 500 rows.');
                    continue;
                }
                $valid = true;
                foreach ($headers as $header) {
                    if (! is_string($header) || strlen($header) > 500) { $valid = false; }
                }
                $cleanRows = [];
                foreach ($rows as $tableRow) {
                    if (! is_array($tableRow) || count($tableRow) !== count($headers)) { $valid = false; continue; }
                    $cleanRow = [];
                    foreach ($tableRow as $cell) {
                        if (! is_string($cell) && ! is_numeric($cell)) { $valid = false; continue 2; }
                        if (strlen((string) $cell) > 2000) { $valid = false; continue 2; }
                        $cleanRow[] = (string) $cell;
                    }
                    $cleanRows[] = $cleanRow;
                }
                if (! $valid) {
                    $this->addError($errors, $row, $field.'.'.$blockIndex, 'Table rows must match the headers and contain bounded text or numbers.');
                    continue;
                }
                $normalized['headers'] = array_values($headers);
                $normalized['rows'] = $cleanRows;
                if (isset($block['caption'])) {
                    if (! is_string($block['caption']) || strlen($block['caption']) > 500) {
                        $this->addError($errors, $row, $field.'.'.$blockIndex.'.caption', 'Table caption must be at most 500 characters.');
                        continue;
                    }
                    $normalized['caption'] = $block['caption'];
                }
            }
            $blocks[] = $normalized;
        }
        return $blocks;
    }

    private function isSafeImageUrl(string $url): bool
    {
        if ($url === '' || strlen($url) > 2048 || preg_match('/[\x00-\x20]/', $url) || str_contains($url, '\\')) {
            return false;
        }
        if (str_starts_with($url, '/storage/') || str_starts_with($url, '/uploads/') || str_starts_with($url, '/assets/exam-examples/')) {
            $decoded = rawurldecode($url);
            return ! str_starts_with($url, '//')
                && ! preg_match('#(?:^|/)\.\.(?:/|$)#', $decoded)
                && ! preg_match('/[?#%]/', $url)
                && ! str_contains($decoded, '\\')
                && ! preg_match('/\.svg$/i', parse_url($url, PHP_URL_PATH) ?: '');
        }
        $parts = parse_url($url);
        return is_array($parts)
            && strtolower((string) ($parts['scheme'] ?? '')) === 'https'
            && ! empty($parts['host'])
            && ! isset($parts['user'])
            && ! isset($parts['pass'])
            && ! preg_match('/\.svg$/i', (string) ($parts['path'] ?? ''));
    }

    private function finiteNumber(mixed $value, int $row, string $field, array &$errors, float $min, float $max): ?float
    {
        if (is_bool($value) || ! is_numeric($value) || ! is_finite((float) $value)) {
            $this->addError($errors, $row, $field, $field.' must be a finite number.');
            return null;
        }
        $number = (float) $value;
        if ($number < $min || $number > $max) {
            $this->addError($errors, $row, $field, $field.' is outside the allowed range.');
            return null;
        }
        return $number;
    }

    private function optionIndex(mixed $value): ?int
    {
        if (is_int($value)) { return $value >= 0 ? $value : null; }
        if (is_string($value) && preg_match('/^(0|[1-9][0-9]*)$/', $value)) { return (int) $value; }
        return null;
    }

    private function contentHasContent(array $blocks): bool
    {
        foreach ($blocks as $block) {
            if (($block['kind'] ?? '') === 'text' && trim((string) ($block['value'] ?? '')) !== '') { return true; }
            if (($block['kind'] ?? '') === 'code' && trim((string) ($block['value'] ?? '')) !== '') { return true; }
            if (($block['kind'] ?? '') === 'math' && trim((string) ($block['value'] ?? '')) !== '') { return true; }
            if (($block['kind'] ?? '') === 'image' && ! empty($block['url'])) { return true; }
            if (($block['kind'] ?? '') === 'table' && ! empty($block['headers'])) { return true; }
        }
        return false;
    }

    private function sameIndexSet(array $left, array $right): bool
    {
        sort($left);
        sort($right);
        return count($left) === count(array_unique($left)) && $left === $right;
    }

    private function matchesShortAnswer(string $answer, array $acceptable): bool
    {
        $normalize = static function (string $value): string {
            $value = trim($value);
            return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
        };
        foreach ($acceptable as $candidate) {
            if (is_string($candidate) && $normalize($answer) === $normalize($candidate)) { return true; }
        }
        return false;
    }

    private function addError(array &$errors, int|string $row, string $field, string $message): void
    {
        $errors['questions.'.$row.'.'.$field][] = $message;
    }

    private function answerError(array &$errors, string $id, string $message): void
    {
        $errors['answers.'.$id][] = $message;
    }
}
