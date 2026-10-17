<?php

namespace App\Services;

use App\Models\ProSubscription;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class GooglePlayMembershipSync
{
    public function __construct(private GooglePlaySubscriptions $play) {}

    public function refresh(ProSubscription $subscription): ProSubscription
    {
        return DB::transaction(function () use ($subscription) {
            // Serialize Google reads and access updates for this account, so
            // overlapping and out-of-order messages cannot restore stale state.
            $user = User::query()->lockForUpdate()->findOrFail($subscription->user_id);
            $subscription = ProSubscription::query()->lockForUpdate()->findOrFail($subscription->id);
            if ($subscription->provider !== 'google_play' || ! $subscription->google_purchase_token) {
                throw new RuntimeException('Not a Google Play subscription.');
            }
            $purchase = $this->play->get($subscription->google_purchase_token);
            $data = $this->snapshot($purchase, $subscription);
            if (in_array($data['status'], ['active', 'trialing', 'cancelled'], true)
                && ($purchase['acknowledgementState'] ?? '') === 'ACKNOWLEDGEMENT_STATE_PENDING') {
                $this->play->acknowledge($subscription->google_purchase_token, $subscription->product_id);
            }
            $subscription->update($data);
            app(MembershipTransactionRecorder::class)->google($subscription, $purchase);
            // A separate active Play, web or complimentary grant must survive.
            $user->update(['is_pro' => $user->hasProAccess()]);

            return $subscription->fresh();
        }, 3);
    }

    public function isFreeTrial(array $line, ?ProSubscription $subscription = null): bool
    {
        if (array_key_exists('offerPhase', $line)) {
            return is_array($line['offerPhase']) && array_key_exists('freeTrial', $line['offerPhase']);
        }
        // Older API responses may omit offerPhase. An offer ID persists after
        // a trial ends, so it is never sufficient by itself to restart a trial.
        return $subscription?->trial_ends_at?->isFuture() ?? false;
    }

    public function snapshot(array $purchase, ProSubscription $subscription): array
    {
        $line = collect($purchase['lineItems'] ?? [])->firstWhere('productId', $subscription->product_id);
        if (! is_array($line) || empty($line['expiryTime'])) {
            throw new RuntimeException('Google Play returned no matching subscription period.');
        }
        $expiry = Carbon::parse($line['expiryTime']);
        $state = $purchase['subscriptionState'] ?? '';
        $status = match ($state) {
            'SUBSCRIPTION_STATE_ACTIVE' => $this->isFreeTrial($line, $subscription) ? 'trialing' : 'active',
            'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' => 'active',
            'SUBSCRIPTION_STATE_CANCELED' => 'cancelled',
            'SUBSCRIPTION_STATE_ON_HOLD' => 'on_hold',
            'SUBSCRIPTION_STATE_PAUSED' => 'paused',
            'SUBSCRIPTION_STATE_PENDING' => 'pending',
            'SUBSCRIPTION_STATE_EXPIRED', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED' => 'expired',
            default => throw new RuntimeException('Unknown Google Play subscription state.'),
        };
        if (! $expiry->isFuture() && in_array($status, ['active', 'trialing', 'cancelled'], true)) {
            $status = 'expired';
        }
        $cancelled = $state === 'SUBSCRIPTION_STATE_CANCELED'
            || data_get($line, 'autoRenewingPlan.autoRenewEnabled') === false;
        $data = [
            'status' => $status,
            'current_period_ends_at' => $expiry,
            'cancel_at_period_end' => $cancelled,
            'cancelled_at' => $cancelled ? ($subscription->cancelled_at ?? now()) : null,
            'cancellation_source' => $cancelled ? ($subscription->cancellation_source ?? 'provider') : null,
        ];
        $money = data_get($line, 'autoRenewingPlan.recurringPrice');
        if (is_array($money) && isset($money['currencyCode'])) {
            $currency = $money['currencyCode'];
            $digits = in_array($currency, ['JPY', 'KRW', 'VND', 'CLP', 'PYG', 'RWF', 'UGX', 'VUV', 'XAF', 'XOF', 'XPF', 'BIF', 'DJF', 'GNF', 'KMF'], true) ? 0
                : (in_array($currency, ['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'], true) ? 3 : 2);
            $data['currency'] = $currency;
            $data['amount_paise'] = (int) round(((int) ($money['units'] ?? 0) + (int) ($money['nanos'] ?? 0) / 1000000000) * (10 ** $digits));
        }
        if ($status === 'trialing' && ! $subscription->trial_ends_at) $data['trial_ends_at'] = $expiry;
        if ($status === 'active' && ! $subscription->paid_at) $data['paid_at'] = now();

        return $data;
    }
}
