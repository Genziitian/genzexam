<?php

declare(strict_types=1);

require dirname(__DIR__).'/backend/vendor/autoload.php';

$app = require dirname(__DIR__).'/backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$service = new App\Services\ProctoredQuestionService();
$assert = static function (bool $condition, string $message): void {
    if (! $condition) {
        throw new RuntimeException($message);
    }
};

$questions = $service->normalize([
    ['id' => 'one', 'type' => 'mcq', 'prompt' => 'Pick $2+2$.', 'options' => ['3', '4'], 'correct_answer' => 1, 'marks' => 2, 'negative' => 0.5],
    ['id' => 'many', 'type' => 'mcq_multi', 'prompt' => [['kind' => 'code', 'language' => 'python', 'value' => 'x = 1']], 'options' => ['a', 'b', 'c'], 'correct_answers' => [0, 2], 'marks' => 3, 'negative' => 0.25],
    ['id' => 'bool', 'type' => 'true_false', 'prompt' => 'The derivative of $x^2$ is $2x$.', 'correct_answer' => true, 'marks' => 1],
    ['id' => 'number', 'type' => 'numerical', 'prompt' => 'Approximate $\\pi$.', 'numerical_answer' => 3.14, 'numerical_tolerance' => 0.01, 'marks' => 2],
    ['id' => 'short', 'type' => 'short_answer', 'prompt' => 'Name the distribution.', 'acceptable_answers' => ['normal', 'Gaussian'], 'marks' => 2],
    ['id' => 'context', 'type' => 'comprehension', 'passage' => [
        ['kind' => 'text', 'value' => 'Use this table.'],
        ['kind' => 'table', 'caption' => 'Values', 'headers' => ['x', 'y'], 'rows' => [['1', '2']]],
    ]],
]);
$assert($questions[0]['type'] === 'mcq_single', 'mcq alias should normalize.');
$assert($questions[5]['type'] === 'comprehension' && (float) $questions[5]['marks'] === 0.0, 'Comprehension should be unscored context.');
$assert($questions[5]['prompt'][1]['kind'] === 'table', 'Table blocks should survive normalization.');
$template = json_decode((string) file_get_contents(dirname(__DIR__).'/templates/proctored-exam-template.json'), true, 512, JSON_THROW_ON_ERROR);
$normalizedTemplate = $service->normalize($template['questions']);
$assert(count($normalizedTemplate) === count($template['questions']), 'The published example template should normalize without row errors.');
$assert($normalizedTemplate[7]['prompt'][1]['url'] === '/assets/exam-examples/normal-curve.png', 'Example diagram path should remain same-origin.');

$result = $service->score($questions, [
    'one' => '1',
    'many' => [0, 2],
    'bool' => true,
    'number' => '3.145',
    'short' => ' gaussian ',
]);
$assert(abs($result['score'] - 10.0) < 1e-9, 'All correct answers should score full marks.');
$assert(abs($result['total_marks'] - 10.0) < 1e-9, 'Comprehension must not contribute to total marks.');
$assert($result['breakdown']['many']['correct'] === true, 'Multi-select should match as an exact set.');

$partial = $service->score($questions, ['many' => [0]]);
$assert(abs($partial['score']) < 1e-9, 'A wrong answer should reduce score but exam score is floored at zero.');
$assert($partial['breakdown']['one']['attempted'] === false, 'Omitted answers are unattempted.');
$assert($service->validateAnswers($questions, ['many' => []]) === [], 'Empty multi-select answer should be treated as unattempted.');

$badCases = [
    [[['type' => 'mcq_single', 'options' => ['a', 'b'], 'correct_answer' => 0]], 'prompt'],
    [[['type' => 'mcq_single', 'prompt' => [''], 'options' => ['a', 'b'], 'correct_answer' => 0]], 'prompt'],
    [[['type' => 'mcq_single', 'prompt' => 'x', 'options' => ['a', 'b'], 'correct_answer' => 8]], 'correct_answer'],
    [[['type' => 'mcq_multi', 'prompt' => 'x', 'options' => ['a', 'b'], 'correct_answers' => [0, 0]]], 'correct_answers'],
    [[['type' => 'numerical', 'prompt' => 'x', 'numerical_answer' => INF]], 'numerical_answer'],
    [[['type' => 'short_answer', 'prompt' => 'x', 'acceptable_answers' => array_fill(0, 101, 'answer')]], 'acceptable_answers'],
    [[['type' => 'short_answer', 'prompt' => 'x', 'acceptable_answers' => ['answer'], 'explanation' => [['kind' => 'image', 'url' => '/uploads/%2e%2e/private.png']]]], 'explanation'],
    [[['type' => 'short_answer', 'prompt' => 'x', 'acceptable_answers' => ['answer'], 'explanation' => [['kind' => 'image', 'url' => 'https://example.test/diagram.svg']]]], 'explanation'],
    [[['type' => 'short_answer', 'prompt' => 'x', 'acceptable_answers' => ['answer'], 'explanation' => [['kind' => 'image', 'url' => '//evil.test/image.png']]]], 'explanation'],
];
foreach ($badCases as [$input, $expectedField]) {
    try {
        $service->normalize($input);
        throw new RuntimeException('Invalid import unexpectedly succeeded.');
    } catch (Illuminate\Validation\ValidationException $exception) {
        $message = implode(' ', array_merge(...array_values($exception->errors())));
        $assert(str_contains($message, $expectedField) || str_contains(implode(' ', array_keys($exception->errors())), $expectedField), 'Validation should identify '.$expectedField.'.');
    }
}

try {
    $service->validateAnswers($questions, ['many' => [0, 0]]);
    throw new RuntimeException('Duplicate selected options unexpectedly succeeded.');
} catch (Illuminate\Validation\ValidationException $exception) {
    $assert(isset($exception->errors()['answers.many']), 'Invalid answer errors should identify the question.');
}

echo "ProctoredQuestionService checks passed.\n";
