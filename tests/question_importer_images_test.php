<?php

declare(strict_types=1);

require dirname(__DIR__).'/backend/vendor/autoload.php';
$app = require dirname(__DIR__).'/backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Http\Controllers\QuizController;
use App\Models\Question;
use App\Models\User;
use App\Services\QuestionImporter;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

$check = static function (bool $condition, string $message): void {
    if (! $condition) { throw new RuntimeException($message); }
};
$image = ['kind' => 'image', 'url' => '/assets/exam-examples/normal-curve.png', 'alt' => 'Original source graph'];
$question = [
    'type' => 'mcq_single',
    'prompt' => [['kind' => 'text', 'value' => 'Use this graph.'], $image,
        ['kind' => 'code', 'language' => 'pseudocode', 'value' => "Step 1: Read the graph\nStep 2: Compare the values"],
        ['kind' => 'text', 'value' => 'Which option matches?']],
    'options' => [[$image], [['kind' => 'text', 'value' => 'Another graph'], $image]],
    'correct_answer' => 1, 'marks' => 2, 'explanation' => [$image],
];
$importer = new QuestionImporter;
$result = $importer->normalizeMany([$question]);
$check($result['errors'] === [], 'Image prompts/options/explanations should import.');
$row = $result['rows'][0];
$check(strpos($row['stem'], 'Use this graph.') < strpos($row['stem'], '!['), 'Intro must precede crop.');
$check(strpos($row['stem'], '![') < strpos($row['stem'], '```pseudocode'), 'Code must follow crop.');
$check(str_ends_with($row['stem'], 'Which option matches?'), 'Trailing inquiry must survive.');
$check($row['stem_code'] === null, 'Ordered code must not also render twice.');
$check(count($row['options']) === 2 && $row['options'][1]['is_correct'], 'Image-only options must retain their indices and key.');
$check(str_contains($row['explanation'], '!['), 'Explanation crop must survive.');
$procedure = $question;
$procedure['prompt'] = [$question['prompt'][0], $question['prompt'][2], $question['prompt'][3]];
$procedure['options'][0] = [['kind' => 'text', 'value' => 'Run this:'], ['kind' => 'code', 'language' => 'python', 'value' => 'print(1)']];
$ordered = $importer->normalizeMany([$procedure]);
$check($ordered['errors'] === [] && str_ends_with($ordered['rows'][0]['stem'], 'Which option matches?'), 'Text/code/outro order must survive even without an image.');
$check(str_contains($ordered['rows'][0]['options'][0]['option_text'], "```python\nprint(1)"), 'Mixed text/code options must not lose their code.');

foreach (['javascript:alert(1)', 'file:///private/test.png', 'data:image/png;base64,AA', '/uploads/../private.png', '/uploads/%2e%2e/private.png', 'https://example.test/x.svg', 'https://example.test/<x>.png'] as $url) {
    foreach (['prompt', 'option', 'explanation'] as $field) {
        $bad = $question;
        $block = ['kind' => 'image', 'url' => $url];
        if ($field === 'option') { $bad['options'][0] = [$block]; }
        else { $bad[$field] = [$block]; }
        $check($importer->normalizeMany([$bad])['rows'] === [], 'Unsafe '.$field.' crop must fail: '.$url);
    }
}
$legacy = $importer->normalizeMany([['type' => 'mcq_single', 'prompt' => [['kind' => 'text', 'value' => 'Legacy text']], 'options' => ['a', 'b'], 'correct_answer' => 0]]);
$check($legacy['errors'] === [] && $legacy['rows'][0]['stem'] === 'Legacy text', 'Text-only imports must keep working.');

// Isolated SQLite: never touch the configured application database.
config(['database.default' => 'crop_test', 'database.connections.crop_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true]]);
DB::purge('crop_test');
Schema::create('courses', function (Blueprint $t) { $t->id(); $t->string('name'); $t->string('slug'); $t->boolean('is_active'); });
Schema::create('quizzes', function (Blueprint $t) {
    $t->id(); $t->unsignedBigInteger('course_id'); $t->string('title'); $t->string('section');
    $t->boolean('is_active'); $t->string('approval_status'); $t->boolean('is_personal');
    $t->unsignedBigInteger('owner_user_id')->nullable(); $t->integer('price_paise')->default(0);
});
foreach (['2026_04_15_000004_create_questions_table.php', '2026_04_15_000005_create_question_options_table.php', '2026_04_15_000006_create_short_answer_acceptables_table.php', '2026_05_28_000001_add_stem_table_to_questions_table.php'] as $migration) {
    (require dirname(__DIR__).'/backend/database/migrations/'.$migration)->up();
}
DB::table('courses')->insert(['id' => 1, 'name' => 'Mathematics 2', 'slug' => 'mathematics-2', 'is_active' => true]);
DB::table('quizzes')->insert(['id' => 1, 'course_id' => 1, 'title' => 'Crop integration fixture', 'section' => 'practice', 'is_active' => true, 'approval_status' => 'approved', 'is_personal' => false]);
$ids = $importer->persist(1, array_fill(0, 5, $row));
$check(count($ids) === 5, 'The fixture paper must contain five questions.');
$saved = Question::findOrFail($ids[0]);
$check($saved->stem === $row['stem'] && $saved->questionOptions[1]->is_correct, 'Database must preserve crops and answer key.');
$request = Request::create('/api/quizzes/1');
$user = new User(['role' => 'student']);
$user->id = 123;
$request->setUserResolver(fn () => $user);
$payload = (new QuizController)->show($request, 1)->getData(true);
$check($payload['questions'][0]['stem'] === $row['stem'], 'Quiz API must return ordered prompt crops.');
$check($payload['questions'][0]['options'][0]['option_text'] === $row['options'][0]['option_text'], 'Quiz API must return image-only options.');
$check(! array_key_exists('is_correct', $payload['questions'][0]['options'][0]), 'Student API must not expose answer keys.');
echo "Question image import, persistence, API, and URL validation checks passed.\n";
