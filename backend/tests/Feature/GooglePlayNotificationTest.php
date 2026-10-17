<?php

namespace Tests\Feature;

use App\Models\ProSubscription;
use App\Models\User;
use App\Http\Controllers\ProMembershipController;
use Illuminate\Http\Request;
use App\Services\GooglePlaySubscriptions;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Mockery;
use Tests\TestCase;

class GooglePlayNotificationTest extends TestCase
{
    private string $endpoint = '/public/api/membership/google-play/notifications';
    private string $token = 'fixture-play-purchase-token-123456';
    private User $student;
    private ProSubscription $subscription;

    protected function setUp(): void
    {
        parent::setUp();
        if (! in_array('sqlite', \PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('pdo_sqlite is required.');
        }
        config([
            'database.default' => 'play_test',
            'database.connections.play_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'cache.default' => 'array',
            'services.google_play.package_name' => 'in.genziitian.quizlab',
            'services.google_play.subscription_product_id' => 'quiz_lab_pro_monthly',
            'services.google_play.trial_offer_id' => 'trial-7-days',
            'services.google_play.rtdn_audience' => 'https://api.example.test'.$this->endpoint,
            'services.google_play.rtdn_service_account_email' => 'push@example.iam.gserviceaccount.com',
            'services.google_play.rtdn_subscription' => 'projects/teaching-lms/subscriptions/quizlab-play-rtdn-sub',
        ]);
        DB::purge('play_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email');
            $table->string('role')->default('student'); $table->boolean('is_admin')->default(false);
            $table->boolean('is_pro')->default(false); $table->timestamps();
        });
        (require database_path('migrations/2026_10_09_000002_create_pro_subscriptions_and_plan_settings.php'))->up();
        (require database_path('migrations/2026_10_17_000001_create_google_play_notifications_table.php'))->up();
        $this->travelTo(now()->startOfSecond());
        $this->student = User::query()->create(['name' => 'Student', 'email' => 'student@example.test', 'is_pro' => true]);
        $this->subscription = ProSubscription::query()->create([
            'user_id' => $this->student->id, 'provider' => 'google_play',
            'provider_reference_hash' => hash('sha256', $this->token),
            'google_purchase_token' => $this->token, 'product_id' => 'quiz_lab_pro_monthly',
            'status' => 'active', 'current_period_ends_at' => now()->addDay(),
        ]);
        Http::preventStrayRequests();
        $this->identity();
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        DB::purge('play_test');
        parent::tearDown();
    }

    private function identity(array $overrides = [], int $status = 200): void
    {
        Http::swap(new \Illuminate\Http\Client\Factory());
        Http::preventStrayRequests();
        Http::fake(['https://oauth2.googleapis.com/tokeninfo*' => Http::response(array_replace([
            'iss' => 'https://accounts.google.com', 'sub' => '123456789',
            'aud' => config('services.google_play.rtdn_audience'),
            'email' => config('services.google_play.rtdn_service_account_email'),
            'email_verified' => 'true', 'exp' => now()->addHour()->timestamp,
            'iat' => now()->subMinute()->timestamp,
        ], $overrides), $status)]);
    }

    private function event(string $messageId = 'event-1', array $overrides = []): array
    {
        $event = array_replace([
            'version' => '1.0', 'packageName' => 'in.genziitian.quizlab',
            'eventTimeMillis' => (string) (now()->timestamp * 1000),
            'subscriptionNotification' => [
                'version' => '1.0', 'notificationType' => 2,
                'purchaseToken' => $this->token, 'subscriptionId' => 'quiz_lab_pro_monthly',
            ],
        ], $overrides);
        return ['subscription' => config('services.google_play.rtdn_subscription'),
            'message' => ['messageId' => $messageId, 'data' => base64_encode(json_encode($event))]];
    }

    private function purchase(string $state = 'ACTIVE', array $lineOverrides = []): array
    {
        return ['subscriptionState' => 'SUBSCRIPTION_STATE_'.$state,
            'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
            'lineItems' => [array_replace([
                'productId' => 'quiz_lab_pro_monthly', 'expiryTime' => now()->addMonth()->toRfc3339String(),
                'autoRenewingPlan' => ['autoRenewEnabled' => true],
                'offerDetails' => ['offerId' => 'trial-7-days'],
                'offerPhase' => ['basePrice' => []],
            ], $lineOverrides)]];
    }

    private function play(array $purchase, int $times = 1): void
    {
        $play = Mockery::mock(GooglePlaySubscriptions::class);
        $play->shouldReceive('get')->with($this->token)->times($times)->andReturn($purchase);
        $this->app->instance(GooglePlaySubscriptions::class, $play);
    }

    private function push(array $body)
    {
        return $this->withHeader('Authorization', 'Bearer fixture-google-id-token')->postJson($this->endpoint, $body);
    }

    public function test_missing_authentication_cannot_change_access(): void
    {
        $this->postJson($this->endpoint, $this->event())->assertUnauthorized();
        $this->assertSame(0, DB::table('google_play_notifications')->count());
        Http::assertNothingSent();
    }

    public function test_unconfigured_endpoint_fails_closed(): void
    {
        config(['services.google_play.rtdn_service_account_email' => '']);
        $this->push($this->event())->assertStatus(503);
        Http::assertNothingSent();
    }

    public function test_google_rejecting_a_forged_token_is_not_accepted(): void
    {
        $this->identity([], 400);
        $this->push($this->event())->assertUnauthorized();
        $this->assertSame(0, DB::table('google_play_notifications')->count());
    }

    public function test_wrong_identity_audience_issuer_or_expiry_is_rejected(): void
    {
        foreach ([['email' => 'attacker@example.test'], ['aud' => 'wrong'], ['email_verified' => false],
            ['iss' => 'https://attacker.test'], ['exp' => now()->subSecond()->timestamp],
            ['iat' => now()->addMinutes(5)->timestamp]] as $claims) {
            $this->identity($claims);
            $this->push($this->event())->assertForbidden();
        }
        $this->assertSame(0, DB::table('google_play_notifications')->count());
    }

    public function test_google_authentication_outage_requests_retry(): void
    {
        $this->identity([], 503);
        $this->push($this->event())->assertStatus(503);
    }

    public function test_wrong_package_or_subscription_is_rejected(): void
    {
        $this->push($this->event(overrides: ['packageName' => 'other.app']))->assertForbidden();
        $body = $this->event(); $body['subscription'] = 'projects/other/subscriptions/untrusted';
        $this->push($body)->assertForbidden();
        $this->assertSame(0, DB::table('google_play_notifications')->count());
    }

    public function test_malformed_payload_does_not_get_acknowledged(): void
    {
        $body = $this->event(); $body['message']['data'] = 'not base64!!!';
        $this->push($body)->assertBadRequest();
        $body['message']['data'] = base64_encode('invalid json');
        $this->push($body)->assertBadRequest();
    }

    public function test_test_message_is_recorded_without_unlocking_or_calling_play(): void
    {
        $this->student->update(['is_pro' => false]);
        $this->subscription->update(['status' => 'expired']);
        $this->play([], 0);
        $this->push($this->event(overrides: ['subscriptionNotification' => null, 'testNotification' => ['version' => '1.0']]))->assertNoContent();
        $this->assertSame('processed', DB::table('google_play_notifications')->sole()->status);
        $this->assertFalse($this->student->fresh()->hasProAccess());
    }

    public function test_renewal_extends_access_and_duplicate_is_not_applied_twice(): void
    {
        $this->subscription->update(['status' => 'expired', 'current_period_ends_at' => now()->subDay()]);
        $this->student->update(['is_pro' => false]);
        $this->play($this->purchase());
        $this->push($this->event())->assertNoContent();
        $this->push($this->event())->assertNoContent();
        $this->assertTrue($this->student->fresh()->hasProAccess());
        $this->assertTrue($this->student->fresh()->is_pro);
        $this->assertSame('active', $this->subscription->fresh()->status);
        $this->assertTrue($this->subscription->fresh()->current_period_ends_at->equalTo(now()->addMonth()));
        $this->assertSame(1, DB::table('google_play_notifications')->sole()->attempts);
        $this->assertStringNotContainsString($this->token, json_encode(DB::table('google_play_notifications')->get()));
    }

    public function test_cancel_preserves_remaining_access_and_restore_clears_cancel_marker(): void
    {
        $this->play($this->purchase('CANCELED', ['autoRenewingPlan' => ['autoRenewEnabled' => false]]));
        $this->push($this->event())->assertNoContent();
        $this->assertTrue($this->student->fresh()->hasProAccess());
        $this->assertSame('cancelled', $this->subscription->fresh()->status);
        $this->assertTrue($this->subscription->fresh()->cancel_at_period_end);
        $this->play($this->purchase());
        $this->push($this->event('event-restored'))->assertNoContent();
        $this->assertFalse($this->subscription->fresh()->cancel_at_period_end);
        $this->assertNull($this->subscription->fresh()->cancelled_at);
    }

    public function test_hold_pause_and_expiry_remove_access_but_grace_preserves_it(): void
    {
        foreach (['IN_GRACE_PERIOD' => true, 'ON_HOLD' => false, 'PAUSED' => false, 'EXPIRED' => false] as $state => $access) {
            $this->play($this->purchase($state));
            $this->push($this->event('event-'.$state))->assertNoContent();
            $this->assertSame($access, $this->student->fresh()->hasProAccess(), $state);
            $this->assertSame($access, $this->student->fresh()->is_pro, $state);
            $this->assertSame($access, $this->subscription->fresh()->grantsAccess(), $state);
        }
    }

    public function test_expired_subscription_cannot_remove_another_valid_grant(): void
    {
        ProSubscription::query()->create(['user_id' => $this->student->id, 'provider' => 'manual',
            'status' => 'active', 'current_period_ends_at' => now()->addYear()]);
        $this->play($this->purchase('EXPIRED'));
        $this->push($this->event())->assertNoContent();
        $this->assertTrue($this->student->fresh()->hasProAccess());
        $this->assertTrue($this->student->fresh()->is_pro);
    }

    public function test_replayed_old_event_uses_current_google_state(): void
    {
        $this->play($this->purchase());
        $this->push($this->event(overrides: ['eventTimeMillis' => '1000', 'subscriptionNotification' => [
            'notificationType' => 12, 'purchaseToken' => $this->token, 'subscriptionId' => 'quiz_lab_pro_monthly',
        ]]))->assertNoContent();
        $this->assertTrue($this->student->fresh()->hasProAccess());
    }

    public function test_current_google_payload_without_subscription_id_is_processed(): void
    {
        $this->play($this->purchase());
        $this->push($this->event(overrides: ['subscriptionNotification' => [
            'notificationType' => 2, 'purchaseToken' => $this->token,
        ]]))->assertNoContent();
        $this->assertSame('processed', DB::table('google_play_notifications')->sole()->status);
    }

    public function test_trial_conversion_uses_current_phase_not_persistent_offer_id(): void
    {
        $this->subscription->update(['status' => 'trialing', 'trial_ends_at' => now()->addDay()]);
        $this->play($this->purchase());
        $this->push($this->event())->assertNoContent();
        $this->assertSame('active', $this->subscription->fresh()->status);
        $this->assertNotNull($this->subscription->fresh()->paid_at);
    }

    public function test_actual_trial_is_recorded_without_a_paid_date(): void
    {
        $this->play($this->purchase(lineOverrides: ['offerPhase' => ['freeTrial' => []]]));
        $this->push($this->event())->assertNoContent();
        $this->assertSame('trialing', $this->subscription->fresh()->status);
        $this->assertNotNull($this->subscription->fresh()->trial_ends_at);
        $this->assertNull($this->subscription->fresh()->paid_at);
    }

    public function test_provider_failure_is_retryable_and_does_not_ack_or_mutate_membership(): void
    {
        $play = Mockery::mock(GooglePlaySubscriptions::class);
        $play->shouldReceive('get')->once()->andThrow(new \RuntimeException('fixture failure'));
        $this->app->instance(GooglePlaySubscriptions::class, $play);
        $this->push($this->event())->assertStatus(503);
        $this->assertSame('pending', DB::table('google_play_notifications')->sole()->status);
        $this->assertNull(DB::table('google_play_notifications')->sole()->processed_at);
        $this->assertSame('active', $this->subscription->fresh()->status);
        $this->play($this->purchase());
        $this->push($this->event())->assertNoContent();
    }

    public function test_unknown_purchase_retries_until_app_links_it(): void
    {
        $this->subscription->delete();
        $this->play([], 0);
        $this->push($this->event())->assertStatus(503);
        $this->assertSame('unlinked', DB::table('google_play_notifications')->sole()->status);
        $this->assertSame(0, ProSubscription::query()->count());
        $this->subscription->exists = false; $this->subscription->save();
        $this->play($this->purchase());
        $this->push($this->event())->assertNoContent();
        $this->assertSame('processed', DB::table('google_play_notifications')->sole()->status);
    }

    public function test_voided_subscription_checks_google_before_changing_access(): void
    {
        $this->play($this->purchase('EXPIRED'));
        $this->push($this->event(overrides: ['subscriptionNotification' => null,
            'voidedPurchaseNotification' => ['productType' => 1, 'purchaseToken' => $this->token, 'refundType' => 1]]))->assertNoContent();
        $this->assertFalse($this->student->fresh()->hasProAccess());
    }

    public function test_unrelated_product_is_acknowledged_without_touching_pro(): void
    {
        $this->play([], 0);
        $this->push($this->event(overrides: ['subscriptionNotification' => [
            'notificationType' => 2, 'purchaseToken' => 'other-token', 'subscriptionId' => 'other-product',
        ]]))->assertNoContent();
        $this->assertSame('ignored', DB::table('google_play_notifications')->sole()->status);
        $this->assertTrue($this->student->fresh()->hasProAccess());
    }

    public function test_acknowledgement_failure_retries_before_committing_access(): void
    {
        $this->subscription->update(['status' => 'expired']);
        $purchase = $this->purchase();
        $purchase['acknowledgementState'] = 'ACKNOWLEDGEMENT_STATE_PENDING';
        $play = Mockery::mock(GooglePlaySubscriptions::class);
        $play->shouldReceive('get')->twice()->with($this->token)->andReturn($purchase);
        $play->shouldReceive('acknowledge')->once()->with($this->token, 'quiz_lab_pro_monthly')
            ->andThrow(new \RuntimeException('temporary acknowledgement failure'));
        $play->shouldReceive('acknowledge')->once()->with($this->token, 'quiz_lab_pro_monthly')->andReturnNull();
        $this->app->instance(GooglePlaySubscriptions::class, $play);
        $this->push($this->event())->assertStatus(503);
        $this->assertSame('expired', $this->subscription->fresh()->status);
        $this->push($this->event())->assertNoContent();
        $this->assertSame('active', $this->subscription->fresh()->status);
    }

    public function test_membership_refresh_cannot_reenable_paused_access(): void
    {
        $this->play($this->purchase('PAUSED'));
        $request = Request::create('/public/api/membership', 'GET');
        $request->setUserResolver(fn () => $this->student);
        $response = (new ProMembershipController())->show($request);
        $this->assertFalse($response->getData(true)['is_pro']);
        $this->assertSame('paused', $this->subscription->fresh()->status);
    }

    public function test_restore_preserves_trial_history_after_conversion_to_paid(): void
    {
        $trialEnd = now()->subDay();
        $this->subscription->update(['trial_ends_at' => $trialEnd]);
        $this->play($this->purchase());
        $request = Request::create('/public/api/membership/google-play/verify', 'POST', [
            'purchase_token' => $this->token, 'product_id' => 'quiz_lab_pro_monthly',
        ]);
        $request->setUserResolver(fn () => $this->student);
        $response = (new ProMembershipController())->verifyGooglePlay($request);
        $this->assertSame(200, $response->getStatusCode());
        $this->assertSame('active', $this->subscription->fresh()->status);
        $this->assertTrue($this->subscription->fresh()->trial_ends_at->equalTo($trialEnd));
    }

    public function test_unknown_remote_state_retries_and_past_expiry_cannot_grant_access(): void
    {
        $this->play($this->purchase('UNRECOGNIZED'));
        $this->push($this->event())->assertStatus(503);
        $this->play($this->purchase(lineOverrides: ['expiryTime' => now()->subSecond()->toRfc3339String()]));
        $this->push($this->event())->assertNoContent();
        $this->assertFalse($this->student->fresh()->hasProAccess());
    }
}
