<?php
namespace App\Services;
use App\Models\MembershipTransaction;
use App\Models\ProSubscription;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Log;
use Throwable;
class MembershipTransactionRecorder {
    // Billing entitlement succeeds even while the optional history migration or Orders API is unavailable.
    public function google(ProSubscription $subscription, array $purchase): void {
        try {
            if (! Schema::hasTable('membership_transactions')) return;
            $line = collect($purchase['lineItems'] ?? [])->firstWhere('productId', $subscription->product_id);
            $reference = $line['latestSuccessfulOrderId'] ?? $purchase['latestOrderId'] ?? null;
            if (! is_string($reference) || $reference === '') return;
            $order = app(GooglePlaySubscriptions::class)->order($reference);
            // Verify order ownership and product again; never use catalog recurring prices as a receipt.
            if (($order['purchaseToken'] ?? '') !== $subscription->google_purchase_token
                || ! collect($order['lineItems'] ?? [])->contains(fn ($item) => ($item['productId'] ?? '') === $subscription->product_id)) return;
            $money = $order['total'] ?? null;
            if (! is_array($money) || empty($money['currencyCode'])) return;
            $currency = $money['currencyCode'];
            $digits = in_array($currency, ['JPY','KRW','VND','CLP','PYG','RWF','UGX','VUV','XAF','XOF','XPF','BIF','DJF','GNF','KMF'], true) ? 0 : (in_array($currency, ['BHD','IQD','JOD','KWD','LYD','OMR','TND'], true) ? 3 : 2);
            $amount = (int) round(((int) ($money['units'] ?? 0) + (int) ($money['nanos'] ?? 0) / 1000000000) * (10 ** $digits));
            $state = strtolower((string) ($order['state'] ?? 'unknown'));
            $this->save($subscription, $reference, $state, $amount, $currency, $order['createTime'] ?? null);
        } catch (Throwable $error) {
            Log::warning('Membership payment history could not synchronize.', ['subscription_id' => $subscription->id, 'provider' => 'google_play']);
        }
    }
    public function razorpay(ProSubscription $subscription, array $payment): void {
        if (($payment['status'] ?? '') !== 'captured' || empty($payment['id']) || ! isset($payment['amount'], $payment['currency'])) return;
        if (isset($payment['subscription_id']) && $payment['subscription_id'] !== $subscription->provider_subscription_id) return;
        // Caller has verified the webhook signature and subscription association.
        $this->save($subscription, $payment['id'], 'paid', (int) $payment['amount'], $payment['currency'], isset($payment['created_at']) ? now()->setTimestamp((int) $payment['created_at']) : now());
    }
    private function save(ProSubscription $subscription, string $reference, string $status, int $amount, string $currency, $paidAt): void {
        if (! Schema::hasTable('membership_transactions')) return;
        MembershipTransaction::query()->updateOrCreate(['provider' => $subscription->provider, 'reference' => $reference], [
            'user_id' => $subscription->user_id, 'pro_subscription_id' => $subscription->id,
            'status' => $status, 'amount_paise' => $amount, 'currency' => $currency, 'paid_at' => $paidAt,
        ]);
    }
}
