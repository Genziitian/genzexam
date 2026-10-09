<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Schema;

class Quiz extends Model
{
    use HasFactory;

    protected static function booted(): void
    {
        // Personal student uploads are opt-in in the few owner-only API paths.
        // Everything else (course catalogs, manager tools, rankings, storefront)
        // excludes them by default.
        static::addGlobalScope('exclude_personal_uploads', function (Builder $query) {
            // Keep existing quiz pages usable during a rolling deployment where
            // the personal-upload migration has not reached the database yet.
            if (Schema::hasColumn('quizzes', 'is_personal')) {
                $query->where('is_personal', false);
            }
        });
    }

    public const SECTIONS = ['practice', 'practice_graded', 'quiz1', 'quiz2', 'endterm', 'mock_test'];
    public const WEEKLY_SECTIONS = ['practice', 'practice_graded'];

    protected $fillable = [
        'course_id',
        'week_id',
        'section',
        'year',
        'title',
        'description',
        'time_limit_minutes',
        'price_paise',
        'access_days',
        'is_active',
        'approval_status',
        'created_by',
        'reviewed_by',
        'reviewed_at',
        'is_personal',
        'owner_user_id',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'price_paise' => 'integer',
            'access_days' => 'integer',
            'is_personal' => 'boolean',
        ];
    }

    public function course(): BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    public function week(): BelongsTo
    {
        return $this->belongsTo(Week::class);
    }

    public function questions(): HasMany
    {
        return $this->hasMany(Question::class)->orderBy('position');
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(Attempt::class);
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }
}
