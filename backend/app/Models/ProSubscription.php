<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProSubscription extends Model
{
    protected $fillable = [
        'user_id', 'provider', 'provider_subscription_id', 'provider_reference_hash', 'google_purchase_token', 'product_id', 'status',
        'checkout_url', 'amount_paise', 'currency', 'started_at', 'paid_at', 'trial_ends_at',
        'current_period_ends_at', 'cancelled_at', 'cancel_at_period_end', 'cancellation_source',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'paid_at' => 'datetime',
            'trial_ends_at' => 'datetime',
            'current_period_ends_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'cancel_at_period_end' => 'boolean',
            'amount_paise' => 'integer',
            'google_purchase_token' => 'encrypted',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function billingDates(): array
    {
        $firstPayment = \Illuminate\Support\Facades\Schema::hasTable('membership_transactions')
            ? \Illuminate\Support\Facades\DB::table('membership_transactions')->where('pro_subscription_id', $this->id)
                ->where('amount_paise', '>', 0)->whereIn('status', ['paid', 'processed', 'charged'])->min('paid_at')
            : null;
        $renewing = in_array($this->provider, ['google_play', 'razorpay'], true) && in_array($this->status, ['active', 'trialing'], true) && ! $this->cancel_at_period_end;
        return [
            // No invented first-purchase date when an older receipt is unavailable.
            'first_payment_recorded_at' => $firstPayment ? $this->asDateTime($firstPayment) : null,
            'next_charge_at' => $renewing && $this->current_period_ends_at?->isFuture() ? $this->current_period_ends_at : null,
        ];
    }

    public function grantsAccess(): bool
    {
        if (in_array($this->status, ['trialing', 'active'], true)) {
            return ! $this->current_period_ends_at || $this->current_period_ends_at->isFuture();
        }

        // A provider-side cancellation prevents the next charge, but a member
        // keeps access through the already-paid period. Managers use `revoked`
        // to remove access immediately.
        return $this->status === 'cancelled'
            && $this->current_period_ends_at !== null
            && $this->current_period_ends_at->isFuture();
    }
}
