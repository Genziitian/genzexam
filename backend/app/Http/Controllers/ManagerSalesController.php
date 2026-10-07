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

    /**
     * Sales analytics for the manager: totals, the last 14 days, and a
     * per-paper breakdown. "Unpaid" means a checkout the student opened but
     * never completed, and did not later complete with another order.
     */
    public function summary(Request $request): JsonResponse
    {
        $this->assertManager($request);
        $zone = 'Asia/Kolkata';
        $paid = fn () => QuizStorefrontOrder::query()->where('status', 'paid');
        $revenueSince = fn ($from) => (int) $paid()->where('paid_at', '>=', $from)->sum('amount_paise');
        $today = now($zone)->startOfDay();

        $paidOrders = $paid()->count();
        $revenue = (int) $paid()->sum('amount_paise');
        $unpaidOrders = $this->unpaid()->count();

        $days = [];
        for ($i = 13; $i >= 0; $i--) {
            $days[$today->copy()->subDays($i)->toDateString()] = ['orders' => 0, 'revenue_paise' => 0];
        }
        $paid()->where('paid_at', '>=', $today->copy()->subDays(13)->utc())->get(['paid_at', 'amount_paise'])
            ->each(function (QuizStorefrontOrder $order) use (&$days, $zone) {
                $day = $order->paid_at->copy()->setTimezone($zone)->toDateString();
                if (isset($days[$day])) {
                    $days[$day]['orders']++;
                    $days[$day]['revenue_paise'] += (int) $order->amount_paise;
                }
            });

        $sold = $paid()->selectRaw('quiz_id, COUNT(*) as sold, SUM(amount_paise) as revenue_paise, COUNT(DISTINCT user_id) as buyers, MAX(paid_at) as last_paid_at')
            ->groupBy('quiz_id')->get()->keyBy('quiz_id');
        $open = $this->unpaid()->selectRaw('quiz_id, COUNT(*) as unpaid')->groupBy('quiz_id')->get()->keyBy('quiz_id');
        $quizzes = Quiz::query()->with('course:id,name')
            ->whereIn('id', $sold->keys()->merge($open->keys())->unique()->values())
            ->get(['id', 'title', 'course_id', 'price_paise', 'is_active']);
        $papers = $quizzes->map(fn (Quiz $quiz) => [
            'id' => $quiz->id,
            'title' => $quiz->title,
            'course_name' => $quiz->course?->name,
            'price_paise' => (int) $quiz->price_paise,
            'is_active' => (bool) $quiz->is_active,
            'sold' => (int) ($sold->get($quiz->id)?->sold ?? 0),
            'buyers' => (int) ($sold->get($quiz->id)?->buyers ?? 0),
            'revenue_paise' => (int) ($sold->get($quiz->id)?->revenue_paise ?? 0),
            'unpaid' => (int) ($open->get($quiz->id)?->unpaid ?? 0),
            'last_paid_at' => $sold->get($quiz->id)?->last_paid_at,
        ])->sortByDesc(fn (array $paper) => [$paper['revenue_paise'], $paper['unpaid']])->values();

        return response()->json([
            'totals' => [
                'paid_orders' => $paidOrders,
                'revenue_paise' => $revenue,
                'buyers' => $paid()->distinct()->count('user_id'),
                'average_paise' => $paidOrders ? (int) round($revenue / $paidOrders) : 0,
                'revenue_today_paise' => $revenueSince($today->copy()->utc()),
                'revenue_7d_paise' => $revenueSince($today->copy()->subDays(6)->utc()),
                'revenue_30d_paise' => $revenueSince($today->copy()->subDays(29)->utc()),
                'unpaid_orders' => $unpaidOrders,
                'unpaid_students' => $this->unpaid()->distinct()->count('user_id'),
                'unpaid_value_paise' => (int) $this->unpaid()->sum('amount_paise'),
                'conversion_percent' => $paidOrders + $unpaidOrders ? (int) round($paidOrders * 100 / ($paidOrders + $unpaidOrders)) : null,
                'paid_papers' => Quiz::query()->where('price_paise', '>', 0)->count(),
            ],
            'days' => collect($days)->map(fn (array $day, string $date) => ['date' => $date, ...$day])->values(),
            'papers' => $papers,
        ]);
    }

    public function purchases(Request $request): JsonResponse
    {
        $this->assertManager($request);
        $filters = $request->validate([
            // unpaid: checkout opened, never paid. created: every unpaid order, even if paid later.
            'status' => ['nullable', Rule::in(['created', 'paid', 'unpaid'])],
            'quiz_id' => ['nullable', 'integer', 'exists:quizzes,id'],
            'search' => ['nullable', 'string', 'max:100'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        $status = $filters['status'] ?? null;
        $search = trim((string) ($filters['search'] ?? ''));
        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $search).'%';
        $query = ($status === 'unpaid' ? $this->unpaid() : QuizStorefrontOrder::query())
            ->when(in_array($status, ['created', 'paid'], true), fn ($query) => $query->where('status', $status))
            ->when($filters['quiz_id'] ?? null, fn ($query, $id) => $query->where('quiz_id', $id))
            ->when($search !== '', fn ($query) => $query->where(fn ($query) => $query
                ->whereHas('user', fn ($user) => $user->where('name', 'like', $like)->orWhere('email', 'like', $like))
                ->orWhereHas('quiz', fn ($quiz) => $quiz->where('title', 'like', $like))
                ->orWhere('razorpay_order_id', 'like', $like)
                ->orWhere('razorpay_payment_id', 'like', $like)));
        $totals = [
            'orders' => (clone $query)->count(),
            'paid_orders' => (clone $query)->where('status', 'paid')->count(),
            'revenue_paise' => (int) (clone $query)->where('status', 'paid')->sum('amount_paise'),
        ];
        $orders = $query->with(['user:id,name,email', 'quiz:id,title,course_id', 'quiz.course:id,name'])
            ->orderByDesc('id')->paginate($filters['per_page'] ?? 50);

        // An unpaid order counts as "paid later" when the same student bought the same paper with another order.
        $open = collect($orders->items())->where('status', 'created');
        $paidPairs = $open->isEmpty() ? collect() : QuizStorefrontOrder::query()->where('status', 'paid')
            ->whereIn('user_id', $open->pluck('user_id')->unique())->whereIn('quiz_id', $open->pluck('quiz_id')->unique())
            ->get(['user_id', 'quiz_id'])->map(fn (QuizStorefrontOrder $order) => $order->user_id.':'.$order->quiz_id)->flip();

        $orders->through(fn (QuizStorefrontOrder $order) => [
            'id' => $order->id,
            'user' => $order->user ? ['id' => $order->user->id, 'name' => $order->user->name, 'email' => $order->user->email] : null,
            'quiz' => $order->quiz ? ['id' => $order->quiz->id, 'title' => $order->quiz->title, 'course_id' => $order->quiz->course_id, 'course_name' => $order->quiz->course?->name] : null,
            'amount_paise' => (int) $order->amount_paise,
            'currency' => $order->currency,
            'status' => $order->status,
            'state' => $order->status === 'paid' ? 'paid' : ($paidPairs->has($order->user_id.':'.$order->quiz_id) ? 'paid_later' : 'unpaid'),
            'access_days' => $order->access_days,
            'razorpay_order_id' => $order->razorpay_order_id,
            'razorpay_payment_id' => $order->razorpay_payment_id,
            'paid_at' => $order->paid_at,
            'created_at' => $order->created_at,
        ]);
        return response()->json([...$orders->toArray(), 'totals' => $totals]);
    }

    /** Checkouts that were opened and never paid, by this order or a later one. */
    private function unpaid()
    {
        return QuizStorefrontOrder::query()->where('quiz_storefront_orders.status', 'created')
            ->whereNotExists(fn ($query) => $query->selectRaw('1')->from('quiz_storefront_orders as paid')
                ->whereColumn('paid.user_id', 'quiz_storefront_orders.user_id')
                ->whereColumn('paid.quiz_id', 'quiz_storefront_orders.quiz_id')
                ->where('paid.status', 'paid'));
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
