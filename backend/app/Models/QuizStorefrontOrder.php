<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuizStorefrontOrder extends Model
{
    protected $fillable = [
        'user_id',
        'quiz_id',
        'razorpay_order_id',
        'razorpay_payment_id',
        'amount_paise',
        'access_days',
        'currency',
        'status',
        'paid_at',
    ];

    protected function casts(): array
    {
        return ['paid_at' => 'datetime', 'amount_paise' => 'integer', 'access_days' => 'integer'];
    }

    public function quiz(): BelongsTo
    {
        return $this->belongsTo(Quiz::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
