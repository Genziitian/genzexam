<?php

namespace App\Console\Commands;

use App\Models\Course;
use App\Models\Quiz;
use App\Models\Week;
use App\Services\QuestionImporter;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ImportQuizzes extends Command
{
    protected $signature = 'quizzes:import 
        {course : Course slug (e.g. english-2, maths1, ct) or numeric ID} 
        {path : Path to a JSON file or directory containing JSON files}
        {--force : Re-create paper if a quiz with the same title already exists}';

    protected $description = 'Import quiz papers from a JSON file or folder of JSON files into a course.';

    private const SECTION_ALIASES = [
        'practice'            => 'practice',
        'pa'                  => 'practice',
        'practice_assignment' => 'practice',
        'practice assignment' => 'practice',
        'graded'              => 'practice_graded',
        'ga'                  => 'practice_graded',
        'practice_graded'     => 'practice_graded',
        'graded_assignment'   => 'practice_graded',
        'graded assignment'   => 'practice_graded',
        'quiz1'               => 'quiz1',
        'quiz 1'              => 'quiz1',
        'quiz_1'              => 'quiz1',
        'quiz2'               => 'quiz2',
        'quiz 2'              => 'quiz2',
        'quiz_2'              => 'quiz2',
        'endterm'             => 'endterm',
        'end term'            => 'endterm',
        'end_term'            => 'endterm',
        'end-term'            => 'endterm',
        'mock_test'           => 'mock_test',
        'mock test'           => 'mock_test',
        'mocktest'            => 'mock_test',
    ];

    public function handle(QuestionImporter $importer): int
    {
        $courseArg = (string) $this->argument('course');
        $path = (string) $this->argument('path');
        $force = (bool) $this->option('force');

        $course = is_numeric($courseArg)
            ? Course::query()->find((int) $courseArg)
            : Course::query()->where('slug', $courseArg)->first();

        if (! $course) {
            $this->error("Course not found: '{$courseArg}'");
            return self::FAILURE;
        }

        $this->info("Target Course: {$course->name} (slug: {$course->slug}, id: {$course->id})");

        // Ensure weeks 1..12 exist for this course
        for ($w = 1; $w <= 12; $w++) {
            Week::firstOrCreate(
                ['course_id' => $course->id, 'week_number' => $w],
                ['title' => "Week {$w}"]
            );
        }

        $files = [];
        if (is_file($path)) {
            $files[] = $path;
        } elseif (is_dir($path)) {
            $scan = glob(rtrim($path, '/').'/*.json') ?: [];
            sort($scan);
            $files = $scan;
        } else {
            $this->error("Path does not exist: {$path}");
            return self::FAILURE;
        }

        if (empty($files)) {
            $this->warn("No JSON files found at: {$path}");
            return self::SUCCESS;
        }

        $this->info("Found " . count($files) . " JSON files to process.");

        $created = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($files as $filePath) {
            $baseName = basename($filePath);
            $raw = file_get_contents($filePath);
            $data = json_decode($raw, true);

            if (! is_array($data)) {
                $this->error("  [FAIL] {$baseName}: Invalid JSON");
                $failed++;
                continue;
            }

            $rawSection = strtolower(trim((string) ($data['section'] ?? ($data['type'] ?? ''))));
            $section = self::SECTION_ALIASES[$rawSection] ?? (in_array($rawSection, Quiz::SECTIONS, true) ? $rawSection : 'quiz1');

            $weekId = null;
            if (in_array($section, Quiz::WEEKLY_SECTIONS, true)) {
                $wkNum = (int) ($data['week'] ?? ($data['week_number'] ?? 0));
                if ($wkNum > 0) {
                    $week = Week::firstOrCreate(
                        ['course_id' => $course->id, 'week_number' => $wkNum],
                        ['title' => "Week {$wkNum}"]
                    );
                    $weekId = $week->id;
                }
            }

            $title = trim((string) ($data['quiz_title'] ?? ($data['title'] ?? pathinfo($baseName, PATHINFO_FILENAME))));
            $questions = $data['questions'] ?? [];

            if (empty($questions)) {
                $this->warn("  [SKIP] {$baseName}: No questions in file");
                $skipped++;
                continue;
            }

            $existing = Quiz::withoutGlobalScope('exclude_personal_uploads')
                ->where('course_id', $course->id)
                ->where('title', $title)
                ->first();

            if ($existing) {
                if (! $force) {
                    $this->line("  [EXISTS] {$title} (Use --force to overwrite)");
                    $skipped++;
                    continue;
                }
                $existing->questions()->delete();
                $existing->delete();
            }

            $normalizeResult = $importer->normalizeMany($questions);
            $rows = $normalizeResult['rows'];

            if (empty($rows)) {
                $this->error("  [FAIL] {$baseName}: No valid normalized questions");
                $failed++;
                continue;
            }

            DB::transaction(function () use ($course, $weekId, $section, $title, $rows, $importer) {
                $quiz = Quiz::create([
                    'course_id'       => $course->id,
                    'week_id'         => $weekId,
                    'section'         => $section,
                    'title'           => $title,
                    'is_active'       => true,
                    'approval_status' => 'approved',
                ]);

                $importer->persist($quiz->id, $rows);
            });

            $this->info("  [OK] Created: {$title} ({$section}, " . count($rows) . " Qs)");
            $created++;
        }

        $this->newLine();
        $this->info("Import complete: {$created} created, {$skipped} skipped, {$failed} failed.");

        return self::SUCCESS;
    }
}
