<?php

namespace App\Http\Controllers;

use App\Models\Course;
use App\Models\Question;
use App\Models\QuestionOption;
use App\Models\Quiz;
use App\Models\ShortAnswerAcceptable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StudentSpinPracticeController extends Controller
{
    public function generate(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user, 401, 'Please sign in to create a practice paper.');

        $validated = $request->validate([
            'course_id' => ['required', 'integer', 'exists:courses,id'],
            'week_min' => ['nullable', 'integer', 'min:1', 'max:12'],
            'week_max' => ['nullable', 'integer', 'min:1', 'max:12'],
            'paper_types' => ['nullable'],
            'title' => ['nullable', 'string', 'max:200'],
            'time_limit_minutes' => ['nullable', 'integer', 'min:5', 'max:180'],
        ]);

        $course = Course::query()->where('is_active', true)->findOrFail($validated['course_id']);

        $weekMin = max(1, min(12, (int) ($validated['week_min'] ?? 1)));
        $weekMax = max(1, min(12, (int) ($validated['week_max'] ?? 12)));
        if ($weekMin > $weekMax) {
            [$weekMin, $weekMax] = [$weekMax, $weekMin];
        }

        $rawTypes = $validated['paper_types'] ?? ['all'];
        if (is_string($rawTypes)) {
            $rawTypes = array_map('trim', explode(',', $rawTypes));
        }
        $rawTypes = is_array($rawTypes) ? $rawTypes : ['all'];

        $typeMap = [
            'pa' => 'practice',
            'practice' => 'practice',
            'ga' => 'practice_graded',
            'practice_graded' => 'practice_graded',
            'quiz1' => 'quiz1',
            'quiz2' => 'quiz2',
            'endterm' => 'endterm',
            'mock' => 'mock_test',
            'mock_test' => 'mock_test',
        ];

        $includeAll = in_array('all', $rawTypes, true) || in_array('*', $rawTypes, true) || empty($rawTypes);
        $selectedSections = [];
        if (! $includeAll) {
            foreach ($rawTypes as $t) {
                $lower = strtolower((string) $t);
                if (isset($typeMap[$lower])) {
                    $selectedSections[] = $typeMap[$lower];
                }
            }
            $selectedSections = array_unique($selectedSections);
        }
        if (empty($selectedSections)) {
            $selectedSections = Quiz::SECTIONS;
        }

        $matchingQuizzes = Quiz::withoutGlobalScope('exclude_personal_uploads')
            ->where('course_id', $course->id)
            ->where('is_active', true)
            ->where('approval_status', 'approved')
            ->where('is_personal', false)
            ->whereIn('section', $selectedSections)
            ->with(['week:id,week_number,title'])
            ->get();

        $matchingQuizIds = [];
        foreach ($matchingQuizzes as $q) {
            if ($q->week) {
                $wn = (int) $q->week->week_number;
                if ($wn >= $weekMin && $wn <= $weekMax) {
                    $matchingQuizIds[] = $q->id;
                }
            } else {
                if ($this->sectionMatchesWeekRange($q->section, $weekMin, $weekMax)) {
                    $matchingQuizIds[] = $q->id;
                }
            }
        }

        if (empty($matchingQuizIds)) {
            return response()->json([
                'error' => "No papers found for {$course->name} in weeks {$weekMin}–{$weekMax} with the selected paper types. Try selecting more weeks or all paper types.",
            ], 422);
        }

        $questions = Question::query()
            ->whereIn('quiz_id', $matchingQuizIds)
            ->with([
                'questionOptions' => fn ($opt) => $opt->orderBy('position'),
                'shortAnswerAcceptables',
            ])
            ->inRandomOrder()
            ->limit(10)
            ->get();

        if ($questions->isEmpty()) {
            return response()->json([
                'error' => "No questions found in the selected papers for {$course->name}. Try broadening your selection.",
            ], 422);
        }

        $timeLimitMinutes = max(5, min(180, (int) ($validated['time_limit_minutes'] ?? 20)));
        $customTitle = trim((string) ($validated['title'] ?? ''));
        $paperTitle = $customTitle !== '' ? $customTitle : "{$course->name} — W{$weekMin}-W{$weekMax} Practice";

        $quiz = DB::transaction(function () use ($course, $paperTitle, $timeLimitMinutes, $questions, $user, $weekMin, $weekMax) {
            $newQuiz = Quiz::query()->create([
                'course_id' => $course->id,
                'week_id' => null,
                'section' => 'practice',
                'title' => mb_substr($paperTitle, 0, 200),
                'description' => "Unified practice paper generated from Spin Wheel ({$course->name}, Weeks {$weekMin}–{$weekMax}).",
                'time_limit_minutes' => $timeLimitMinutes,
                'price_paise' => 0,
                'is_active' => true,
                'approval_status' => 'approved',
                'created_by' => $user->id,
                'is_personal' => true,
                'owner_user_id' => $user->id,
            ]);

            $position = 1;
            foreach ($questions as $q) {
                $newQuestion = Question::query()->create([
                    'quiz_id' => $newQuiz->id,
                    'type' => $q->type,
                    'stem' => $q->stem,
                    'stem_image' => $q->stem_image,
                    'stem_code' => $q->stem_code,
                    'stem_code_language' => $q->stem_code_language,
                    'stem_table' => $q->stem_table,
                    'explanation' => $q->explanation,
                    'marks' => $q->marks ?: 1,
                    'difficulty' => $q->difficulty ?: 'medium',
                    'position' => $position++,
                    'numerical_answer' => $q->numerical_answer,
                    'numerical_tolerance' => $q->numerical_tolerance,
                ]);

                foreach ($q->questionOptions as $opt) {
                    QuestionOption::query()->create([
                        'question_id' => $newQuestion->id,
                        'option_type' => $opt->option_type,
                        'option_text' => $opt->option_text,
                        'code_language' => $opt->code_language,
                        'is_correct' => $opt->is_correct,
                        'position' => $opt->position,
                    ]);
                }

                foreach ($q->shortAnswerAcceptables as $saa) {
                    ShortAnswerAcceptable::query()->create([
                        'question_id' => $newQuestion->id,
                        'acceptable_text' => $saa->acceptable_text,
                    ]);
                }
            }

            return $newQuiz;
        });

        return response()->json([
            'id' => $quiz->id,
            'title' => $quiz->title,
            'course' => [
                'id' => $course->id,
                'name' => $course->name,
                'slug' => $course->slug,
            ],
            'question_count' => $questions->count(),
            'time_limit_minutes' => $quiz->time_limit_minutes,
            'week_range' => [
                'min' => $weekMin,
                'max' => $weekMax,
            ],
            'paper_room_url' => "/paper/{$quiz->id}",
            'my_papers_url' => "/my-papers",
            'message' => "Your practice paper '{$quiz->title}' with {$questions->count()} questions is ready!",
        ], 201);
    }

    private function sectionMatchesWeekRange(string $section, int $min, int $max): bool
    {
        return match ($section) {
            'quiz1' => ! ($max < 1 || $min > 4),
            'quiz2' => ! ($max < 5 || $min > 8),
            'endterm', 'mock_test' => ! ($max < 1 || $min > 12),
            default => true,
        };
    }
}
