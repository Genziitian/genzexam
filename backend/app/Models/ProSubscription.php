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
