<?php

namespace Tests\Feature;

use App\Models\ProSubscription;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Routing\RouteCollection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Tests\TestCase;

class DailyRewardsTest extends TestCase
{
    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'database.default' => 'rewards_test',
            'database.connections.rewards_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'cache.default' => 'array',
        ]);
        DB::purge('rewards_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email');
            $table->string('role')->default('student'); $table->boolean('is_admin')->default(false);
            $table->boolean('is_pro')->default(false); $table->unsignedInteger('xp')->default(0);
            $table->timestamp('last_seen_at')->nullable(); $table->timestamps();
        });
        (require database_path('migrations/2026_10_09_000002_create_pro_subscriptions_and_plan_settings.php'))->up();
        $this->student = User::create(['name' => 'Student', 'email' => 'rewards@example.test']);
        $this->actingAs($this->student, 'sanctum');
        $this->withoutMiddleware(ThrottleRequests::class);
        $this->travelTo(now()->startOfSecond());
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        DB::purge('rewards_test');
        parent::tearDown();
    }

    private function reward(array $attributes = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(), 'type' => 'free_pro', 'title' => '30 Days Free Pro',
            'is_claimed' => false, 'is_scratched' => false, 'expires_at' => null,
        ], $attributes);
    }

    public function test_rewards_route_returns_the_account_quota_and_rewards(): void
    {
        $this->getJson('/public/api/student/rewards')->assertOk()
            ->assertJsonPath('quota.remaining', 1)->assertJsonPath('rewards', []);
    }

    public function test_recovery_routes_restore_missing_endpoints_without_duplicates_or_open_access(): void
    {
        $original = Route::getRoutes();
        try {
            Route::setRoutes(new RouteCollection());
            $file = base_path('../docs/hostinger-recovery/rewards-routes.php');
            Route::prefix('public/api')->group($file);
            $this->assertCount(5, Route::getRoutes());
            Route::prefix('public/api')->group($file);
            $this->assertCount(5, Route::getRoutes());
            foreach (Route::getRoutes() as $route) {
                $this->assertContains('auth:sanctum', $route->gatherMiddleware());
                if (str_contains($route->uri(), 'manager/')) {
                    $this->assertContains('is_manager', $route->gatherMiddleware());
                }
            }
        } finally {
            Route::setRoutes($original);
        }
    }

    public function test_a_user_cannot_claim_an_unknown_or_another_users_pro_reward(): void
    {
        $reward = $this->reward();
        $other = User::create(['name' => 'Other', 'email' => 'other-rewards@example.test']);
        Cache::put('user_rewards_list_'.$other->id, [$reward], 3600);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $reward['id']])->assertNotFound();
        $this->assertSame(0, ProSubscription::count());
        $this->assertFalse($this->student->fresh()->is_pro);
    }

    public function test_claiming_a_pro_reward_grants_thirty_days_once_and_only_marks_that_reward(): void
    {
        $reward = $this->reward();
        $untouched = $this->reward();
        Cache::put('user_rewards_list_'.$this->student->id, [$reward, $untouched], 3600);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $reward['id']])->assertOk();
        $subscription = ProSubscription::sole();
        $this->assertSame('reward-'.$reward['id'], $subscription->provider_subscription_id);
        $this->assertTrue($subscription->current_period_ends_at->equalTo(now()->addDays(30)));
        $this->assertTrue($this->student->fresh()->hasProAccess());
        $rewards = Cache::get('user_rewards_list_'.$this->student->id);
        $this->assertTrue($rewards[0]['is_claimed']);
        $this->assertFalse($rewards[1]['is_claimed']);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $reward['id']])->assertStatus(409);
        $this->assertSame(1, ProSubscription::count());
        // A stale cache cannot grant the same award twice after a partial failure.
        Cache::put('user_rewards_list_'.$this->student->id, [$reward], 3600);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $reward['id']])->assertStatus(409);
        $this->assertSame(1, ProSubscription::count());
    }

    public function test_expired_and_non_pro_rewards_cannot_grant_membership(): void
    {
        $expired = $this->reward(['expires_at' => now()->subMinute()->toIso8601String()]);
        $coupon = $this->reward(['type' => 'coupon_flat']);
        Cache::put('user_rewards_list_'.$this->student->id, [$expired, $coupon], 3600);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $expired['id']])->assertStatus(410);
        $this->postJson('/public/api/student/rewards/claim-pro', ['id' => $coupon['id']])->assertNotFound();
        $this->postJson('/public/api/student/rewards/claim-pro', [])->assertUnprocessable();
        $this->assertSame(0, ProSubscription::count());
    }

    public function test_scratch_only_updates_an_owned_reward(): void
    {
        $reward = $this->reward();
        Cache::put('user_rewards_list_'.$this->student->id, [$reward], 3600);
        $this->postJson('/public/api/student/rewards/scratch', ['id' => (string) Str::uuid()])->assertNotFound();
        $this->postJson('/public/api/student/rewards/scratch', ['id' => $reward['id']])->assertOk();
        $this->assertTrue(Cache::get('user_rewards_list_'.$this->student->id)[0]['is_scratched']);
    }

    public function test_used_daily_spin_and_simultaneous_reward_requests_are_rejected(): void
    {
        Cache::put('user_daily_reward_spin_'.$this->student->id.'_'.now('Asia/Kolkata')->format('Y-m-d'), 1, 3600);
        $this->postJson('/public/api/student/rewards/spin')->assertStatus(429);
        $lock = Cache::lock('user_rewards_lock_'.$this->student->id, 30);
        $this->assertTrue($lock->get());
        try {
            $this->postJson('/public/api/student/rewards/spin')->assertStatus(409);
        } finally {
            $lock->release();
        }
    }
}
