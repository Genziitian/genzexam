<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Quiz;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;



class AdminQuizController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $quizzes = Quiz::query()
            ->with([
                'course:id,name',
                'week:id,week_number',
            ])
            ->withCount('questions')
            ->when(! $request->user()->isManager(), fn ($query) => $query->whereIn('course_id', $request->user()->assignedCourses()->select('courses.id')))
            ->when($request->filled('course_id'), fn ($query) => $query->where('course_id', $request->integer('course_id')))
            ->when($request->filled('section'), fn ($query) => $query->where('section', $request->string('section')))
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (Quiz $quiz) => [
                'id' => $quiz->id,
                'title' => $quiz->title,
                'description' => $quiz->description,
                'section' => $quiz->section,
                'year' => $quiz->year,
                'course_id' => $quiz->course_id,
                'course_name' => $quiz->course?->name,
                'week_id' => $quiz->week_id,
                'week_number' => $quiz->week?->week_number,
                'time_limit_minutes' => $quiz->time_limit_minutes,
                'is_active' => (bool) $quiz->is_active,
                'price_paise' => (int) $quiz->price_paise,
                'access_days' => $quiz->access_days,
                'approval_status' => $quiz->approval_status,
                'created_by' => $quiz->created_by,
                'reviewed_by' => $quiz->reviewed_by,
                'reviewed_at' => $quiz->reviewed_at,
                'questions_count' => $quiz->questions_count,
                'created_at' => $quiz->created_at,
            ])
            ->values();

        return response()->json($quizzes);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'course_id' => ['required', 'exists:courses,id'],
            'section' => ['required', Rule::in(Quiz::SECTIONS)],
            'year' => ['nullable', 'integer', 'min:1990', 'max:2100'],
            'week_id' => ['nullable', 'exists:weeks,id', Rule::requiredIf(fn () => in_array($request->input('section'), Quiz::WEEKLY_SECTIONS, true))],
            'title' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'time_limit_minutes' => ['nullable', 'integer', 'min:1', 'max:300'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (! in_array($validated['section'] ?? null, Quiz::WEEKLY_SECTIONS, true)) {
            $validated['week_id'] = null;
        }

        if (! $request->user()->isManager() && ! $request->user()->assignedCourses()->whereKey($validated['course_id'])->exists()) {
            abort(403, 'You can only create papers for courses assigned to you.');
        }

        // Auto-fill the paper year from the title when the admin left it blank.
        if (empty($validated['year'])) {
            $validated['year'] = $this->parseYearFromTitle($validated['title']);
        }

        $isManager = $request->user()->isManager();
        $quiz = Quiz::query()->create([
            ...$validated,
            // New admin papers stay unpublished until a manager reviews them.
            'is_active' => $isManager && (bool) ($validated['is_active'] ?? false),
            'approval_status' => $isManager ? 'approved' : 'pending',
            'created_by' => $request->user()->id,
            'reviewed_by' => $isManager ? $request->user()->id : null,
            'reviewed_at' => $isManager ? now() : null,
        ]);

        return response()->json(
            $quiz->load([
                'course:id,name',
                'week:id,week_number',
            ])->loadCount('questions'),
            201
        );
    }

    public function show(int $id): JsonResponse
    {
        $quiz = Quiz::query()
            ->with([
                'course:id,name,slug',
                'week:id,week_number,title',
            ])
            ->withCount('questions')
            ->findOrFail($id);
        $this->assertQuizAccess(request(), $quiz);

        return response()->json($quiz);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $quiz = Quiz::query()->findOrFail($id);
        $this->assertQuizEditable($request, $quiz);

        $validated = $request->validate([
            'course_id' => ['sometimes', 'required', 'exists:courses,id'],
            'section' => ['sometimes', 'required', Rule::in(Quiz::SECTIONS)],
            'year' => ['nullable', 'integer', 'min:1990', 'max:2100'],
            'week_id' => ['nullable', 'exists:weeks,id'],
            'title' => ['sometimes', 'required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'time_limit_minutes' => ['nullable', 'integer', 'min:1', 'max:300'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (! $request->user()->isManager()) {
            if (isset($validated['course_id']) && ! $request->user()->assignedCourses()->whereKey($validated['course_id'])->exists()) {
                abort(403, 'You can only move papers to courses assigned to you.');
            }
            unset($validated['is_active']);
            // Editing an approved paper sends it back for review and takes it offline.
            if ($quiz->approval_status === 'approved') {
                $quiz->approval_status = 'pending';
                $quiz->is_active = false;
                $quiz->reviewed_by = null;
                $quiz->reviewed_at = null;
                $quiz->save();
            }
        } elseif (($validated['is_active'] ?? false) && $quiz->approval_status !== 'approved') {
            return response()->json(['error' => 'Approve this paper before activating it.'], 422);
        }

        $nextSection = $validated['section'] ?? $quiz->section;
        $needsWeek = in_array($nextSection, Quiz::WEEKLY_SECTIONS, true);
        if (! $needsWeek) {
            $validated['week_id'] = null;
        }

        if ($needsWeek && ! array_key_exists('week_id', $validated) && ! $quiz->week_id) {
            return response()->json([
                'message' => 'The week_id field is required for weekly sections (practice, practice_graded).',
                'errors' => [
                    'week_id' => ['The week_id field is required for weekly sections.'],
                ],
            ], 422);
        }

        $quiz->update($validated);

        return response()->json(
            $quiz->fresh()->load([
                'course:id,name,slug',
                'week:id,week_number,title',
            ])->loadCount('questions')
        );
    }

    public function destroy(int $id): JsonResponse
    {
        $quiz = Quiz::query()->findOrFail($id);
        $this->assertQuizEditable(request(), $quiz);
        if (\App\Models\QuizStorefrontOrder::query()->where('quiz_id', $quiz->id)->exists()) {
            return response()->json(['error' => 'This paper has checkout records. Disable the paper to remove it from sale while keeping purchase history.'], 409);
        }
        $quiz->delete();

        return response()->json([
            'message' => 'Quiz deleted successfully.',
        ]);
    }

    public function toggle(Request $request, int $id): JsonResponse
    {
        if (! $request->user()->isManager()) {
            return response()->json(['error' => 'Only a manager can publish or disable papers.'], 403);
        }
        $quiz = Quiz::query()->findOrFail($id);
        if ($quiz->approval_status !== 'approved') {
            return response()->json(['error' => 'A manager must approve this paper before it can be activated.'], 422);
        }
        $quiz->update([
            'is_active' => ! $quiz->is_active,
        ]);

        return response()->json($quiz->fresh());
    }

    public function approve(Request $request, int $id): JsonResponse
    {
        $quiz = Quiz::query()->findOrFail($id);
        $quiz->update([
            'approval_status' => 'approved',
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        return response()->json($quiz->fresh()->load(['course:id,name', 'week:id,week_number']));
    }

    private function assertQuizAccess(Request $request, Quiz $quiz): void
    {
        abort_unless(
            $request->user()->isManager() || $request->user()->assignedCourses()->whereKey($quiz->course_id)->exists(),
            403,
            'This paper belongs to a course that is not assigned to you.'
        );
    }

    private function assertQuizEditable(Request $request, Quiz $quiz): void
    {
        $this->assertQuizAccess($request, $quiz);
        abort_unless(
            $request->user()->isManager() || (int) $quiz->created_by === (int) $request->user()->id,
            403,
            'You can only edit papers you created. A manager can edit any paper.'
        );
    }

    /**
     * Pull a 4-digit year (1990–2099) out of a quiz title, e.g. "Endterm 2023".
     */
    private function parseYearFromTitle(?string $title): ?int
    {
        if (! $title) {
            return null;
        }

        if (preg_match('/\b(19|20)\d{2}\b/', $title, $matches)) {
            return (int) $matches[0];
        }

        return null;
    }
}
