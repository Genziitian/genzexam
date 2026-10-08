<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AccountDeletionRequest extends Model
{
    protected $fillable = [
        'user_id', 'user_name', 'user_email', 'user_role', 'account_created_at',
        'reason', 'details', 'status',
    ];

    protected function casts(): array
    {
        return ['account_created_at' => 'datetime'];
    }
}
