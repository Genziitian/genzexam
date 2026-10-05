<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUserController extends Controller
{
    /**
     * Paginated, searchable list of users for the manager panel.
     */
    public function index(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('search', ''));
        $filter = (string) $request->query('filter', 'all');
        $perPage = min(max((int) $request->query('per_page', 25), 1), 100);

        $query = User::query()
            ->select(['id', 'name', 'email', 'avatar', 'is_admin', 'is_pro', 'is_active', 'xp', 'email_verified_at', 'last_seen_at', 'created_at']);

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        match ($filter) {
            'admins'    => $query->where('is_admin', true),
            'pro'       => $query->where('is_pro', true),
            'inactive'  => $query->where('is_active', false),
            'active'    => $query->where('is_active', true),
            default     => null,
        };

        $users = $query->orderByDesc('created_at')->paginate($perPage);

        return response()->json([
            'data' => collect($users->items())->map(fn (User $u) => $this->present($u))->values(),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page'    => $users->lastPage(),
                'per_page'     => $users->perPage(),
                'total'        => $users->total(),
            ],
            'counts' => [
                'total'    => User::count(),
                'admins'   => User::where('is_admin', true)->count(),
                'pro'      => User::where('is_pro', true)->count(),
                'inactive' => User::where('is_active', false)->count(),
            ],
        ]);
    }

    /**
     * Activate / deactivate an account. A deactivated user cannot sign in.
     */
    public function toggleActive(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);

        if ($guard = $this->guardSelf($request, $target, 'deactivate')) {
            return $guard;
        }

        $target->update(['is_active' => ! $target->is_active]);

        if (! $target->is_active) {
            $target->tokens()->delete();
        }

        return response()->json([
            'message' => $target->is_active
                ? "{$target->name}'s account was reactivated."
                : "{$target->name}'s account was deactivated and signed out.",
            'user' => $this->present($target),
        ]);
    }

    /**
     * Grant / revoke Pro membership.
     */
    public function togglePro(int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);
        $target->update(['is_pro' => ! $target->is_pro]);

        return response()->json([
            'message' => $target->is_pro
                ? "{$target->name} is now a Pro member."
                : "{$target->name}'s Pro access was removed.",
            'user' => $this->present($target),
        ]);
    }

    /**
     * Grant / revoke admin rights.
     */
    public function toggleAdmin(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);

        if ($guard = $this->guardSelf($request, $target, 'change the admin rights of')) {
            return $guard;
        }

        $target->update(['is_admin' => ! $target->is_admin]);

        if (! $target->is_admin) {
            $target->tokens()->delete();
        }

        return response()->json([
            'message' => $target->is_admin
                ? "{$target->name} has been granted admin access."
                : "{$target->name}'s admin access was revoked.",
            'user' => $this->present($target),
        ]);
    }

    /**
     * Permanently delete a user account.
     */
    public function destroy(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);

        if ($guard = $this->guardSelf($request, $target, 'delete')) {
            return $guard;
        }

        $name = $target->name;
        $target->tokens()->delete();
        $target->delete();

        return response()->json([
            'message' => "{$name}'s account was permanently deleted.",
            'user_id' => $userId,
        ]);
    }

    private function guardSelf(Request $request, User $target, string $action): ?JsonResponse
    {
        if ($target->is($request->user())) {
            return response()->json([
                'error' => "You cannot {$action} your own account.",
            ], 422);
        }

        return null;
    }

    private function present(User $u): array
    {
        return [
            'id'         => $u->id,
            'name'       => $u->name,
            'email'      => $u->email,
            'avatar'     => $u->avatar,
            'is_admin'   => (bool) $u->is_admin,
            'is_pro'     => (bool) $u->is_pro,
            'is_active'  => (bool) $u->is_active,
            'xp'         => (int) ($u->xp ?? 0),
            'verified'   => $u->email_verified_at !== null,
            'last_seen_at' => $u->last_seen_at,
            'created_at' => $u->created_at,
        ];
    }
}
