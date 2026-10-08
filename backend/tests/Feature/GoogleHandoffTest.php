<?php

namespace Tests\Feature;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as GoogleUser;
use Mockery;
use Tests\TestCase;

/** Google sign-in for the iPhone home-screen app: the login is handed back by a one-time id. */
class GoogleHandoffTest extends TestCase
{
    private const ID = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718';

    protected function setUp(): void
    {
        parent::setUp();
        if (! in_array('sqlite', \PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('pdo_sqlite is required.');
        }
        config([
            'database.default' => 'handoff_test',
            'database.connections.handoff_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => ''],
            'cache.default' => 'array',
            'services.google.client_id' => 'client-fixture',
            'services.google.client_secret' => 'secret-fixture',
            'services.google.redirect' => 'https://labapi.example/public/api/auth/google/callback',
        ]);
        DB::purge('handoff_test');
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

    private function fakeGoogle(): void
    {
        $google = (new GoogleUser())->map(['id' => 'g-123', 'name' => 'Raj Singh', 'email' => 'raj@example.com', 'avatar' => null]);
        $driver = Mockery::mock();
        $driver->shouldReceive('stateless')->andReturnSelf();
        $driver->shouldReceive('user')->andReturn($google);
        Socialite::shouldReceive('driver')->with('google')->andReturn($driver);
    }

    public function test_redirect_carries_the_handoff_id_as_state(): void
    {
        $response = $this->get('/public/api/auth/google?handoff='.self::ID);
        $response->assertRedirect();
        parse_str((string) parse_url($response->headers->get('Location'), PHP_URL_QUERY), $query);
        $this->assertSame('h.'.self::ID, $query['state'] ?? null);
    }

    public function test_redirect_ignores_a_malformed_handoff_id(): void
    {
        $response = $this->get('/public/api/auth/google?handoff=short');
        parse_str((string) parse_url($response->headers->get('Location'), PHP_URL_QUERY), $query);
        $this->assertArrayNotHasKey('state', $query);
    }

    public function test_callback_parks_the_login_and_the_app_collects_it_once(): void
    {
        $this->fakeGoogle();
        $callback = $this->get('/public/api/auth/google/callback?code=x&state=h.'.self::ID);
        $callback->assertOk();
        $this->assertStringContainsString('You are signed in', $callback->getContent());

        $first = $this->postJson('/public/api/auth/google/handoff', ['handoff' => self::ID]);
        $first->assertOk()->assertJsonPath('user.email', 'raj@example.com');
        $token = $first->json('token');
        $this->assertNotEmpty($token);
        $this->getJson('/public/api/auth/me', ['Authorization' => 'Bearer '.$token])->assertOk();

        $this->postJson('/public/api/auth/google/handoff', ['handoff' => self::ID])->assertNotFound();
    }

    public function test_unknown_or_malformed_ids_get_nothing(): void
    {
        $this->postJson('/public/api/auth/google/handoff', ['handoff' => str_repeat('z', 40)])->assertNotFound();
        $this->postJson('/public/api/auth/google/handoff', ['handoff' => 'bad id!'])->assertStatus(422);
    }

    public function test_normal_web_sign_in_is_unchanged(): void
    {
        config(['app.frontend_url' => null]);
        putenv('FRONTEND_URL=https://quiz.example');
        $this->fakeGoogle();
        $response = $this->get('/public/api/auth/google/callback?code=x');
        $response->assertRedirect();
        $this->assertStringStartsWith('https://quiz.example/auth/callback?token=', $response->headers->get('Location'));
        $this->assertNull(Cache::get('google_handoff:'.self::ID));
    }
}
