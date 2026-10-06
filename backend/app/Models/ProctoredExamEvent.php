<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProctoredExamEvent extends Model
{
    protected $table = 'proctored_exam_events';

    protected $fillable = ['exam_id', 'user_id', 'client_event_id', 'type', 'occurred_at'];

    protected function casts(): array
    {
        return ['occurred_at' => 'immutable_datetime'];
    }
}
