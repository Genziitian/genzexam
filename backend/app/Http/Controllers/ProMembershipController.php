<?php

namespace App\Http\Controllers;

use App\Models\ProSubscription;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Services\GooglePlaySubscriptions;
use App\Services\RazorpayProSubscriptions;
use Throwable;

class ProMembershipController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $subscription = $user->proSubscriptions()->latest('id')->first();
        if ($subscription?->provider === 'google_play' && $subscription->google_purchase_token) {
            try {
                $remote = app(GooglePlaySubscriptions::class)->get($subscription->google_purchase_token);
                $line = collect($remote['lineItems'] ?? [])->firstWhere('productId', $subscription->product_id);
                if ($line) {
                    $expiry = isset($line['expiryTime']) ? now()->parse($line['expiryTime']) : null;
                    $state = (string) ($remote['subscriptionState'] ?? '');
                    $isTrial = $subscription->trial_ends_at && $subscription->trial_ends_at->isFuture() && $state === 'SUBSCRIPTION_STATE_ACTIVE';
                    $hasEntitlement = $expiry?->isFuture() && in_array($state, ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED'], true);
                    $subscription->update([
                        'status' => $hasEntitlement ? ($isTrial ? 'trialing' : 'active') : ($state === 'SUBSCRIPTION_STATE_EXPIRED' ? 'expired' : 'cancelled'),
                        'current_period_ends_at' => $expiry,
                        'cancel_at_period_end' => $state === 'SUBSCRIPTION_STATE_CANCELED' || data_get($line, 'autoRenewingPlan.autoRenewEnabled') === false,
                    ]);
                    if (! $hasEntitlement) $user->update(['is_pro' => false]);
                    $subscription->refresh();
                }
            } catch (Throwable $error) {
                // If Play is temporarily unreachable, show the last server-verified state.
            }
        }
        $plan = DB::table('pro_plan_settings')->first();
        $trialAvailable = ! $user->proSubscriptions()->whereNotNull('trial_ends_at')->exists();
        return response()->json([
            'is_pro' => $user->hasProAccess(),
            'plan' => ['price_paise' => (int) ($plan->price_paise ?? 9900), 'trial_days' => (int) ($plan->trial_days ?? 7), 'enabled' => (bool) ($plan->enabled ?? true)],
            'trial_available' => $trialAvailable,
            'google_play_trial_offer_id' => config('services.google_play.trial_offer_id'),
            'subscription' => $subscription ? $this->subscriptionData($subscription) : ((bool) $user->is_pro ? ['id' => 'legacy', 'provider' => 'manual', 'status' => 'active', 'started_at' => null, 'trial_ends_at' => null, 'current_period_ends_at' => null, 'cancel_at_period_end' => false] : null),
            'payment_setup' => [
                'web' => (bool) (config('services.razorpay.key_id') && config('services.razorpay.key_secret')),
                'google_play' => (bool) (config('services.google_play.package_name') && config('services.google_play.subscription_product_id') && config('services.google_play.trial_offer_id') && config('services.google_play.service_account_json')),
            ],
        ]);
    }

    public function cancel(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user->is_pro && ! $user->proSubscriptions()->exists()) {
            $user->update(['is_pro' => false]);
            return response()->json(['message' => 'Your manually granted Pro access has been removed.']);
        }
        $subscription = $user->proSubscriptions()->whereIn('status', ['trialing', 'active'])->latest('id')->firstOrFail();

        // Store-backed recurring billing must be cancelled with the billing provider.
        // The app's store management page is the safe destination when provider credentials
        // are not installed; never claim a store renewal was stopped by changing local state.
        if ($subscription->provider === 'google_play') {
            try {
                app(GooglePlaySubscriptions::class)->cancel((string) $subscription->google_purchase_token, 'user');
                $subscription->update(['cancel_at_period_end' => true, 'cancelled_at' => now(), 'cancellation_source' => 'user']);
                return response()->json(['message' => 'Renewal cancelled. Pro access remains available until the current billing period ends.', 'subscription' => $this->subscriptionData($subscription->fresh())]);
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
        }
        if ($subscription->provider === 'razorpay') {
            try {
                app(RazorpayProSubscriptions::class)->cancel((string) $subscription->provider_subscription_id);
                $subscription->update(['cancel_at_period_end' => true, 'cancelled_at' => now(), 'cancellation_source' => 'user']);
                return response()->json(['message' => 'Renewal cancelled. Pro access remains through the current trial or paid period.', 'subscription' => $this->subscriptionData($subscription->fresh())]);
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
        }

        $subscription->update([
            'status' => 'cancelled', 'cancelled_at' => now(), 'cancel_at_period_end' => false,
            'cancellation_source' => 'user',
        ]);
        $user->update(['is_pro' => false]);

        return response()->json(['message' => 'Your Pro membership has been cancelled.', 'subscription' => $this->subscriptionData($subscription->fresh())]);
    }

    public function startRazorpay(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_if($user->hasProAccess(), 409, 'Your account already has Pro access.');
        $settings = DB::table('pro_plan_settings')->where('id', 1)->first();
        abort_if(! $settings || ! $settings->enabled, 403, 'Pro membership is not available right now.');
        try {
            $service = app(RazorpayProSubscriptions::class);
            $planId = $settings->razorpay_plan_id ?: $service->createPlan((int) $settings->price_paise);
            if (! $settings->razorpay_plan_id) DB::table('pro_plan_settings')->where('id', 1)->update(['razorpay_plan_id' => $planId, 'updated_at' => now()]);
            $trialDays = $user->proSubscriptions()->whereNotNull('trial_ends_at')->exists() ? 0 : (int) $settings->trial_days;
            $remote = $service->createSubscription($planId, $trialDays, (int) $user->id, (string) $user->email);
        } catch (Throwable $error) {
            return response()->json(['error' => $error->getMessage()], 503);
        }
        $trialEnd = $trialDays > 0 ? now()->addDays($trialDays) : null;
        $sub = ProSubscription::query()->create([
            'user_id' => $user->id,
            'provider' => 'razorpay',
            'provider_subscription_id' => $remote['id'],
            'product_id' => 'quiz-lab-pro-monthly',
            'checkout_url' => $remote['short_url'],
            'status' => 'pending',
            'amount_paise' => (int) $settings->price_paise,
            'currency' => 'INR',
            'started_at' => now(),
            'trial_ends_at' => $trialEnd,
            'current_period_ends_at' => $trialEnd,
        ]);
        return response()->json(['subscription' => $this->subscriptionData($sub), 'checkout_url' => $remote['short_url'], 'trial_days' => $trialDays, 'amount_paise' => (int) $settings->price_paise]);
    }

    public function razorpayWebhook(Request $request): JsonResponse
    {
        $raw = $request->getContent();
        $signature = (string) $request->header('X-Razorpay-Signature');
        abort_unless(app(RazorpayProSubscriptions::class)->verifyWebhook($raw, $signature), 400, 'Invalid webhook signature.');
        $event = (string) $request->input('event');
        $entity = $request->input('payload.subscription.entity', []);
        $providerId = (string) ($entity['id'] ?? '');
        if ($providerId === '') return response()->json(['ok' => true]);
        $subscription = ProSubscription::query()->where('provider', 'razorpay')->where('provider_subscription_id', $providerId)->first();
        if (! $subscription) return response()->json(['ok' => true]);
        $periodEnd = ! empty($entity['current_end']) ? now()->setTimestamp((int) $entity['current_end']) : $subscription->current_period_ends_at;
        if (in_array($event, ['subscription.activated', 'subscription.charged'], true)) {
            $trial = $subscription->trial_ends_at && $subscription->trial_ends_at->isFuture() && (int) ($entity['paid_count'] ?? 0) === 0;
            $subscription->update(['status' => $trial ? 'trialing' : 'active', 'current_period_ends_at' => $periodEnd, 'paid_at' => $event === 'subscription.charged' ? now() : $subscription->paid_at, 'checkout_url' => null]);
            $subscription->user?->update(['is_pro' => true]);
        } elseif ($event === 'subscription.cancelled') {
            $subscription->update(['status' => 'cancelled', 'cancel_at_period_end' => false, 'current_period_ends_at' => $periodEnd, 'checkout_url' => null]);
            if (! $periodEnd || $periodEnd->isPast()) $subscription->user?->update(['is_pro' => false]);
        } elseif (in_array($event, ['subscription.halted', 'subscription.completed'], true)) {
            $subscription->update(['status' => $event === 'subscription.completed' ? 'expired' : 'cancelled', 'current_period_ends_at' => $periodEnd, 'checkout_url' => null]);
            if (! $periodEnd || $periodEnd->isPast()) $subscription->user?->update(['is_pro' => false]);
        }
        return response()->json(['ok' => true]);
    }

    public function verifyGooglePlay(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'purchase_token' => ['required', 'string', 'min:20', 'max:4096'],
            'product_id' => ['required', 'string', 'max:200'],
        ]);
        $configuredProduct = (string) config('services.google_play.subscription_product_id');
        abort_if($configuredProduct === '' || ! hash_equals($configuredProduct, $validated['product_id']), 422, 'This is not the configured Pro subscription product.');

        try {
            $purchase = app(GooglePlaySubscriptions::class)->get($validated['purchase_token']);
        } catch (Throwable $error) {
            return response()->json(['error' => $error->getMessage()], 503);
        }
        $line = collect($purchase['lineItems'] ?? [])->firstWhere('productId', $configuredProduct);
        abort_unless($line, 422, 'Google Play did not return the expected Pro product.');
        $state = (string) ($purchase['subscriptionState'] ?? '');
        $expiry = isset($line['expiryTime']) ? now()->parse($line['expiryTime']) : null;
        abort_unless(in_array($state, ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED'], true) && $expiry?->isFuture(), 422, 'This Google Play subscription is not currently entitled.');

        $hash = hash('sha256', $validated['purchase_token']);
        $existing = ProSubscription::query()->where('provider_reference_hash', $hash)->first();
        abort_if($existing && (int) $existing->user_id !== (int) $request->user()->id, 409, 'This purchase is already linked to another account.');
        $offerId = data_get($line, 'offerDetails.offerId');
        $isTrial = (string) config('services.google_play.trial_offer_id') !== '' && $offerId === config('services.google_play.trial_offer_id');
        if ($isTrial && $request->user()->proSubscriptions()->whereNotNull('trial_ends_at')->where(function ($query) use ($hash) {
            $query->whereNull('provider_reference_hash')->orWhere('provider_reference_hash', '!=', $hash);
        })->exists()) {
            return response()->json(['error' => 'This Quiz LAB account has already used its free trial. Please choose the regular paid plan in Google Play.'], 422);
        }
        if (($purchase['acknowledgementState'] ?? '') === 'ACKNOWLEDGEMENT_STATE_PENDING') {
            try {
                app(GooglePlaySubscriptions::class)->acknowledge($validated['purchase_token'], $configuredProduct);
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
        }
        $sub = ProSubscription::query()->updateOrCreate(['provider_reference_hash' => $hash], [
            'user_id' => $request->user()->id,
            'provider' => 'google_play',
            'provider_subscription_id' => $hash,
            'google_purchase_token' => $validated['purchase_token'],
            'product_id' => $configuredProduct,
            'status' => $isTrial ? 'trialing' : 'active',
            'amount_paise' => (int) (DB::table('pro_plan_settings')->value('price_paise') ?? 9900),
            'currency' => 'INR',
            'started_at' => isset($purchase['startTime']) ? now()->parse($purchase['startTime']) : now(),
            'trial_ends_at' => $isTrial ? $expiry : null,
            'paid_at' => $isTrial ? null : ($existing?->paid_at ?? now()),
            'current_period_ends_at' => $expiry,
            'cancel_at_period_end' => data_get($line, 'autoRenewingPlan.autoRenewEnabled') === false || $state === 'SUBSCRIPTION_STATE_CANCELED',
        ]);
        $request->user()->update(['is_pro' => true]);
        return response()->json(['message' => 'Purchase verified with Google Play.', 'subscription' => $this->subscriptionData($sub)]);
    }

    public function managerPlan(Request $request): JsonResponse
    {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $plan = DB::table('pro_plan_settings')->first();
        $playPriceManaged = (bool) (config('services.google_play.package_name') && config('services.google_play.subscription_product_id') && config('services.google_play.subscription_base_plan_id') && config('services.google_play.regions_version') && config('services.google_play.service_account_json'));
        return response()->json(['price_paise' => (int) ($plan->price_paise ?? 9900), 'trial_days' => (int) ($plan->trial_days ?? 7), 'enabled' => (bool) ($plan->enabled ?? true), 'google_play_price_paise' => $plan->google_play_price_paise ?? null, 'google_play_price_managed' => $playPriceManaged, 'google_play_price_note' => $playPriceManaged ? 'Saving the price also updates the configured Google Play base plan price for new India subscribers.' : 'Connect Google Play price-management credentials and a base plan ID to control the Android price here.']);
    }

    public function updatePlan(Request $request): JsonResponse
    {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $data = $request->validate([
            'price_paise' => ['required', 'integer', 'min:100', 'max:1000000'],
            'trial_days' => ['required', 'integer', 'min:0', 'max:30'],
            'enabled' => ['required', 'boolean'],
        ]);
        $playPriceManaged = (bool) (config('services.google_play.package_name') && config('services.google_play.subscription_product_id') && config('services.google_play.subscription_base_plan_id') && config('services.google_play.regions_version') && config('services.google_play.service_account_json'));
        $planId = null;
        if (config('services.razorpay.key_id') && config('services.razorpay.key_secret')) {
            try { $planId = app(RazorpayProSubscriptions::class)->createPlan((int) $data['price_paise']); }
            catch (Throwable $error) { return response()->json(['error' => $error->getMessage()], 503); }
        } else {
            $planId = DB::table('pro_plan_settings')->where('id', 1)->value('razorpay_plan_id');
        }
        if ($playPriceManaged) {
            try { app(GooglePlaySubscriptions::class)->updateIndiaBasePlanPrice((int) $data['price_paise']); }
            catch (Throwable $error) { return response()->json(['error' => $error->getMessage()], 503); }
        }
        DB::table('pro_plan_settings')->updateOrInsert(['id' => 1], [...$data, 'google_play_price_paise' => $playPriceManaged ? (int) $data['price_paise'] : DB::table('pro_plan_settings')->where('id', 1)->value('google_play_price_paise'), 'razorpay_plan_id' => $planId, 'updated_at' => now(), 'created_at' => now()]);
        return $this->managerPlan($request);
    }

    public function managerSubscriptions(Request $request): JsonResponse
    {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $query = ProSubscription::query()->with('user:id,name,email')->latest('id');
        if ($request->filled('status') && $request->input('status') !== 'all') $query->where('status', $request->input('status'));
        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->whereHas('user', fn ($users) => $users->where('name', 'like', '%'.$search.'%')->orWhere('email', 'like', '%'.$search.'%'));
        }
        $page = $query->paginate(50);
        $rows = $page->getCollection()->map(fn (ProSubscription $subscription) => $this->subscriptionData($subscription, true));
        $legacyCount = 0;
        if ($page->currentPage() === 1 && (! $request->filled('status') || $request->input('status') === 'all' || $request->input('status') === 'active')) {
            $legacyQuery = User::query()->where('is_pro', true)->whereDoesntHave('proSubscriptions');
            if ($request->filled('search')) {
                $search = trim((string) $request->input('search'));
                $legacyQuery->where(fn ($users) => $users->where('name', 'like', '%'.$search.'%')->orWhere('email', 'like', '%'.$search.'%'));
            }
            $legacyCount = $legacyQuery->count();
            $legacy = $legacyQuery->get(['id', 'name', 'email', 'created_at']);
            foreach ($legacy as $user) {
                $rows->push(['id' => 'legacy-'.$user->id, 'user' => ['id' => $user->id, 'name' => $user->name, 'email' => $user->email], 'provider' => 'manual legacy flag', 'product_id' => null, 'status' => 'active', 'amount_paise' => 0, 'currency' => 'INR', 'started_at' => null, 'trial_ends_at' => null, 'current_period_ends_at' => null, 'cancelled_at' => null, 'cancel_at_period_end' => false, 'created_at' => $user->created_at]);
            }
        }
        $page->setCollection($rows);
        $pagination = $page->toArray();
        $pagination['data'] = $rows->values()->all();
        if ($legacyCount > 0) {
            $pagination['total'] += $legacyCount;
            $pagination['last_page'] = max(1, (int) ceil($pagination['total'] / $page->perPage()));
        }
        return response()->json([
            ...$pagination,
            'summary' => [
                'active' => ProSubscription::query()->where('status', 'active')->count() + User::query()->where('is_pro', true)->whereDoesntHave('proSubscriptions')->count(),
                'trialing' => ProSubscription::query()->where('status', 'trialing')->count(),
                'cancelled' => ProSubscription::query()->where('status', 'cancelled')->count(),
                'revoked' => ProSubscription::query()->where('status', 'revoked')->count(),
                'expired' => ProSubscription::query()->where('status', 'expired')->count(),
                'pending' => ProSubscription::query()->where('status', 'pending')->count(),
            ],
        ]);
    }

    public function managerGrant(Request $request): JsonResponse
    {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'days' => ['required', 'integer', 'min:1', 'max:3650'],
        ]);
        $user = User::query()->where('email', $data['email'])->firstOrFail();
        abort_if($user->hasProAccess(), 409, 'This account already has Pro access.');
        $subscription = ProSubscription::query()->create([
            'user_id' => $user->id,
            'provider' => 'manual',
            'product_id' => 'manager-grant',
            'status' => 'active',
            'amount_paise' => 0,
            'currency' => 'INR',
            'started_at' => now(),
            'current_period_ends_at' => now()->addDays((int) $data['days']),
        ]);
        $user->update(['is_pro' => true]);
        return response()->json(['message' => 'Pro access granted for '.$data['days'].' days.', 'subscription' => $this->subscriptionData($subscription->load('user'), true)], 201);
    }

    public function managerCancel(Request $request, string $id): JsonResponse
    {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $action = $request->validate(['action' => ['required', 'in:cancel_renewal,revoke_access']])['action'];
        if (str_starts_with($id, 'legacy-')) {
            $userId = (int) substr($id, 7);
            $user = User::query()->findOrFail($userId);
            if ($action === 'cancel_renewal') return response()->json(['message' => 'Legacy Pro has no recurring billing record. Choose Revoke access to remove it.'], 422);
            $user->update(['is_pro' => false]);
            return response()->json(['message' => 'Legacy Pro access revoked.']);
        }
        $subscription = ProSubscription::query()->with('user')->findOrFail($id);
        abort_unless(in_array($subscription->status, ['pending', 'trialing', 'active'], true), 409, 'This membership is not active.');
        abort_if($subscription->provider === 'manual' && $action === 'cancel_renewal', 422, 'Complimentary Pro has no renewal. Choose Revoke access instead.');

        if ($action === 'revoke_access') {
            try {
                if ($subscription->provider === 'google_play' && $subscription->google_purchase_token) {
                    app(GooglePlaySubscriptions::class)->revoke((string) $subscription->google_purchase_token, 'prorated');
                } elseif ($subscription->provider === 'razorpay' && $subscription->provider_subscription_id) {
                    app(RazorpayProSubscriptions::class)->cancel((string) $subscription->provider_subscription_id, false);
                }
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
            DB::transaction(function () use ($subscription) {
                $subscription->update(['status' => 'revoked', 'cancelled_at' => now(), 'cancel_at_period_end' => false, 'cancellation_source' => 'manager', 'checkout_url' => null]);
                $subscription->user?->update(['is_pro' => false]);
            });
            return response()->json(['message' => $subscription->provider === 'google_play' ? 'Pro access revoked. Google Play was asked to issue a prorated refund.' : 'Pro access revoked immediately. No automatic refund was issued.', 'subscription' => $this->subscriptionData($subscription->fresh('user'), true)]);
        }

        if ($subscription->provider === 'google_play') {
            try {
                app(GooglePlaySubscriptions::class)->cancel((string) $subscription->google_purchase_token, 'manager');
                $subscription->update(['cancel_at_period_end' => true, 'cancelled_at' => now(), 'cancellation_source' => 'manager']);
                return response()->json(['message' => 'Google Play renewal cancelled; access remains through the current paid or trial period.', 'subscription' => $this->subscriptionData($subscription->fresh('user'), true)]);
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
        }
        if ($subscription->provider === 'razorpay') {
            try {
                app(RazorpayProSubscriptions::class)->cancel((string) $subscription->provider_subscription_id, $subscription->status !== 'pending');
                if ($subscription->status === 'pending') {
                    $subscription->update(['status' => 'cancelled', 'cancel_at_period_end' => false, 'cancelled_at' => now(), 'cancellation_source' => 'manager', 'checkout_url' => null]);
                } else {
                    $subscription->update(['cancel_at_period_end' => true, 'cancelled_at' => now(), 'cancellation_source' => 'manager']);
                }
                return response()->json(['message' => 'Razorpay renewal cancelled; access remains through the current trial or paid period.', 'subscription' => $this->subscriptionData($subscription->fresh('user'), true)]);
            } catch (Throwable $error) {
                return response()->json(['error' => $error->getMessage()], 503);
            }
        }

        // Manager-granted Pro has no external recurring payment to stop.
        DB::transaction(function () use ($subscription) {
            $subscription->update(['status' => 'revoked', 'cancelled_at' => now(), 'cancel_at_period_end' => false, 'cancellation_source' => 'manager']);
            $subscription->user?->update(['is_pro' => false]);
        });

        return response()->json(['message' => 'Pro access revoked.', 'subscription' => $this->subscriptionData($subscription->fresh('user'), true)]);
    }

    private function subscriptionData(ProSubscription $subscription, bool $includeUser = false): array
    {
        return [
            'id' => $subscription->id,
            'user' => $includeUser && $subscription->user ? ['id' => $subscription->user->id, 'name' => $subscription->user->name, 'email' => $subscription->user->email] : null,
            'provider' => $subscription->provider,
            'product_id' => $subscription->product_id,
            'status' => $subscription->status,
            'amount_paise' => $subscription->amount_paise,
            'currency' => $subscription->currency,
            'started_at' => $subscription->started_at,
            'paid_at' => $subscription->paid_at,
            'trial_ends_at' => $subscription->trial_ends_at,
            'current_period_ends_at' => $subscription->current_period_ends_at,
            'cancelled_at' => $subscription->cancelled_at,
            'cancel_at_period_end' => $subscription->cancel_at_period_end,
            'cancellation_source' => $subscription->cancellation_source,
            'provider_subscription_id' => $includeUser ? $subscription->provider_subscription_id : null,
            'checkout_url' => $includeUser ? $subscription->checkout_url : null,
            'created_at' => $subscription->created_at,
        ];
    }
}
