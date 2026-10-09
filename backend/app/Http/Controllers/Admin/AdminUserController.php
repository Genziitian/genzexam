<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\ProSubscription;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

/**
 * Manager-only user management and teacher course assignments.
 * Admin teacher accounts do not have access to user records or these endpoints.
 */
class AdminUserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('search', ''));
        $filter = (string) $request->query('filter', 'all');
        $perPage = min(max((int) $request->query('per_page', 25), 1), 100);

        // Only select columns that exist, so a pending migration on the server
        // cannot turn this page into a 500 "Server Error".
        $wanted = [
            'id', 'name', 'email', 'avatar', 'role', 'is_admin', 'is_pro',
            'is_active', 'xp', 'email_verified_at', 'last_seen_at', 'created_at',
        ];
        $existing = Schema::getColumnListing('users');
        $query = User::query()->select(array_values(array_intersect($wanted, $existing)));
        $hasRole = in_array('role', $existing, true);

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        match ($filter) {
            'managers' => $query->where('role', User::ROLE_MANAGER),
            'admins'   => $query->where('role', User::ROLE_ADMIN),
            'students' => $query->where('role', User::ROLE_STUDENT),
            'pro'      => $query->where('is_pro', true),
            'inactive' => $query->where('is_active', false),
            'active'   => $query->where('is_active', true),
            default    => null,
        };

        if ($hasRole) {
            $query->orderByRaw("FIELD(role, 'manager', 'admin', 'student')");
        }

        $users = $query->orderByDesc('created_at')
            ->paginate($perPage);

        $actor = $request->user();

        return response()->json([
            'data' => collect($users->items())->map(fn (User $u) => $this->present($u, $actor))->values(),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page'    => $users->lastPage(),
                'per_page'     => $users->perPage(),
                'total'        => $users->total(),
            ],
            'counts' => [
                'total'    => User::count(),
                'managers' => User::where('role', User::ROLE_MANAGER)->count(),
                'admins'   => User::where('role', User::ROLE_ADMIN)->count(),
                'students' => User::where('role', User::ROLE_STUDENT)->count(),
                'pro'      => User::where('is_pro', true)->count(),
                'inactive' => User::where('is_active', false)->count(),
            ],
            'viewer' => [
                'id'          => $actor->id,
                'role'        => $actor->role,
                'is_manager'  => $actor->isManager(),
                'can_manage_roles'  => $actor->isManager(),
                'can_delete_users'  => $actor->isManager(),
            ],
        ]);
    }

    /** Activate or deactivate a user. Manager only. */
    public function toggleActive(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);

        if ($denied = $this->denyUnlessOutranks($request, $target, 'deactivate')) {
            return $denied;
        }

        $target->update(['is_active' => ! $target->is_active]);

        if (! $target->is_active) {
            $target->tokens()->delete();
        }

        return response()->json([
            'message' => $target->is_active
                ? "{$target->name}'s account was reactivated."
                : "{$target->name}'s account was deactivated and signed out.",
            'user' => $this->present($target, $request->user()),
        ]);
    }

    /** Grant or remove Pro. Manager only. */
    public function togglePro(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);

        if ($denied = $this->denyUnlessOutranks($request, $target, 'change Pro access for')) {
            return $denied;
        }

        $grant = ! $target->is_pro;
        $target->update(['is_pro' => $grant]);
        if ($grant) {
            ProSubscription::query()->create([
                'user_id' => $target->id,
                'provider' => 'manual',
                'status' => 'active',
                'amount_paise' => 0,
                'currency' => 'INR',
                'started_at' => now(),
            ]);
        } else {
            $target->proSubscriptions()->whereIn('status', ['active', 'trialing'])->update([
                'status' => 'revoked', 'cancelled_at' => now(), 'cancellation_source' => 'manager',
            ]);
        }

        return response()->json([
            'message' => $target->is_pro
                ? "{$target->name} is now a Pro member."
                : "{$target->name}'s Pro access was removed.",
            'user' => $this->present($target, $request->user()),
        ]);
    }

    /** Set a user's role. Manager only. */
    public function setRole(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['required', Rule::in(User::ROLES)],
        ]);

        $target = User::findOrFail($userId);
        $actor = $request->user();

        if ($target->is($actor)) {
            return response()->json(['error' => 'You cannot change your own role.'], 422);
        }

        // Never leave the platform without a manager.
        if ($target->isManager() && $validated['role'] !== User::ROLE_MANAGER
            && User::where('role', User::ROLE_MANAGER)->count() <= 1) {
            return response()->json([
                'error' => 'This is the only manager account. Promote another manager first.',
            ], 422);
        }

        $previous = $target->role;
        $target->update(['role' => $validated['role']]);
        if ($validated['role'] !== User::ROLE_ADMIN) {
            $target->assignedCourses()->detach();
        }

        // Losing privileges takes effect immediately.
        if (User::ROLE_RANK[$validated['role']] < User::ROLE_RANK[$previous]) {
            $target->tokens()->delete();
        }

        return response()->json([
            'message' => "{$target->name} is now a " . ucfirst($validated['role']) . '.',
            'user' => $this->present($target->fresh(), $actor),
        ]);
    }

    /** Assign the courses an admin teacher is allowed to manage. Manager only. */
    public function assignCourses(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'course_ids' => ['present', 'array'],
            'course_ids.*' => ['integer', 'distinct', 'exists:courses,id'],
        ]);

        $target = User::findOrFail($userId);
        if ($target->is($request->user())) {
            return response()->json(['error' => 'You cannot assign courses to your own account.'], 422);
        }
        if ($target->role !== User::ROLE_ADMIN) {
            return response()->json(['error' => 'Course assignments are for admin teacher accounts.'], 422);
        }

        $sync = [];
        foreach ($validated['course_ids'] as $courseId) {
            $sync[$courseId] = ['assigned_by' => $request->user()->id];
        }
        $target->assignedCourses()->sync($sync);

        return response()->json([
            'message' => "Course access updated for {$target->name}.",
            'course_ids' => $target->assignedCourses()->pluck('courses.id')->map(fn ($id) => (int) $id),
        ]);
    }

    /** Permanently delete an account. Manager only. */
    public function destroy(Request $request, int $userId): JsonResponse
    {
        $target = User::findOrFail($userId);
        $actor = $request->user();

        if ($target->is($actor)) {
            return response()->json(['error' => 'You cannot delete your own account.'], 422);
        }

        if ($target->isManager() && User::where('role', User::ROLE_MANAGER)->count() <= 1) {
            return response()->json([
                'error' => 'This is the only manager account and cannot be deleted.',
            ], 422);
        }

        $name = $target->name;
        if (Schema::hasTable('proctored_exams') && (
            \App\Models\ProctoredExam::query()->where('owner_id', $target->id)->exists()
            || \App\Models\ProctoredExamSession::query()->where('user_id', $target->id)->exists()
        )) {
            return response()->json(['error' => 'This account has exam records. Deactivate it to preserve assessment results and the audit history.'], 409);
        }
        if (\App\Models\QuizStorefrontOrder::query()->where('user_id', $target->id)->exists()) {
            return response()->json(['error' => 'This account has checkout records. Deactivate the account to retain its purchase history.'], 409);
        }
        $target->tokens()->delete();
        $target->delete();

        return response()->json([
            'message' => "{$name}'s account was permanently deleted.",
            'user_id' => $userId,
        ]);
    }

    private function denyUnlessOutranks(Request $request, User $target, string $action): ?JsonResponse
    {
        $actor = $request->user();

        if ($target->is($actor)) {
            return response()->json(['error' => "You cannot {$action} your own account."], 422);
        }

        if (! $actor->outranks($target)) {
            return response()->json([
                'error' => "You do not have permission to {$action} a " . ucfirst($target->role) . ' account.',
            ], 403);
        }

        return null;
    }

    private ?bool $assignmentsTableExists = null;

    private function hasAssignmentsTable(): bool
    {
        return $this->assignmentsTableExists ??= Schema::hasTable('course_user');
    }

    private function present(User $u, User $actor): array
    {
        $canManage = $actor->outranks($u);

        return [
            'id'           => $u->id,
            'name'         => $u->name,
            'email'        => $u->email,
            'avatar'       => $u->avatar,
            'role'         => $u->role,
            'is_admin'     => (bool) $u->is_admin,
            'is_pro'       => (bool) $u->is_pro,
            'is_active'    => (bool) $u->is_active,
            'xp'           => (int) ($u->xp ?? 0),
            'verified'     => $u->email_verified_at !== null,
            'last_seen_at' => $u->last_seen_at,
            'created_at'   => $u->created_at,
            'assigned_course_ids' => ($u->role === User::ROLE_ADMIN && $this->hasAssignmentsTable())
                ? $u->assignedCourses()->pluck('courses.id')->map(fn ($id) => (int) $id)->values()
                : [],
            'can' => [
                'toggle_active' => $canManage,
                'toggle_pro'    => $canManage,
                'set_role'      => $actor->isManager() && ! $actor->is($u),
                'delete'        => $actor->isManager() && ! $actor->is($u),
            ],
        ];
    }
}
