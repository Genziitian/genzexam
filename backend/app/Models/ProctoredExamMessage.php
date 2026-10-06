<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProctoredExamMessage extends Model
{
    protected $table = 'proctored_exam_messages';

    protected $fillable = ['exam_id', 'sender_id', 'text', 'is_announcement'];

    protected function casts(): array
    {
        return ['is_announcement' => 'boolean'];
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }
}
