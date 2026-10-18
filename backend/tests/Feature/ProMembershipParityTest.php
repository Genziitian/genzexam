<?php

namespace Tests\Feature;

use App\Models\ProSubscription;
use App\Models\User;
use App\Services\QuestionImporter;
use App\Services\RazorpayProSubscriptions;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\UploadedFile;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Mockery;
use Tests\TestCase;

class ProMembershipParityTest extends TestCase
{
    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'database.default' => 'parity_test',
            'database.connections.parity_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'cache.default' => 'array',
            'services.student_paper_uploads.limit' => 5,
            'services.student_paper_uploads.free_limit' => 1,
            'services.student_paper_uploads.window_days' => 7,
            'services.google_play.subscription_base_plan_id' => 'monthly',
        ]);
        DB::purge('parity_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email');
            $table->string('role')->default('student'); $table->boolean('is_admin')->default(false);
            $table->boolean('is_pro')->default(false); $table->timestamp('last_seen_at')->nullable(); $table->timestamps();
        });
        (require database_path('migrations/2026_10_09_000002_create_pro_subscriptions_and_plan_settings.php'))->up();
        Schema::create('courses', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('slug');
            $table->boolean('is_active')->default(true); $table->integer('sort_order')->default(0);
        });
        Schema::create('quizzes', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('course_id'); $table->unsignedBigInteger('week_id')->nullable();
            $table->string('section'); $table->string('title'); $table->text('description')->nullable();
            $table->integer('time_limit_minutes')->nullable(); $table->integer('price_paise')->default(0);
            $table->boolean('is_active')->default(true); $table->string('approval_status')->default('approved');
            $table->unsignedBigInteger('created_by')->nullable(); $table->unsignedBigInteger('reviewed_by')->nullable();
            $table->timestamp('reviewed_at')->nullable(); $table->boolean('is_personal')->default(false);
            $table->unsignedBigInteger('owner_user_id')->nullable(); $table->timestamps();
        });
        Schema::create('questions', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('quiz_id'); $table->softDeletes();
        });
        DB::table('courses')->insert(['id' => 1, 'name' => 'Course', 'slug' => 'course']);
        $this->travelTo(now()->startOfSecond());
        $this->student = User::query()->create(['name' => 'Student', 'email' => 'parity@example.test', 'is_pro' => true]);
        $this->actingAs($this->student, 'sanctum');
        $this->withoutMiddleware(ThrottleRequests::class);
        Http::preventStrayRequests();
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        DB::purge('parity_test');
        parent::tearDown();
    }

    private function grant(string $provider, string $status, int $days = 1): ProSubscription
    {
        return ProSubscription::query()->create([
            'user_id' => $this->student->id, 'provider' => $provider, 'status' => $status,
            'product_id' => 'quiz_lab_pro_monthly', 'provider_subscription_id' => 'fixture-'.$provider,
            'current_period_ends_at' => now()->addDays($days),
        ]);
    }

    public function test_student_cannot_manage_another_students_subscription(): void
    {
        $owner = User::query()->create(['name'=>'Other','email'=>'other@example.test','is_pro'=>false]);
        $sub = $this->grant('razorpay', 'active');
        $sub->update(['user_id'=>$owner->id]);
        $this->postJson('/public/api/membership/manage', ['subscription_id'=>$sub->id,'action'=>'cancel'])->assertNotFound();
        $this->assertFalse($sub->fresh()->cancel_at_period_end);
    }

    public function test_failed_provider_cancellation_preserves_access_and_renewal_state(): void
    {
        $sub = $this->grant('razorpay', 'active');
        $this->mock(\App\Services\RazorpayProSubscriptions::class, function ($mock) {
            $mock->shouldReceive('cancel')->once()->with('fixture-razorpay')->andThrow(new \RuntimeException('Provider unavailable.'));
        });
        $this->postJson('/public/api/membership/manage', ['subscription_id'=>$sub->id,'action'=>'cancel'])->assertStatus(503);
        $this->assertFalse($sub->fresh()->cancel_at_period_end);
        $this->assertTrue($this->student->fresh()->hasProAccess());
    }

    public function test_confirmed_cancellation_keeps_access_and_removes_next_charge(): void
    {
        $sub = $this->grant('razorpay', 'active');
        $this->assertNotNull($sub->billingDates()['next_charge_at']);
        $this->mock(\App\Services\RazorpayProSubscriptions::class, function ($mock) {
            $mock->shouldReceive('cancel')->once()->with('fixture-razorpay')->andReturn(['status'=>'active']);
        });
        $this->postJson('/public/api/membership/manage', ['subscription_id'=>$sub->id,'action'=>'cancel'])->assertOk();
        $this->assertTrue($sub->fresh()->cancel_at_period_end);
        $this->assertNull($sub->fresh()->billingDates()['next_charge_at']);
        $this->assertTrue($this->student->fresh()->hasProAccess());
        $this->postJson('/public/api/membership/manage', ['subscription_id'=>$sub->id,'action'=>'pause'])->assertUnprocessable();
        $this->postJson('/public/api/membership/manage', ['subscription_id'=>$sub->id,'action'=>'resume'])->assertUnprocessable();
    }

    public function test_paid_play_billing_does_not_require_a_trial_offer(): void
    {
        config([
            'services.google_play.package_name' => 'in.genziitian.quizlab',
            'services.google_play.subscription_product_id' => 'quiz_lab_pro_monthly',
            'services.google_play.service_account_json' => '/private/billing.json',
            'services.google_play.trial_offer_id' => null,
        ]);
        $this->getJson('/public/api/membership')->assertOk()
            ->assertJsonPath('payment_setup.google_play', true);
        config(['services.google_play.service_account_json' => null]);
        $this->getJson('/public/api/membership')->assertOk()
            ->assertJsonPath('payment_setup.google_play', false);
    }

    public function test_web_and_app_share_membership_and_trial_rules_for_both_payment_providers(): void
    {
        foreach (['google_play', 'razorpay'] as $provider) {
            $subscription = $this->grant($provider, 'active');
            foreach (['active' => true, 'trialing' => true, 'cancelled' => true, 'expired' => false,
                'paused' => false, 'on_hold' => false, 'pending' => false, 'revoked' => false] as $status => $access) {
                $subscription->update(['status' => $status]);
                foreach (['web', 'mobile'] as $client) {
                    $result = $this->getJson('/public/api/membership', ['X-QuizLab-Client' => $client]);
                    $result->assertOk()->assertJsonPath('is_pro', $access)
                        ->assertJsonPath('google_play_base_plan_id', 'monthly');
                }
                $this->assertSame($access, $subscription->fresh()->grantsAccess());
                $this->assertSame($access, (new \App\Models\VideoSolution(['is_pro' => true]))->isAccessibleBy($this->student->fresh()));
            }
            $subscription->update(['status' => 'active', 'trial_ends_at' => now()->subDay(), 'current_period_ends_at' => now()->subSecond()]);
            foreach (['web', 'mobile'] as $client) {
                $this->getJson('/public/api/membership', ['X-QuizLab-Client' => $client])
                    ->assertOk()->assertJsonPath('is_pro', false)->assertJsonPath('trial_available', false);
            }
            $subscription->delete();
        }
    }

    public function test_a_separate_active_grant_is_valid_for_both_clients(): void
    {
        $this->grant('google_play', 'expired');
        $this->grant('manual', 'active');
        foreach (['web', 'mobile'] as $client) {
            $this->getJson('/public/api/membership', ['X-QuizLab-Client' => $client])->assertJsonPath('is_pro', true);
        }
    }

    public function test_disabled_new_sales_does_not_remove_existing_access_or_restore_eligibility(): void
    {
        DB::table('pro_plan_settings')->update(['enabled' => false]);
        $this->grant('google_play', 'active');
        foreach (['web', 'mobile'] as $client) {
            $this->getJson('/public/api/membership', ['X-QuizLab-Client' => $client])
                ->assertJsonPath('plan.enabled', false)->assertJsonPath('is_pro', true);
        }
        ProSubscription::query()->update(['status' => 'expired']);
        $this->postJson('/public/api/membership/razorpay/start')->assertForbidden();
    }

    public function test_annual_web_checkout_has_the_yearly_price_and_no_trial(): void
    {
        $this->student->update(['is_pro' => false]);
        config(['services.pro.annual_price_paise' => 99900]);
        $payment = Mockery::mock(RazorpayProSubscriptions::class);
        $payment->shouldReceive('createPlan')->once()->with(99900, 'yearly')->andReturn('annual-plan');
        $payment->shouldReceive('createSubscription')->once()
            ->with('annual-plan', 0, $this->student->id, $this->student->email, 'yearly')
            ->andReturn(['id' => 'annual-sub', 'short_url' => 'https://example.test/yearly']);
        $this->app->instance(RazorpayProSubscriptions::class, $payment);
        $this->postJson('/public/api/membership/razorpay/start', ['billing_period' => 'annual'])
            ->assertOk()->assertJsonPath('trial_days', 0)->assertJsonPath('amount_paise', 99900);
        $this->assertDatabaseHas('pro_subscriptions', [
            'product_id' => 'quiz-lab-pro-annual', 'trial_ends_at' => null, 'amount_paise' => 99900,
        ]);
    }

    public function test_used_play_trial_prevents_a_second_web_trial(): void
    {
        $sub = $this->grant('google_play', 'expired', -1);
        $sub->update(['trial_ends_at' => now()->subDays(2)]);
        DB::table('pro_plan_settings')->update(['razorpay_plan_id' => 'fixture-plan']);
        $payment = Mockery::mock(RazorpayProSubscriptions::class);
        $payment->shouldReceive('createSubscription')->once()->with('fixture-plan', 0, $this->student->id, $this->student->email)
            ->andReturn(['id' => 'fixture-sub', 'short_url' => 'https://example.test/checkout']);
        $this->app->instance(RazorpayProSubscriptions::class, $payment);
        $this->postJson('/public/api/membership/razorpay/start')->assertOk()->assertJsonPath('trial_days', 0);
    }

    public function test_expired_members_get_only_free_upload_allowance_and_cannot_download_on_either_client(): void
    {
        $this->grant('google_play', 'expired');
        foreach (['web', 'mobile'] as $client) {
            $this->getJson('/public/api/student/uploaded-papers', ['X-QuizLab-Client' => $client])
                ->assertOk()->assertJsonPath('quota.is_pro', false)->assertJsonPath('quota.limit', 1);
            $this->getJson('/public/api/quizzes/999/offline-download', ['X-QuizLab-Client' => $client])->assertForbidden();
        }
    }

    public function test_web_and_app_consume_one_shared_upload_allowance(): void
    {
        $this->grant('google_play', 'active', 30);
        $importer = Mockery::mock(QuestionImporter::class);
        $importer->shouldReceive('normalizeMany')->times(5)->andReturn(['rows' => [['stem' => 'Fixture']], 'errors' => []]);
        $importer->shouldReceive('persist')->times(5)->andReturn([]);
        $this->app->instance(QuestionImporter::class, $importer);
        for ($index = 0; $index < 5; $index++) {
            $client = $index % 2 ? 'mobile' : 'web';
            $this->withHeaders(['Accept' => 'application/json', 'X-QuizLab-Client' => $client])
                ->post('/public/api/student/uploaded-papers', ['paper' => UploadedFile::fake()->createWithContent('paper.json', '[{"stem":"Fixture"}]')])
                ->assertCreated()->assertJsonPath('quota.remaining', 4 - $index);
        }
        foreach (['web', 'mobile'] as $client) {
            $this->getJson('/public/api/student/uploaded-papers', ['X-QuizLab-Client' => $client])
                ->assertOk()->assertJsonPath('quota.remaining', 0)->assertJsonPath('quota.limit', 5)->assertJsonPath('quota.window_days', 7);
            $this->postJson('/public/api/student/uploaded-papers', [], ['X-QuizLab-Client' => $client])
                ->assertStatus(429)->assertJsonPath('quota.remaining', 0);
        }
        $this->travel(7)->days();
        $this->getJson('/public/api/student/uploaded-papers')->assertJsonPath('quota.remaining', 5);
    }

    public function test_free_upload_consumed_on_web_is_not_a_second_free_upload_in_app(): void
    {
        $this->student->update(['is_pro' => false]);
        $importer = Mockery::mock(QuestionImporter::class);
        $importer->shouldReceive('normalizeMany')->once()->andReturn(['rows' => [['stem' => 'Fixture']], 'errors' => []]);
        $importer->shouldReceive('persist')->once()->andReturn([]);
        $this->app->instance(QuestionImporter::class, $importer);
        $this->withHeaders(['Accept' => 'application/json', 'X-QuizLab-Client' => 'web'])
            ->post('/public/api/student/uploaded-papers', ['paper' => UploadedFile::fake()->createWithContent('paper.json', '[{"stem":"Fixture"}]')])
            ->assertCreated()->assertJsonPath('quota.limit', 1)->assertJsonPath('quota.remaining', 0);
        $this->postJson('/public/api/student/uploaded-papers', [], ['X-QuizLab-Client' => 'mobile'])
            ->assertStatus(429)->assertJsonPath('quota.remaining', 0);
        $this->grant('google_play', 'active', 30);
        $this->getJson('/public/api/student/uploaded-papers', ['X-QuizLab-Client' => 'mobile'])
            ->assertJsonPath('quota.limit', 5)->assertJsonPath('quota.used', 1)->assertJsonPath('quota.remaining', 4);
    }
}
