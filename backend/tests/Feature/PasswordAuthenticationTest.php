<?php

namespace Tests\Feature;

use App\Mail\OtpMail;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class PasswordAuthenticationTest extends TestCase
{
    public function test_current_quiz_lab_web_origin_is_allowed_by_cors(): void
    {
        $this->assertContains('https://quiz.genziitian.in', config('cors.allowed_origins'));
    }

    protected function setUp(): void
    {
        parent::setUp();
        if (! in_array('sqlite', \PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('pdo_sqlite is required.');
        }

        config([
            'database.default' => 'password_auth_test',
            'database.connections.password_auth_test' => [
                'driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '',
                'foreign_key_constraints' => true,
            ],
            'cache.default' => 'array',
        ]);
        DB::purge('password_auth_test');

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password')->nullable();
            $table->string('google_id')->nullable();
            $table->string('avatar')->nullable();
            $table->boolean('is_admin')->default(false);
            $table->boolean('is_active')->default(true);
            $table->string('role')->default('student');
            $table->timestamp('email_verified_at')->nullable();
            $table->string('otp')->nullable();
            $table->timestamp('otp_expires_at')->nullable();
            $table->unsignedInteger('xp')->default(0);
            $table->date('last_xp_action_date')->nullable();
            $table->unsignedInteger('highest_level_reached')->default(1);
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();
        });

        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->morphs('tokenable');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });

        Schema::create('login_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('ip_address', 45)->nullable();
            $table->string('user_agent', 300)->nullable();
            $table->string('auth_method', 16)->default('email');
            $table->timestamp('logged_in_at')->useCurrent();
        });
    }

    public function test_registration_hashes_password_and_requires_email_verification(): void
    {
        Mail::fake();

        $response = $this->postJson('/public/api/auth/register', [
            'name' => 'Test Student',
            'email' => 'student@example.test',
            'password' => 'correct horse battery staple',
            'password_confirmation' => 'correct horse battery staple',
        ]);

        $response->assertCreated();
        $storedPassword = DB::table('users')->where('email', 'student@example.test')->value('password');
        $this->assertNotSame('correct horse battery staple', $storedPassword);
        $this->assertTrue(Hash::check('correct horse battery staple', $storedPassword));
        $this->assertSame(1, DB::table('users')->whereNull('email_verified_at')->count());
        Mail::assertSent(OtpMail::class);
    }

    public function test_verified_user_can_sign_in_with_email_and_password(): void
    {
        DB::table('users')->insert([
            'name' => 'Test Student',
            'email' => 'student@example.test',
            'password' => Hash::make('correct horse battery staple'),
            'email_verified_at' => now(),
            'role' => 'student',
            'is_active' => true,
        ]);

        $response = $this->postJson('/public/api/auth/login', [
            'email' => 'student@example.test',
            'password' => 'correct horse battery staple',
        ]);

        $response->assertOk()->assertJsonPath('user.email', 'student@example.test');
        $this->assertNotEmpty($response->json('token'));
        $this->assertSame('email', DB::table('login_logs')->value('auth_method'));
    }

    public function test_wrong_password_is_rejected_and_unverified_user_cannot_sign_in(): void
    {
        DB::table('users')->insert([
            'name' => 'Test Student',
            'email' => 'student@example.test',
            'password' => Hash::make('correct horse battery staple'),
            'email_verified_at' => now(),
            'role' => 'student',
            'is_active' => true,
        ]);

        $this->postJson('/public/api/auth/login', [
            'email' => 'student@example.test', 'password' => 'wrong password',
        ])->assertUnauthorized();

        DB::table('users')->insert([
            'name' => 'Pending Student',
            'email' => 'pending@example.test',
            'password' => Hash::make('correct horse battery staple'),
            'role' => 'student',
            'is_active' => true,
        ]);

        $this->postJson('/public/api/auth/login', [
            'email' => 'pending@example.test', 'password' => 'correct horse battery staple',
        ])->assertForbidden()->assertJsonPath('needs_verification', true);
    }

    public function test_personal_access_tokens_expire_after_the_configured_lifetime(): void
    {
        config(['sanctum.expiration' => 1]);
        DB::table('users')->insert([
            'name' => 'Test Student',
            'email' => 'student@example.test',
            'password' => Hash::make('correct horse battery staple'),
            'email_verified_at' => now(),
            'role' => 'student',
            'is_active' => true,
        ]);

        $login = $this->postJson('/public/api/auth/login', [
            'email' => 'student@example.test',
            'password' => 'correct horse battery staple',
        ])->assertOk();

        $token = $login->json('token');
        $this->travel(2)->minutes();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/public/api/auth/me')
            ->assertUnauthorized();
    }
}
