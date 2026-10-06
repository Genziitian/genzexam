<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProctoredExamEnrollment extends Model
{
    protected $table = 'proctored_exam_enrollments';

    protected $fillable = ['exam_id', 'email', 'user_id', 'added_by'];

    public function exam(): BelongsTo
    {
        return $this->belongsTo(ProctoredExam::class, 'exam_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
