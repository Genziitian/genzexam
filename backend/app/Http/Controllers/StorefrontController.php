<?php

namespace App\Http\Controllers;

use App\Models\Attempt;
use App\Models\Quiz;
use App\Models\QuizEntitlement;
use App\Models\QuizStorefrontOrder;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class StorefrontController extends Controller
{
    public function papers(Request $request): JsonResponse
    {
        $user = $request->user();
        $papers = Quiz::query()
            ->where('is_personal', false)
            ->where('is_active', true)
            ->where('approval_status', 'approved')
            ->when($user?->isAdmin(), fn ($query) => $query->whereIn('course_id', $user->assignedCourses()->select('courses.id')))
            ->whereHas('course', fn ($query) => $query->where('is_active', true))
            ->with(['course:id,name,slug,level,icon', 'week:id,week_number,title'])
            ->withCount('questions')
            ->orderBy('course_id')
            ->orderByDesc('year')
            ->orderBy('section')
            ->get()
            ->map(fn (Quiz $quiz) => $this->paperSummary($quiz));

        return response()->json(['papers' => $papers]);
    }

    /**
     * My Papers is the student's own record: papers they paid for and papers
     * they have started. Free papers they never opened stay in the catalogue.
     */
    public function myPapers(Request $request): JsonResponse
    {
        $user = $request->user();
        // Managers and admins open every paper without buying, so they only ever see their attempts here.
        $staff = ! $user->isStudent();

        $entitlements = QuizEntitlement::query()
            ->where('user_id', $user->id)
            ->get()
            ->keyBy('quiz_id');

        // One row per attempt; a single student has few enough to group in memory.
        $attempts = Attempt::query()
            ->where('user_id', $user->id)
            ->orderBy('id')
            ->get(['id', 'quiz_id', 'started_at', 'submitted_at', 'score', 'total_marks', 'is_complete'])
            ->groupBy('quiz_id');

        $personalIds = $user->isStudent()
            ? Quiz::withoutGlobalScope('exclude_personal_uploads')->where('is_personal', true)->where('owner_user_id', $user->id)->pluck('id')
            : collect();

        $quizzes = Quiz::withoutGlobalScope('exclude_personal_uploads')
            ->whereIn('id', $entitlements->keys()->merge($attempts->keys())->merge($personalIds)->unique()->values())
            ->where(fn ($query) => $query->where('is_personal', false)
                ->orWhere(fn ($owned) => $owned->where('is_personal', true)->where('owner_user_id', $user->id)))
            ->with(['course:id,name,slug,level,icon,is_active', 'week:id,week_number,title'])
            ->withCount('questions')
            ->get();

        $papers = $quizzes->map(function (Quiz $quiz) use ($entitlements, $attempts, $staff) {
            $entitlement = $entitlements->get($quiz->id);
            $rows = $attempts->get($quiz->id, collect());
            if ($quiz->is_personal) {
                return [
                    ...$this->paperSummary($quiz),
                    'course' => ['name' => 'My uploads', 'slug' => ''],
                    'source' => 'personal_upload',
                    'purchased' => false,
                    'owned_since' => $quiz->created_at,
                    'expires_at' => null,
                    'expired' => false,
                    'has_access' => true,
                    'available' => true,
                    'attempt_count' => $rows->filter(fn (Attempt $attempt) => $attempt->is_complete && $attempt->submitted_at)->count(),
                    'in_progress' => $rows->first(fn (Attempt $attempt) => ! $attempt->is_complete) !== null,
                    'last_attempt_id' => $rows->last()?->id,
                    'last_score' => $rows->last()?->score,
                    'last_total_marks' => $rows->last()?->total_marks,
                    'last_submitted_at' => $rows->last()?->submitted_at,
                    'last_activity_at' => $rows->last()?->submitted_at ?? $quiz->created_at,
                ];
            }
            $paid = (int) $quiz->price_paise > 0;
            $purchased = $entitlement?->source === 'purchase';
            $active = $entitlement && ($entitlement->expires_at === null || $entitlement->expires_at->isFuture());
            $available = $quiz->is_active && $quiz->approval_status === 'approved' && (bool) $quiz->course?->is_active;

            // A free claim on a paper that is still free was never more than a bookmark.
            if ($rows->isEmpty() && ! $purchased && ! $paid) {
                return null;
            }
            // A free paper that has been withdrawn leaves nothing to open.
            if (! $available && ! $purchased && ! ($paid && $entitlement)) {
                return null;
            }

            $last = $rows->filter(fn (Attempt $attempt) => $attempt->is_complete && $attempt->submitted_at)->last();
            $open = $rows->first(fn (Attempt $attempt) => ! $attempt->is_complete);
            $activity = collect([$entitlement?->updated_at, $rows->last()?->submitted_at, $rows->last()?->started_at])
                ->filter()->max();

            return [
                ...$this->paperSummary($quiz),
                'source' => $entitlement?->source,
                'purchased' => $purchased,
                'owned_since' => $entitlement?->created_at,
                'expires_at' => $paid || $purchased ? $entitlement?->expires_at : null,
                'expired' => ! $staff && $paid && $entitlement !== null && ! $active,
                'has_access' => $staff || ! $paid || $active,
                'available' => $available,
                'attempt_count' => $rows->filter(fn (Attempt $attempt) => $attempt->is_complete && $attempt->submitted_at)->count(),
                'in_progress' => $open !== null,
                'last_attempt_id' => $last?->id,
                'last_score' => $last?->score,
                'last_total_marks' => $last?->total_marks,
                'last_submitted_at' => $last?->submitted_at,
                'last_activity_at' => $activity,
            ];
        })->filter()->sortByDesc(fn (array $paper) => $paper['last_activity_at']?->getTimestamp() ?? 0)->values();

        return response()->json(['papers' => $papers]);
    }

    public function claimFree(Request $request, int $quizId): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user->isStudent(), 403, 'Student paper library only.');

        DB::transaction(function () use ($user, $quizId) {
            // Serialize all grants for a student, including the first entitlement.
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $quiz = $this->publishedQuiz($quizId, true);
            abort_if((int) $quiz->price_paise > 0, 409, 'This paper requires purchase.');
            $entitlement = QuizEntitlement::query()
                ->where('user_id', $user->id)->where('quiz_id', $quiz->id)->first();

            if (! $entitlement || ($entitlement->expires_at && $entitlement->expires_at->lte(now()))) {
                QuizEntitlement::query()->updateOrCreate(
                    ['user_id' => $user->id, 'quiz_id' => $quiz->id],
                    [
                        'order_id' => null,
                        'source' => 'free_claim',
                        'expires_at' => $quiz->access_days ? now()->addDays($quiz->access_days) : null,
                    ]
                );
            }
        }, 3);

        return response()->json(['entitled' => true, 'quiz_id' => $quizId]);
    }

    public function createOrder(Request $request, int $quizId): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user->isStudent(), 403, 'Student checkout only.');
        $this->requireRazorpayKeys();

        try {
            $order = DB::transaction(function () use ($user, $quizId) {
                User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
                $quiz = $this->publishedQuiz($quizId);
                $amount = (int) $quiz->price_paise;
                abort_if($amount < 100, 409, 'This paper is free or is not available for purchase.');
                $owned = QuizEntitlement::query()
                    ->where('user_id', $user->id)->where('quiz_id', $quiz->id)
                    ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                    ->exists();
                abort_if($owned, 409, 'You already have access to this paper.');

                // Repeated clicks and concurrent tabs share the same recent checkout.
                $existing = QuizStorefrontOrder::query()
                    ->where('user_id', $user->id)->where('quiz_id', $quiz->id)
                    ->where('status', 'created')->whereNotNull('razorpay_order_id')
                    ->where('amount_paise', $amount)->where('access_days', $quiz->access_days)
                    ->where('created_at', '>', now()->subMinutes(30))->latest('id')->first();
                if ($existing) {
                    return $existing;
                }

                $receipt = 'ql_'.Str::lower(Str::random(24));
                $response = Http::withBasicAuth(
                    (string) config('services.razorpay.key_id'),
                    (string) config('services.razorpay.key_secret')
                )->acceptJson()->connectTimeout(5)->timeout(20)->post('https://api.razorpay.com/v1/orders', [
                    'amount' => $amount,
                    'currency' => 'INR',
                    'receipt' => $receipt,
                    'notes' => ['quiz_id' => (string) $quiz->id, 'user_id' => (string) $user->id],
                ]);

                if (! $response->successful() || ! $response->json('id')) {
                    throw new HttpResponseException(response()->json(['error' => 'Checkout is temporarily unavailable. Please try again.'], 502));
                }

                return QuizStorefrontOrder::query()->create([
                    'user_id' => $user->id,
                    'quiz_id' => $quiz->id,
                    'razorpay_order_id' => $response->json('id'),
                    'amount_paise' => $amount,
                    'access_days' => $quiz->access_days,
                    'currency' => 'INR',
                    'status' => 'created',
                ]);
            });
        } catch (ConnectionException $exception) {
            return response()->json(['error' => 'Checkout is temporarily unavailable. Please try again.'], 502);
        }

        return response()->json([
            'order_id' => $order->razorpay_order_id,
            'amount' => (int) $order->amount_paise,
            'currency' => $order->currency,
            'key_id' => config('services.razorpay.key_id'),
            'name' => 'Quiz LAB by GenZ IITian',
            'description' => $order->quiz->title,
            'prefill' => ['name' => $user->name, 'email' => $user->email],
        ], 201);
    }

    public function verifyPayment(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user->isStudent(), 403, 'Student checkout only.');
        $this->requireRazorpayKeys();

        $validated = $request->validate([
            'razorpay_order_id' => ['required', 'string', 'max:80', 'regex:/^order_[A-Za-z0-9]+$/'],
            'razorpay_payment_id' => ['required', 'string', 'max:80', 'regex:/^pay_[A-Za-z0-9]+$/'],
            'razorpay_signature' => ['required', 'string', 'size:64', 'regex:/^[a-f0-9]{64}$/'],
        ]);

        $order = QuizStorefrontOrder::query()
            ->where('user_id', $user->id)
            ->where('razorpay_order_id', $validated['razorpay_order_id'])
            ->firstOrFail();

        $expectedSignature = hash_hmac(
            'sha256',
            $order->razorpay_order_id.'|'.$validated['razorpay_payment_id'],
            (string) config('services.razorpay.key_secret')
        );
        abort_unless(hash_equals($expectedSignature, $validated['razorpay_signature']), 400, 'Payment signature is invalid.');

        if ($order->status === 'paid') {
            abort_unless($order->razorpay_payment_id === $validated['razorpay_payment_id'], 409, 'Order already has a different payment.');
            return response()->json(['verified' => true, 'quiz_id' => $order->quiz_id]);
        }

        try {
            $paymentResponse = Http::withBasicAuth(
                (string) config('services.razorpay.key_id'),
                (string) config('services.razorpay.key_secret')
            )->acceptJson()->connectTimeout(5)->timeout(20)->get('https://api.razorpay.com/v1/payments/'.$validated['razorpay_payment_id']);
        } catch (ConnectionException $exception) {
            return response()->json(['error' => 'Payment confirmation is still processing. Please refresh your library shortly.'], 409);
        }

        if (! $paymentResponse->successful()) {
            return response()->json(['error' => 'Payment confirmation is still processing. Please refresh your library shortly.'], 409);
        }

        $payment = $paymentResponse->json();
        abort_unless(
            ($payment['id'] ?? null) === $validated['razorpay_payment_id']
                && ($payment['order_id'] ?? null) === $order->razorpay_order_id
                && (int) ($payment['amount'] ?? 0) === (int) $order->amount_paise
                && ($payment['currency'] ?? null) === 'INR',
            400,
            'Payment details do not match this paper.'
        );

        if (($payment['status'] ?? null) !== 'captured') {
            return response()->json(['error' => 'Payment is awaiting capture. Please refresh your library shortly.'], 409);
        }

        $this->grantPaidOrder($order, $validated['razorpay_payment_id']);

        return response()->json(['verified' => true, 'quiz_id' => $order->quiz_id]);
    }

    public function webhook(Request $request): JsonResponse
    {
        $secret = (string) config('services.razorpay.webhook_secret');
        abort_if($secret === '', 503, 'Razorpay webhook is not configured.');

        $signature = (string) $request->header('X-Razorpay-Signature');
        $expected = hash_hmac('sha256', $request->getContent(), $secret);
        abort_unless($signature !== '' && hash_equals($expected, $signature), 400, 'Webhook signature is invalid.');

        $payload = $request->json()->all();
        if (! in_array($payload['event'] ?? null, ['payment.captured', 'order.paid'], true)) {
            return response()->json(['received' => true]);
        }

        $payment = $payload['payload']['payment']['entity'] ?? [];
        abort_unless(is_array($payment) && preg_match('/^pay_[A-Za-z0-9]+$/', (string) ($payment['id'] ?? '')), 400, 'Payment ID is missing or invalid.');
        $order = QuizStorefrontOrder::query()->where('razorpay_order_id', $payment['order_id'] ?? '')->first();
        if (! $order) {
            return response()->json(['received' => true]);
        }

        abort_unless(
            (int) ($payment['amount'] ?? 0) === (int) $order->amount_paise
                && ($payment['currency'] ?? null) === 'INR'
                && ($payment['status'] ?? null) === 'captured',
            400,
            'Captured amount does not match the order.'
        );

        $this->grantPaidOrder($order, (string) ($payment['id'] ?? ''));

        return response()->json(['received' => true]);
    }

    public function updatePrice(Request $request, int $quizId): JsonResponse
    {
        abort_unless($request->user()?->isManager(), 403, 'Only managers can change paper pricing.');
        $validated = $request->validate([
            'price_paise' => ['required', 'integer', 'min:0', 'max:100000000'],
            'access_days' => ['nullable', 'integer', 'min:1', 'max:3650'],
        ]);

        if ($validated['price_paise'] > 0 && $validated['price_paise'] < 100) {
            throw \Illuminate\Validation\ValidationException::withMessages(['price_paise' => 'Set a price of at least ₹1, or 0 for free.']);
        }

        $quiz = Quiz::query()->findOrFail($quizId);
        $quiz->update($validated);

        return response()->json([
            'quiz_id' => $quiz->id,
            'price_paise' => (int) $quiz->price_paise,
            'access_days' => $quiz->access_days,
        ]);
    }

    private function grantPaidOrder(QuizStorefrontOrder $order, string $paymentId): void
    {
        abort_if($paymentId === '', 400, 'Payment ID is missing.');

        DB::transaction(function () use ($order, $paymentId) {
            // Both callback and webhook use the same lock order as free claims.
            User::query()->whereKey($order->user_id)->lockForUpdate()->firstOrFail();
            $lockedOrder = QuizStorefrontOrder::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            if ($lockedOrder->status === 'paid') {
                abort_unless($lockedOrder->razorpay_payment_id === $paymentId, 409, 'Order already has a different payment.');
                return;
            }

            $entitlement = QuizEntitlement::query()
                ->where('user_id', $lockedOrder->user_id)->where('quiz_id', $lockedOrder->quiz_id)->first();
            $startsAt = $entitlement?->expires_at?->isFuture() ? $entitlement->expires_at->copy() : now();
            // A second captured order extends a timed grant and never shortens lifetime access.
            $expiresAt = $lockedOrder->access_days && ! ($entitlement && $entitlement->expires_at === null)
                ? $startsAt->addDays((int) $lockedOrder->access_days)
                : null;

            $lockedOrder->update([
                'razorpay_payment_id' => $paymentId,
                'status' => 'paid',
                'paid_at' => now(),
            ]);
            QuizEntitlement::query()->updateOrCreate(
                ['user_id' => $lockedOrder->user_id, 'quiz_id' => $lockedOrder->quiz_id],
                ['order_id' => $lockedOrder->id, 'source' => 'purchase', 'expires_at' => $expiresAt]
            );
        }, 3);
    }

    private function publishedQuiz(int $quizId, bool $lock = false): Quiz
    {
        return Quiz::query()
            ->where('is_personal', false)
            ->where('is_active', true)
            ->where('approval_status', 'approved')
            ->whereHas('course', fn ($query) => $query->where('is_active', true))
            ->when($lock, fn ($query) => $query->lockForUpdate())
            ->findOrFail($quizId);
    }

    private function paperSummary(Quiz $quiz): array
    {
        return [
            'id' => $quiz->id,
            'title' => $quiz->title,
            'description' => $quiz->description,
            'section' => $quiz->section,
            'year' => $quiz->year,
            'time_limit_minutes' => $quiz->time_limit_minutes,
            'question_count' => $quiz->questions_count,
            'week' => $quiz->week ? [
                'number' => $quiz->week->week_number,
                'title' => $quiz->week->title,
            ] : null,
            'price_paise' => (int) $quiz->price_paise,
            'access_days' => $quiz->access_days,
            'course' => $quiz->course ? [
                'name' => $quiz->course->name,
                'slug' => $quiz->course->slug,
                'level' => $quiz->course->level,
                'icon' => $quiz->course->icon,
            ] : null,
        ];
    }

    private function requireRazorpayKeys(): void
    {
        abort_if(
            ! config('services.razorpay.key_id') || ! config('services.razorpay.key_secret'),
            503,
            'Razorpay checkout is not configured yet.'
        );
    }
}
