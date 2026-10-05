<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Course extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'level',
        'description',
        'icon',
        'has_ide',
        'is_active',
        'sort_order',
    ];

    public function weeks(): HasMany
    {
        return $this->hasMany(Week::class);
    }

    public function quizzes(): HasMany
    {
        return $this->hasMany(Quiz::class);
    }

    public function ideProblems(): HasMany
    {
        return $this->hasMany(IDEProblem::class);
    }

    public function assignedUsers(): BelongsToMany
    {
        return $this->belongsToMany(User::class)->withPivot('assigned_by')->withTimestamps();
    }
}
