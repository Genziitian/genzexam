<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Every failed sign-in is written to login_failures with a reason managers can read. */
class LoginFailureLogTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        if (! in_array('sqlite', \PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('pdo_sqlite is required.');
        }
        config([
            'database.default' => 'lf_test',
            'database.connections.lf_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => ''],
            'cache.default' => 'array',
        ]);
        DB::purge('lf_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email'); $table->string('password')->nullable();
            $table->timestamp('email_verified_at')->nullable(); $table->string('google_id')->nullable();
            $table->string('avatar')->nullable(); $table->boolean('is_active')->default(true);
            $table->boolean('is_admin')->default(false); $table->string('role')->default('student');
            $table->string('otp')->nullable(); $table->timestamp('otp_expires_at')->nullable();
            $table->timestamp('last_seen_at')->nullable(); $table->timestamps();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id(); $table->morphs('tokenable'); $table->string('name'); $table->string('token', 64)->unique();
            $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
        Schema::create('login_logs', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('user_id'); $table->string('ip_address')->nullable();
            $table->string('user_agent')->nullable(); $table->string('auth_method')->nullable();
            $table->timestamp('logged_in_at')->nullable(); $table->timestamps();
        });
        (require database_path('migrations/2026_11_09_000001_create_login_failures_table.php'))->up();
    }

    private function user(array $attrs = []): User
    {
        return User::forceCreate(array_merge([
            'name' => 'Asha', 'email' => 'asha@example.com', 'password' => bcrypt('right-pass'),
            'email_verified_at' => now(), 'is_active' => true, 'role' => 'student',
        ], $attrs));
    }

    private function login(string $email, string $password)
    {
        return $this->postJson('/public/api/auth/login', ['email' => $email, 'password' => $password]);
    }

    public function test_each_password_failure_is_logged_with_its_reason(): void
    {
        $this->user();
        $this->user(['email' => 'google@example.com', 'password' => null, 'google_id' => 'g1']);
        $this->user(['email' => 'new@example.com', 'email_verified_at' => null]);
        $this->user(['email' => 'off@example.com', 'is_active' => false]);

        $this->login('asha@example.com', 'wrong')->assertStatus(401);
        $this->login('google@example.com', 'anything')->assertStatus(401);
        $this->login('new@example.com', 'right-pass')->assertStatus(403);
        $this->login('off@example.com', 'right-pass')->assertStatus(403);
        $this->login('nobody@example.com', 'x')->assertStatus(401);
        $this->login('not-an-email', 'x')->assertStatus(422);
        $this->login('asha@example.com', 'right-pass')->assertOk();

        $this->assertSame(
            ['wrong_password', 'google_only_account', 'not_verified', 'deactivated', 'no_account', 'validation'],
            DB::table('login_failures')->orderBy('id')->pluck('reason')->all()
        );
        $this->assertSame('google@example.com', DB::table('login_failures')->where('reason', 'google_only_account')->value('email'));
    }

    public function test_wrong_and_expired_otp_are_logged(): void
    {
        $u = $this->user(['email' => 'otp@example.com', 'email_verified_at' => null, 'otp' => bcrypt('123456'), 'otp_expires_at' => now()->addMinutes(5)]);
        $this->postJson('/public/api/auth/verify-otp', ['email' => 'otp@example.com', 'otp' => '000000'])->assertStatus(422);
        $u->forceFill(['otp_expires_at' => now()->subMinute()])->save();
        $this->postJson('/public/api/auth/verify-otp', ['email' => 'otp@example.com', 'otp' => '123456'])->assertStatus(422);

        $this->assertSame(['otp_wrong', 'otp_expired'], DB::table('login_failures')->orderBy('id')->pluck('reason')->all());
    }

    public function test_rate_limited_logins_are_logged_and_routes_do_not_share_one_counter(): void
    {
        $this->user();
        for ($i = 0; $i < 30; $i++) {
            $this->login('asha@example.com', 'wrong');
        }
        $this->login('asha@example.com', 'wrong')->assertStatus(429);
        $this->assertSame(1, DB::table('login_failures')->where('reason', 'rate_limited')->count());

        // Another auth route from the same IP is not blocked by the login counter.
        $this->postJson('/public/api/auth/verify-otp', ['email' => 'asha@example.com', 'otp' => '000000'])->assertStatus(422);
    }

    public function test_browser_reports_are_stored_and_only_managers_can_read_them(): void
    {
        $this->postJson('/public/api/auth/login-failure', [
            'email' => 'asha@example.com', 'method' => 'email', 'reason' => 'network_error',
            'message' => 'No response from the server', 'detail' => 'status=0', 'page' => '/login',
        ])->assertStatus(202);
        $this->postJson('/public/api/auth/login-failure', ['reason' => 'made_up'])->assertStatus(202);

        $row = DB::table('login_failures')->orderBy('id')->first();
        $this->assertSame(['network_error', 'browser', '/login'], [$row->reason, $row->source, $row->page]);
        $this->assertSame('other', DB::table('login_failures')->orderByDesc('id')->value('reason'));

        Sanctum::actingAs($this->user(['email' => 'stud@example.com']));
        $this->getJson('/public/api/manager/login-failures')->assertStatus(403);

        Sanctum::actingAs($this->user(['email' => 'boss@example.com', 'role' => 'manager']));
        $res = $this->getJson('/public/api/manager/login-failures?days=7')->assertOk();
        $this->assertSame(2, $res->json('total'));
        $this->assertSame(1, $res->json('by_reason.network_error'));
        $this->assertSame('network_error', $res->json('failures.1.reason'));
        $this->assertSame(1, count($this->getJson('/public/api/manager/login-failures?reason=network_error')->json('failures')));
    }
}
