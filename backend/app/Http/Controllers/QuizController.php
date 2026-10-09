<?php

namespace App\Http\Controllers;

use App\Models\Attempt;
use App\Models\Quiz;
use App\Support\StudentAppMode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Exceptions\HttpResponseException;

class QuizController extends Controller
{
    public function downloadForOffline(Request $request, int $id): JsonResponse
    {
        abort_unless($request->user()->hasProAccess(), 403, 'Offline paper downloads require Quiz LAB Pro.');
        return $this->show($request, $id);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $quiz = Quiz::withoutGlobalScope('exclude_personal_uploads')
            ->where(function ($query) use ($request) {
                $query->where('is_personal', false)
                    ->orWhere(fn ($owned) => $owned->where('is_personal', true)->where('owner_user_id', $request->user()->id));
            })
            ->where('is_active', true)
            ->where('approval_status', 'approved')
            ->whereHas('course', fn ($query) => $query->where('is_active', true))
            ->with([
                'course:id,name,slug',
                'questions' => fn ($query) => $query
                    ->orderBy('position')
                    ->with([
                        'questionOptions' => fn ($optionQuery) => $optionQuery
                            ->orderBy('position')
                            ->getQuery(),
                    ]),
            ])
            ->findOrFail($id);

        if ($request->user()->isAdmin() && ! StudentAppMode::enabled($request) && ! $request->user()->assignedCourses()->whereKey($quiz->course_id)->exists()) {
            throw new HttpResponseException(response()->json(['error' => 'This course is not assigned to you.'], 403));
        }

        if (StudentAppMode::isStudent($request) && (int) $quiz->price_paise > 0) {
            $hasAccess = \App\Models\QuizEntitlement::query()
                ->where('user_id', $request->user()->id)
                ->where('quiz_id', $quiz->id)
                ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                ->exists();

            if (! $hasAccess) {
                return response()->json([
                    'error' => 'purchase_required',
                    'message' => 'Purchase this paper to open it.',
                    'price_paise' => (int) $quiz->price_paise,
                ], 402);
            }
        }

        return response()->json([
            'id' => $quiz->id,
            'title' => $quiz->title,
            'description' => $quiz->description,
            'section' => $quiz->section,
            'time_limit_minutes' => $quiz->time_limit_minutes,
            'course' => [
                'id' => $quiz->course?->id,
                'name' => $quiz->course?->name,
                'slug' => $quiz->course?->slug,
            ],
            'questions' => $quiz->questions->map(fn ($question) => [
                'id' => $question->id,
                'type' => $question->type,
                'stem' => $question->stem,
                'stem_image' => $question->stem_image,
                'stem_code' => $question->stem_code,
                'stem_code_language' => $question->stem_code_language,
                'stem_table' => $question->stem_table,
                'marks' => (float) $question->marks,
                'difficulty' => $question->difficulty,
                'position' => $question->position,
                'options' => $question->questionOptions->map(fn ($option) => [
                    'id' => $option->id,
                    'option_type' => $option->option_type,
                    'option_text' => $option->option_text,
                    'code_language' => $option->code_language,
                    'position' => $option->position,
                ])->values(),
            ])->values(),
        ]);
    }

    public function leaderboard(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        abort_if($user->isAdmin() && ! StudentAppMode::enabled($request), 403, 'Leaderboards are not available in teacher content management.');
        Quiz::query()->findOrFail($id);

        $attempts = Attempt::query()
            ->where('quiz_id', $id)
            ->where('is_complete', true)
            ->whereNotNull('score')
            ->with('user:id,name')
            ->orderByDesc('score')
            ->orderBy('submitted_at')
            ->get();

        $rankedRows = $attempts->values()->map(function (Attempt $attempt, int $index) {
            $nameParts = preg_split('/\s+/', trim((string) $attempt->user?->name));
            $first = $nameParts[0] ?? 'Student';
            $lastInitial = '';
            if (! empty($nameParts) && count($nameParts) > 1) {
                $lastInitial = strtoupper(substr((string) end($nameParts), 0, 1)).'.';
            }

            $displayName = trim($first.' '.$lastInitial);
            $totalMarks = (float) ($attempt->total_marks ?? 0);
            $score = (float) ($attempt->score ?? 0);
            $percentage = $totalMarks > 0 ? round(($score / $totalMarks) * 100, 2) : 0;

            return [
                'rank' => $index + 1,
                'user_id' => $attempt->user?->id,
                'name' => (string) ($attempt->user?->name ?? 'Student'),
                'display_name' => $displayName,
                'score' => $score,
                'total_marks' => $totalMarks,
                'percentage' => $percentage,
                'submitted_at' => $attempt->submitted_at,
            ];
        });

        $top = $rankedRows->take(10)->values();
        $me = $rankedRows->firstWhere('user_id', $user?->id);

        return response()->json([
            'top' => $top,
            'me' => $me,
        ]);
    }
}
