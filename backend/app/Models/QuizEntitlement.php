<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuizEntitlement extends Model
{
    protected $fillable = ['user_id', 'quiz_id', 'order_id', 'source', 'expires_at'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function quiz(): BelongsTo
    {
        return $this->belongsTo(Quiz::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(QuizStorefrontOrder::class, 'order_id');
    }
}
