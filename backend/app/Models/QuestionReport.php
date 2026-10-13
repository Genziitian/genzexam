<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuestionReport extends Model
{
    protected $fillable = [
        'question_id', 'quiz_id', 'user_id', 'question_number', 'reasons', 'comment',
        'status', 'manager_note', 'resolved_by', 'resolved_at',
    ];

    protected function casts(): array
    {
        return ['reasons' => 'array', 'resolved_at' => 'datetime'];
    }

    public function question(): BelongsTo { return $this->belongsTo(Question::class); }
    public function quiz(): BelongsTo { return $this->belongsTo(Quiz::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function resolver(): BelongsTo { return $this->belongsTo(User::class, 'resolved_by'); }
}
