<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Support\Facades\Schema;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    public const ROLE_STUDENT = 'student';
    public const ROLE_ADMIN   = 'admin';
    public const ROLE_MANAGER = 'manager';

    public const ROLES = [self::ROLE_STUDENT, self::ROLE_ADMIN, self::ROLE_MANAGER];

    /** Higher number wins. Used to stop a lower tier acting on a higher one. */
    public const ROLE_RANK = [
        self::ROLE_STUDENT => 0,
        self::ROLE_ADMIN   => 1,
        self::ROLE_MANAGER => 2,
    ];

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'google_id',
        'avatar',
        'is_admin',
        'is_pro',
        'is_active',
        'role',
        'email_verified_at',
        'otp',
        'otp_expires_at',
        'xp',
        'last_xp_action_date',
        'highest_level_reached',
        'last_seen_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'otp',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_admin' => 'boolean',
            'is_pro' => 'boolean',
            'is_active' => 'boolean',
            'email_verified_at' => 'datetime',
            'otp_expires_at' => 'datetime',
            'last_xp_action_date' => 'date',
            'last_seen_at' => 'datetime',
            'xp' => 'integer',
            'highest_level_reached' => 'integer',
            'password' => 'hashed',
        ];
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(Attempt::class);
    }

    public function proSubscriptions(): HasMany
    {
        return $this->hasMany(ProSubscription::class);
    }

    public function hasProAccess(): bool
    {
        // Keep legacy manager grants working until they are migrated into the
        // subscription ledger. During a rolling deployment, the API may receive
        // traffic before the ledger migration has run; preserve the old flag then.
        if (! Schema::hasTable('pro_subscriptions')) {
            return (bool) $this->is_pro;
        }

        // Once a ledger row exists, it is authoritative.
        if ($this->proSubscriptions()->exists()) {
            return $this->proSubscriptions()->where(function ($query) {
                $query->where(function ($active) {
                    $active->whereIn('status', ['trialing', 'active'])
                        ->where(fn ($period) => $period->whereNull('current_period_ends_at')->orWhere('current_period_ends_at', '>', now()));
                })->orWhere(function ($cancelled) {
                    // Provider cancellation stops renewal; access remains through
                    // the already-paid period. Immediate revocation uses `revoked`.
                    $cancelled->where('status', 'cancelled')
                        ->whereNotNull('current_period_ends_at')
                        ->where('current_period_ends_at', '>', now());
                });
            })->exists();
        }
        return (bool) $this->is_pro;
    }

    public function assignedCourses(): BelongsToMany
    {
        return $this->belongsToMany(Course::class)->withPivot('assigned_by')->withTimestamps();
    }

    public function ideSubmissions(): HasMany
    {
        return $this->hasMany(IDESubmission::class);
    }

    /**
     * The effective role. Falls back to the legacy is_admin flag when the role
     * column has not been migrated yet, so a pending migration can never lock
     * existing admins out of the panel.
     */
    public function effectiveRole(): string
    {
        if ($this->role !== null) {
            return $this->role;
        }

        return $this->is_admin ? self::ROLE_ADMIN : self::ROLE_STUDENT;
    }

    /** Managers have total control. */
    public function isManager(): bool
    {
        return $this->effectiveRole() === self::ROLE_MANAGER;
    }

    /** Admins have limited control; managers inherit everything admins can do. */
    public function isAdmin(): bool
    {
        return $this->effectiveRole() === self::ROLE_ADMIN;
    }

    public function hasAdminAccess(): bool
    {
        return $this->isAdmin() || $this->isManager();
    }

    public function isStudent(): bool
    {
        return ! $this->hasAdminAccess();
    }

    public function roleRank(): int
    {
        return self::ROLE_RANK[$this->effectiveRole()] ?? 0;
    }

    /**
     * May this user act on $target? A user can never act on their own account,
     * and may only act on accounts strictly below their own tier.
     */
    public function outranks(User $target): bool
    {
        if ($this->is($target)) {
            return false;
        }

        return $this->roleRank() > $target->roleRank();
    }

    protected static function booted(): void
    {
        // Keep the legacy is_admin flag in step with the role so older code
        // and existing clients keep working.
        static::saving(function (User $user) {
            if ($user->role === null) {
                $user->role = $user->is_admin ? self::ROLE_ADMIN : self::ROLE_STUDENT;
            }

            $user->is_admin = in_array($user->role, [self::ROLE_ADMIN, self::ROLE_MANAGER], true);
        });
    }
}
