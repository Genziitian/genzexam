<?php

namespace App\Http\Controllers;

use App\Models\Course;
use App\Models\Question;
use App\Models\Quiz;
use App\Models\Week;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Manager review of papers Pro students uploaded. A student's upload stays a
 * private test; publishing makes a public copy the manager can file under a
 * course and week, so later edits to either side never touch the other.
 */
class ManagerUploadedPaperController extends Controller
{
    private function uploads()
    {
        return Quiz::withoutGlobalScope('exclude_personal_uploads')->fileUploads();
    }

    public function index(Request $request): JsonResponse
    {
        $request->validate(['state' => ['sometimes', 'in:new,published,all']]);
        $state = $request->input('state', 'new');
        $query = $this->uploads()->with(['owner:id,name,email', 'course:id,name'])->withCount('questions')->latest('id');
        if ($state === 'new') $query->whereNull('published_quiz_id');
        if ($state === 'published') $query->whereNotNull('published_quiz_id');
        $counts = [
            'new' => $this->uploads()->whereNull('published_quiz_id')->count(),
            'published' => $this->uploads()->whereNotNull('published_quiz_id')->count(),
        ];

        return response()->json([
            'papers' => $query->limit(200)->get()->map(fn (Quiz $q) => $this->summary($q))->values(),
            'counts' => $counts,
        ]);
    }

    public function show(int $id): JsonResponse
    {
        $quiz = $this->uploads()->with(['owner:id,name,email', 'course:id,name'])->withCount('questions')->findOrFail($id);
        $questions = Question::query()->where('quiz_id', $quiz->id)->with('questionOptions')->orderBy('position')->get()
            ->map(fn (Question $q) => [
                'id' => $q->id,
                'type' => $q->type,
                'stem' => $q->stem,
                'marks' => $q->marks,
                'numerical_answer' => $q->numerical_answer,
                'options' => $q->questionOptions->map(fn ($o) => ['text' => $o->option_text, 'is_correct' => (bool) $o->is_correct])->values(),
            ])->values();

        return response()->json(['paper' => $this->summary($quiz), 'questions' => $questions]);
    }

    /** Publish (or refresh) the public copy with the course, week and details the manager chose. */
    public function publish(Request $request, int $id): JsonResponse
    {
        $source = $this->uploads()->findOrFail($id);
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'course_id' => ['required', 'integer', Rule::exists('courses', 'id')],
            'week_id' => ['nullable', 'integer', Rule::exists('weeks', 'id')],
            'section' => ['required', 'string', Rule::in(Quiz::SECTIONS)],
            'year' => ['nullable', 'integer', 'min:2000', 'max:2100'],
            'description' => ['nullable', 'string', 'max:2000'],
            'time_limit_minutes' => ['nullable', 'integer', 'min:1', 'max:600'],
        ]);
        if (! empty($data['week_id'])) {
            abort_unless(Week::query()->whereKey($data['week_id'])->where('course_id', $data['course_id'])->exists(), 422, 'That week belongs to a different course.');
        }
        $attributes = [
            'course_id' => $data['course_id'],
            'week_id' => $data['week_id'] ?? null,
            'section' => $data['section'],
            'year' => $data['year'] ?? null,
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'time_limit_minutes' => $data['time_limit_minutes'] ?? null,
        ];
        $manager = $request->user();

        $public = DB::transaction(function () use ($source, $attributes, $manager) {
            $existing = $source->published_quiz_id ? Quiz::query()->find($source->published_quiz_id) : null;
            if ($existing) {
                // Re-publishing only refreshes the details; the questions may already have been edited.
                $existing->fill($attributes + ['is_active' => true, 'approval_status' => 'approved'])->save();
                $public = $existing;
            } else {
                $public = Quiz::query()->create($attributes + [
                    'price_paise' => 0,
                    'is_active' => true,
                    'approval_status' => 'approved',
                    'created_by' => $manager->id,
                    'reviewed_by' => $manager->id,
                    'reviewed_at' => now(),
                    'is_personal' => false,
                    'owner_user_id' => null,
                ]);
                $this->copyQuestions($source, $public);
            }
            $source->forceFill(['published_quiz_id' => $public->id, 'upload_reviewed_at' => now()])->save();

            return $public;
        });

        return response()->json(['ok' => true, 'published_quiz_id' => $public->id], 201);
    }

    /** Take the public copy offline and return the upload to the review queue. */
    public function unpublish(int $id): JsonResponse
    {
        $source = $this->uploads()->findOrFail($id);
        if ($source->published_quiz_id) {
            Quiz::query()->whereKey($source->published_quiz_id)->update(['is_active' => false]);
        }
        $source->forceFill(['published_quiz_id' => null, 'upload_reviewed_at' => null])->save();

        return response()->json(['ok' => true]);
    }

    private function copyQuestions(Quiz $source, Quiz $target): void
    {
        Question::query()->where('quiz_id', $source->id)->with(['questionOptions', 'shortAnswerAcceptables'])->orderBy('position')->get()
            ->each(function (Question $question) use ($target) {
                $copy = $question->replicate(['id'])->fill(['quiz_id' => $target->id]);
                $copy->save();
                foreach ($question->questionOptions as $option) {
                    $copy->questionOptions()->create($option->only(['option_type', 'option_text', 'code_language', 'is_correct', 'position']));
                }
                foreach ($question->shortAnswerAcceptables as $acceptable) {
                    $copy->shortAnswerAcceptables()->create($acceptable->only(['acceptable_text']));
                }
            });
    }

    private function summary(Quiz $q): array
    {
        return [
            'id' => $q->id,
            'title' => $q->title,
            'course_id' => $q->course_id,
            'course_name' => $q->course?->name,
            'section' => $q->section,
            'question_count' => $q->questions_count,
            'created_at' => $q->created_at,
            'published_quiz_id' => $q->published_quiz_id,
            'owner' => $q->owner ? ['id' => $q->owner->id, 'name' => $q->owner->name, 'email' => $q->owner->email] : null,
        ];
    }
}
