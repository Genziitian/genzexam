<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Admin\AdminQuizController;
use App\Models\Course;
use App\Models\Quiz;
use App\Models\QuizStorefrontOrder;
use App\Models\Week;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ManagerSalesController extends Controller
{
    public function papers(Request $request): JsonResponse
    {
        $this->assertManager($request);
        $response = app(AdminQuizController::class)->index($request);
        $papers = $response->getData(true);
        $courses = Course::query()->pluck('is_active', 'id');
        foreach ($papers as &$paper) {
            $paper['course_active'] = (bool) ($courses[$paper['course_id']] ?? false);
        }
        return response()->json($papers);
    }

    public function weeks(Request $request, int $id): JsonResponse
    {
        $this->assertManager($request);
        Course::query()->findOrFail($id);
        return response()->json(Week::query()->where('course_id', $id)->orderBy('week_number')
            ->get(['id', 'course_id', 'week_number', 'title', 'is_active']));
    }

    public function store(Request $request): JsonResponse
    {
        $this->assertManager($request);
        $pricing = $this->pricing($request);
        $this->validateWeek($request);
        $request->merge(['is_active' => false]);
        return DB::transaction(function () use ($request, $pricing) {
            $response = app(AdminQuizController::class)->store($request);
            if ($response->getStatusCode() >= 400) {
                return $response;
            }
            $quiz = Quiz::query()->findOrFail($response->getData(true)['id']);
            $quiz->update($pricing);
            return response()->json($this->loaded($quiz), 201);
        });
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $this->assertManager($request);
        $quiz = Quiz::query()->findOrFail($id);
        $pricing = $this->pricing($request);
        $this->validateWeek($request, $quiz);
        // Publication is a separate, deliberate step after reviewing content.
        $request->merge(['is_active' => false]);
        return DB::transaction(function () use ($request, $id, $pricing) {
            $response = app(AdminQuizController::class)->update($request, $id);
            if ($response->getStatusCode() >= 400) {
                return $response;
            }
            $quiz = Quiz::query()->findOrFail($id);
            $quiz->update($pricing);
            return response()->json($this->loaded($quiz));
        });
    }

    public function setActive(Request $request, int $id): JsonResponse
    {
        $this->assertManager($request);
        $validated = $request->validate(['is_active' => ['required', 'boolean']]);
        return DB::transaction(function () use ($id, $validated) {
            $quiz = Quiz::query()->lockForUpdate()->findOrFail($id);
            if ($validated['is_active']) {
                abort_unless($quiz->approval_status === 'approved', 422, 'Approve this paper before publishing it.');
                abort_unless($quiz->course?->is_active, 422, 'Enable the course before publishing its papers.');
                abort_unless($quiz->questions()->where('type', '!=', 'comprehension')->exists(), 422, 'Add at least one answerable question before publishing.');
                abort_if((int) $quiz->price_paise > 0 && (int) $quiz->price_paise < 100, 422, 'Paid papers must cost at least ₹1.');
            }
            $quiz->update(['is_active' => (bool) $validated['is_active']]);
            return response()->json($this->loaded($quiz));
        });
    }

    public function purchases(Request $request): JsonResponse
    {
        $this->assertManager($request);
        $filters = $request->validate([
            'status' => ['nullable', Rule::in(['created', 'paid'])],
            'quiz_id' => ['nullable', 'integer', 'exists:quizzes,id'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        $query = QuizStorefrontOrder::query()
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->when($filters['quiz_id'] ?? null, fn ($query, $id) => $query->where('quiz_id', $id));
        $totals = [
            'orders' => (clone $query)->count(),
            'paid_orders' => (clone $query)->where('status', 'paid')->count(),
            'revenue_paise' => (int) (clone $query)->where('status', 'paid')->sum('amount_paise'),
        ];
        $orders = $query->with(['user:id,name,email', 'quiz:id,title,course_id'])
            ->orderByDesc('id')->paginate($filters['per_page'] ?? 50);
        $orders->through(fn (QuizStorefrontOrder $order) => [
            'id' => $order->id,
            'user' => $order->user ? ['id' => $order->user->id, 'name' => $order->user->name, 'email' => $order->user->email] : null,
            'quiz' => $order->quiz ? ['id' => $order->quiz->id, 'title' => $order->quiz->title, 'course_id' => $order->quiz->course_id] : null,
            'amount_paise' => (int) $order->amount_paise,
            'currency' => $order->currency,
            'status' => $order->status,
            'access_days' => $order->access_days,
            'razorpay_order_id' => $order->razorpay_order_id,
            'razorpay_payment_id' => $order->razorpay_payment_id,
            'paid_at' => $order->paid_at,
            'created_at' => $order->created_at,
        ]);
        return response()->json([...$orders->toArray(), 'totals' => $totals]);
    }

    private function pricing(Request $request): array
    {
        $pricing = $request->validate([
            'price_paise' => ['sometimes', 'required', 'integer', 'min:0', 'max:100000000'],
            'access_days' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:3650'],
        ]);
        if (($pricing['price_paise'] ?? 0) > 0 && $pricing['price_paise'] < 100) {
            throw ValidationException::withMessages(['price_paise' => 'Set a price of at least ₹1, or 0 for free.']);
        }
        return $pricing;
    }

    private function validateWeek(Request $request, ?Quiz $quiz = null): void
    {
        $section = $request->input('section', $quiz?->section);
        if (! in_array($section, Quiz::WEEKLY_SECTIONS, true)) {
            return;
        }
        $weekId = $request->input('week_id', $quiz?->week_id);
        $courseId = $request->input('course_id', $quiz?->course_id);
        if (! $weekId || ! Week::query()->whereKey($weekId)->where('course_id', $courseId)->exists()) {
            throw ValidationException::withMessages(['week_id' => 'Choose a week belonging to the selected course.']);
        }
    }

    private function loaded(Quiz $quiz): Quiz
    {
        return $quiz->fresh()->load(['course:id,name,slug,is_active', 'week:id,week_number,title'])->loadCount('questions');
    }

    private function assertManager(Request $request): void
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');
    }
}
