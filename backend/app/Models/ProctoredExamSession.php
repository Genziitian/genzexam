<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProctoredExamSession extends Model
{
    protected $table = 'proctored_exam_sessions';

    protected $fillable = [
        'exam_id', 'user_id', 'status', 'warnings', 'warning_allowance', 'revision', 'answers', 'score',
        'total_marks', 'score_breakdown', 'joined_at', 'submitted_at',
    ];

    protected function casts(): array
    {
        return [
            'answers' => 'array',
            'score_breakdown' => 'array',
            'joined_at' => 'immutable_datetime',
            'submitted_at' => 'immutable_datetime',
            'warnings' => 'integer',
            'warning_allowance' => 'integer',
            'revision' => 'integer',
            'score' => 'float',
            'total_marks' => 'float',
        ];
    }

    public function exam(): BelongsTo
    {
        return $this->belongsTo(ProctoredExam::class, 'exam_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
