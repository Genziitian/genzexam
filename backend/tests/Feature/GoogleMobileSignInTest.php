<?php

namespace Tests\Feature;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/** Native Google sign-in for the mobile app: the app posts Google's ID token and gets a session. */
class GoogleMobileSignInTest extends TestCase
{
    private const TOKEN = 'aaaa.bbbb.cccc';

    protected function setUp(): void
    {
        parent::setUp();
        if (! in_array('sqlite', \PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('pdo_sqlite is required.');
        }
        config([
            'database.default' => 'gmobile_test',
            'database.connections.gmobile_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => ''],
            'cache.default' => 'array',
            'services.google.client_id' => 'client-fixture',
        ]);
        DB::purge('gmobile_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email'); $table->string('password')->nullable();
            $table->timestamp('email_verified_at')->nullable(); $table->string('google_id')->nullable();
            $table->string('avatar')->nullable(); $table->boolean('is_active')->default(true);
            $table->boolean('is_admin')->default(false); $table->string('role')->default('student');
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
    }

    private function fakeGoogle(array $overrides = [], int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response(array_merge([
            'iss' => 'https://accounts.google.com',
            'aud' => 'client-fixture',
            'sub' => 'g-123',
            'email' => 'Raj@Example.com',
            'email_verified' => 'true',
            'name' => 'Raj Singh',
            'picture' => 'https://example.com/a.png',
            'exp' => (string) (time() + 600),
        ], $overrides), $status)]);
    }

    public function test_valid_token_creates_the_user_and_returns_a_session(): void
    {
        $this->fakeGoogle();

        $res = $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN]);

        $res->assertOk()->assertJsonPath('user.email', 'raj@example.com')->assertJsonPath('user.name', 'Raj Singh');
        $this->assertNotEmpty($res->json('token'));
        $this->assertSame(1, DB::table('users')->where('google_id', 'g-123')->count());
        $this->assertSame('google', DB::table('login_logs')->value('auth_method'));
    }

    public function test_existing_email_account_is_linked_not_duplicated(): void
    {
        DB::table('users')->insert(['name' => 'Raj', 'email' => 'raj@example.com', 'is_active' => 1, 'role' => 'manager']);
        $this->fakeGoogle();

        $res = $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN]);

        $res->assertOk()->assertJsonPath('user.role', 'manager');
        $this->assertSame(1, DB::table('users')->count());
        $this->assertSame('g-123', DB::table('users')->value('google_id'));
    }

    public function test_token_issued_for_another_app_is_rejected(): void
    {
        $this->fakeGoogle(['aud' => 'someone-elses-client']);

        $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN])->assertStatus(401);
        $this->assertSame(0, DB::table('users')->count());
    }

    public function test_expired_unverified_or_invalid_tokens_are_rejected(): void
    {
        $this->fakeGoogle(['exp' => (string) (time() - 10)]);
        $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN])->assertStatus(401);

        Http::swap(new \Illuminate\Http\Client\Factory());
        $this->fakeGoogle(['email_verified' => 'false']);
        $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN])->assertStatus(401);

        Http::swap(new \Illuminate\Http\Client\Factory());
        $this->fakeGoogle(['error_description' => 'Invalid Value'], 400);
        $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN])->assertStatus(401);

        $this->assertSame(0, DB::table('users')->count());
    }

    public function test_malformed_token_is_refused_without_calling_google(): void
    {
        Http::fake();

        $this->postJson('/api/auth/google/mobile', ['id_token' => 'not-a-token'])->assertStatus(422);
        $this->postJson('/api/auth/google/mobile', [])->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_deactivated_account_cannot_sign_in(): void
    {
        DB::table('users')->insert(['name' => 'Raj', 'email' => 'raj@example.com', 'is_active' => 0, 'google_id' => 'g-123']);
        $this->fakeGoogle();

        $this->postJson('/api/auth/google/mobile', ['id_token' => self::TOKEN])->assertStatus(403);
        $this->assertSame(0, DB::table('personal_access_tokens')->count());
    }
}
