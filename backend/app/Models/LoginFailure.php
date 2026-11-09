<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Log;
use Throwable;

class LoginFailure extends Model
{
    public $timestamps = false;

    protected $fillable = ['email', 'user_id', 'method', 'reason', 'message', 'detail', 'source', 'ip_address', 'user_agent', 'page', 'created_at'];

    protected $casts = ['created_at' => 'datetime'];

    /** Never lets logging break a sign-in: any database problem is only written to the Laravel log. */
    public static function record(string $method, string $reason, ?string $email = null, ?User $user = null, ?string $message = null, ?string $detail = null, string $source = 'server', ?string $page = null): void
    {
        try {
            $request = request();
            static::create([
                'email' => $email !== null ? mb_substr(mb_strtolower(trim($email)), 0, 191) : ($user?->email),
                'user_id' => $user?->id,
                'method' => mb_substr($method, 0, 20),
                'reason' => mb_substr($reason, 0, 40),
                'message' => $message !== null ? mb_substr($message, 0, 500) : null,
                'detail' => $detail !== null ? mb_substr($detail, 0, 4000) : null,
                'source' => $source,
                'ip_address' => $request?->ip(),
                'user_agent' => mb_substr((string) $request?->userAgent(), 0, 300),
                'page' => $page !== null ? mb_substr($page, 0, 300) : null,
                'created_at' => now(),
            ]);
        } catch (Throwable $e) {
            Log::warning('Could not record login failure', ['reason' => $reason, 'email' => $email, 'error' => $e->getMessage()]);
        }
    }
}
