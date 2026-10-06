<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProctoredExam extends Model
{
    use HasUuids;

    protected $table = 'proctored_exams';

    protected $fillable = [
        'owner_id', 'title', 'subject', 'instructions', 'duration_minutes', 'extension_minutes', 'max_warnings',
        'scheduled_at', 'closes_at', 'status', 'results_published', 'questions', 'started_at',
        'paused_at', 'paused_seconds', 'ended_at',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'immutable_datetime',
            'closes_at' => 'immutable_datetime',
            'started_at' => 'immutable_datetime',
            'paused_at' => 'immutable_datetime',
            'ended_at' => 'immutable_datetime',
            'results_published' => 'boolean',
            'questions' => 'array',
            'paused_seconds' => 'integer',
            'duration_minutes' => 'integer',
            'extension_minutes' => 'integer',
            'max_warnings' => 'integer',
        ];
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function enrollments(): HasMany
    {
        return $this->hasMany(ProctoredExamEnrollment::class, 'exam_id');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(ProctoredExamSession::class, 'exam_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(ProctoredExamMessage::class, 'exam_id');
    }

    public function auditLogs(): HasMany
    {
        return $this->hasMany(ProctoredExamAuditLog::class, 'exam_id');
    }
}
