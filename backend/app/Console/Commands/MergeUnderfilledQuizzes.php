<?php

namespace App\Console\Commands;

use App\Models\Course;
use App\Models\Question;
use App\Models\Quiz;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class MergeUnderfilledQuizzes extends Command
{
    protected $signature = 'quizzes:merge-underfilled
        {--course= : Optional course slug or ID to restrict merging to}
        {--min=5 : Minimum question count required per paper (default 5)}
        {--max=10 : Maximum question count allowed before splitting (default 10)}
        {--dry-run : Only show what would be merged without changing data}';

    protected $description = 'Automatically merge papers with fewer than 5 questions of the same subject and section.';

    private const SECTION_NAMES = [
        'quiz1'           => 'Quiz 1',
        'quiz2'           => 'Quiz 2',
        'endterm'         => 'End Term',
        'practice_graded' => 'Graded Assignment',
        'practice'        => 'Practice Assignment',
        'mock_test'       => 'Mock Test',
    ];

    public function handle(): int
    {
        $min = (int) $this->option('min');
        $max = (int) $this->option('max');
        $dryRun = (bool) $this->option('dry-run');
        $courseFilter = $this->option('course');

        $this->info("Scanning for papers with < {$min} questions...");

        $courseQuery = Course::query();
        if ($courseFilter) {
            $courseQuery->where(fn ($q) => is_numeric($courseFilter)
                ? $q->where('id', (int) $courseFilter)
                : $q->where('slug', $courseFilter));
        }
        $courses = $courseQuery->get();

        $totalMerged = 0;
        $totalNewPapers = 0;

        foreach ($courses as $course) {
            foreach (Quiz::SECTIONS as $section) {
                $underfilled = Quiz::withoutGlobalScope('exclude_personal_uploads')
                    ->where('course_id', $course->id)
                    ->where('section', $section)
                    ->where('is_personal', false)
                    ->where('is_active', true)
                    ->withCount('questions')
                    ->having('questions_count', '<', $min)
                    ->having('questions_count', '>', 0)
                    ->orderBy('year')
                    ->orderBy('id')
                    ->get();

                if ($underfilled->count() < 2 && $underfilled->sum('questions_count') < $min) {
                    if ($underfilled->isNotEmpty()) {
                        $this->warn("  [{$course->name}] {$section}: {$underfilled->count()} paper(s) with total {$underfilled->sum('questions_count')} Qs (< {$min}). Needs more questions to merge.");
                    }
                    continue;
                }

                $sectionTitle = self::SECTION_NAMES[$section] ?? ucfirst($section);
                $this->line("\nFound {$underfilled->count()} underfilled papers in [{$course->name} · {$sectionTitle}]:");
                foreach ($underfilled as $u) {
                    $this->line("  - ID {$u->id}: '{$u->title}' ({$u->questions_count} Qs)");
                }

                $allQuestions = Question::query()
                    ->whereIn('quiz_id', $underfilled->pluck('id'))
                    ->orderBy('quiz_id')
                    ->orderBy('position')
                    ->get();

                $totalQ = $allQuestions->count();
                $this->info("Total pooled questions: {$totalQ}");

                if ($dryRun) {
                    $this->comment("  [DRY-RUN] Would merge {$underfilled->count()} papers into combined {$sectionTitle} paper(s).");
                    continue;
                }

                DB::transaction(function () use ($course, $section, $sectionTitle, $underfilled, $allQuestions, $max, &$totalMerged, &$totalNewPapers) {
                    // Split into chunks if > max
                    $chunks = $allQuestions->chunk($max);
                    $chunkIndex = 1;
                    $totalChunks = $chunks->count();

                    foreach ($chunks as $chunk) {
                        $titleSuffix = $totalChunks > 1 ? " · Part {$chunkIndex}" : "";
                        $combinedTitle = "{$course->name} — {$sectionTitle} (Combined PYQ){$titleSuffix}";

                        $combinedQuiz = Quiz::query()->create([
                            'course_id' => $course->id,
                            'section' => $section,
                            'title' => $combinedTitle,
                            'is_active' => true,
                            'is_personal' => false,
                            'approval_status' => 'approved',
                            'description' => "Combined previous-year questions merged from short papers.",
                        ]);

                        $pos = 1;
                        foreach ($chunk as $q) {
                            $q->update([
                                'quiz_id' => $combinedQuiz->id,
                                'position' => $pos++,
                            ]);
                        }

                        $this->info("  Created combined paper ID {$combinedQuiz->id}: '{$combinedTitle}' ({$chunk->count()} Qs)");
                        $totalNewPapers++;
                        $chunkIndex++;
                    }

                    // Deactivate original fragmented quizzes
                    Quiz::withoutGlobalScope('exclude_personal_uploads')
                        ->whereIn('id', $underfilled->pluck('id'))
                        ->update(['is_active' => false]);

                    $totalMerged += $underfilled->count();
                });
            }
        }

        $this->line("\n" . str_repeat('=', 50));
        $this->info("Done! Merged {$totalMerged} fragmented papers into {$totalNewPapers} complete papers.");

        return self::SUCCESS;
    }
}
