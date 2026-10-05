<?php

namespace Tests\Feature;

use App\Http\Controllers\StorefrontController;
use App\Models\Quiz;
use App\Models\QuizEntitlement;
use App\Models\QuizStorefrontOrder;
use App\Models\User;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

/** Isolated SQLite fixture: never migrates or truncates a configured application database. */
class StorefrontSecurityTest extends TestCase
{
    private StorefrontController $store;
    private User $student;
    private Quiz $paper;

    protected function setUp(): void
    {
        parent::setUp();
        if (! extension_loaded('pdo_sqlite')) {
            $this->markTestSkipped('pdo_sqlite is required for isolated storefront security tests.');
        }
        config([
            'database.default' => 'storefront_test',
            'database.connections.storefront_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'services.razorpay.key_id' => 'rzp_test_fixture',
            'services.razorpay.key_secret' => 'fixture_secret',
            'services.razorpay.webhook_secret' => 'fixture_webhook',
        ]);
        DB::purge('storefront_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email');
            $table->string('role'); $table->boolean('is_admin')->default(false); $table->timestamps();
        });
        Schema::create('courses', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('slug'); $table->string('level')->nullable();
            $table->string('icon')->nullable(); $table->boolean('is_active')->default(true);
        });
        Schema::create('quizzes', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('course_id'); $table->unsignedBigInteger('week_id')->nullable();
            $table->string('title'); $table->text('description')->nullable(); $table->string('section')->default('practice');
            $table->integer('year')->nullable(); $table->integer('time_limit_minutes')->nullable();
            $table->boolean('is_active')->default(true); $table->string('approval_status')->default('approved'); $table->timestamps();
        });
        Schema::create('questions', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('quiz_id'); $table->integer('position')->default(0);
        });
        (require database_path('migrations/2026_10_05_000004_add_quiz_storefront_and_orders.php'))->up();
        DB::table('courses')->insert(['id' => 1, 'name' => 'Math', 'slug' => 'math', 'is_active' => true]);
        $this->student = User::query()->create(['name' => 'Student', 'email' => 'student@example.test', 'role' => 'student']);
        $this->paper = Quiz::query()->create(['course_id' => 1, 'title' => 'Paper', 'price_paise' => 9900, 'access_days' => 30]);
        $this->store = new StorefrontController();
        Http::preventStrayRequests();
        $this->travelTo(now()->startOfSecond());
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        DB::purge('storefront_test');
        parent::tearDown();
    }

    private function request(array $data = [], ?User $user = null): Request
    {
        $request = Request::create('/api/storefront', 'POST', $data);
        $request->setUserResolver(fn () => $user ?? $this->student);
        return $request;
    }

    private function order(string $id = 'order_fixture'): QuizStorefrontOrder
    {
        return QuizStorefrontOrder::query()->create([
            'user_id' => $this->student->id, 'quiz_id' => $this->paper->id,
            'razorpay_order_id' => $id, 'amount_paise' => 9900, 'access_days' => 30,
            'currency' => 'INR', 'status' => 'created',
        ]);
    }

    private function payment(QuizStorefrontOrder $order, array $overrides = []): array
    {
        return array_replace(['id' => 'pay_fixture', 'order_id' => $order->razorpay_order_id,
            'amount' => 9900, 'currency' => 'INR', 'status' => 'captured'], $overrides);
    }

    private function verification(QuizStorefrontOrder $order, string $paymentId = 'pay_fixture'): array
    {
        return ['razorpay_order_id' => $order->razorpay_order_id, 'razorpay_payment_id' => $paymentId,
            'razorpay_signature' => hash_hmac('sha256', $order->razorpay_order_id.'|'.$paymentId, 'fixture_secret')];
    }

    private function webhook(array $payment, string $event = 'payment.captured', bool $valid = true): Request
    {
        $body = json_encode(['event' => $event, 'payload' => ['payment' => ['entity' => $payment]]], JSON_THROW_ON_ERROR);
        return Request::create('/api/storefront/razorpay/webhook', 'POST', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X_RAZORPAY_SIGNATURE' => $valid ? hash_hmac('sha256', $body, 'fixture_webhook') : str_repeat('0', 64),
        ], $body);
    }

    private function assertAborts(int $status, callable $action): void
    {
        try {
            $action();
            $this->fail('Expected request rejection.');
        } catch (HttpException $exception) {
            $this->assertSame($status, $exception->getStatusCode());
        }
    }

    public function test_free_claim_is_idempotent_and_honors_duration(): void
    {
        $this->paper->update(['price_paise' => 0]);
        $this->store->claimFree($this->request(), $this->paper->id);
        $expiry = QuizEntitlement::query()->sole()->expires_at;
        $this->assertTrue($expiry->equalTo(now()->addDays(30)));
        $this->travel(1)->days();
        $this->store->claimFree($this->request(), $this->paper->id);
        $this->assertTrue(QuizEntitlement::query()->sole()->expires_at->equalTo($expiry));
    }

    public function test_paid_paper_cannot_be_claimed_for_free(): void
    {
        $this->assertAborts(409, fn () => $this->store->claimFree($this->request(), $this->paper->id));
        $this->assertSame(0, QuizEntitlement::query()->count());
    }

    public function test_order_uses_server_price_and_reuses_recent_checkout(): void
    {
        Http::fake(['api.razorpay.com/v1/orders' => Http::response(['id' => 'order_fixture'], 200)]);
        $response = $this->store->createOrder($this->request(['amount' => 1]), $this->paper->id);
        $this->assertSame(9900, $response->getData(true)['amount']);
        $this->store->createOrder($this->request(), $this->paper->id);
        Http::assertSentCount(1);
        Http::assertSent(fn ($request) => $request['amount'] === 9900 && $request['currency'] === 'INR');
        $this->assertSame(1, QuizStorefrontOrder::query()->count());
    }

    public function test_forged_signature_never_grants_access(): void
    {
        $order = $this->order();
        $payload = array_replace($this->verification($order), ['razorpay_signature' => str_repeat('0', 64)]);
        $this->assertAborts(400, fn () => $this->store->verifyPayment($this->request($payload)));
        Http::assertNothingSent();
        $this->assertSame(0, QuizEntitlement::query()->count());
    }

    public function test_another_students_order_cannot_be_verified(): void
    {
        $order = $this->order();
        $other = User::query()->create(['name' => 'Other', 'email' => 'other@example.test', 'role' => 'student']);
        $this->expectException(ModelNotFoundException::class);
        $this->store->verifyPayment($this->request($this->verification($order), $other));
    }

    public function test_authorized_but_uncaptured_payment_does_not_unlock_paper(): void
    {
        $order = $this->order();
        Http::fake(['api.razorpay.com/v1/payments/*' => Http::response($this->payment($order, ['status' => 'authorized']))]);
        $this->assertSame(409, $this->store->verifyPayment($this->request($this->verification($order)))->getStatusCode());
        $this->assertSame(0, QuizEntitlement::query()->count());
    }

    public function test_captured_payment_with_wrong_amount_does_not_unlock_paper(): void
    {
        $order = $this->order();
        Http::fake(['api.razorpay.com/v1/payments/*' => Http::response($this->payment($order, ['amount' => 1]))]);
        $this->assertAborts(400, fn () => $this->store->verifyPayment($this->request($this->verification($order))));
        $this->assertSame(0, QuizEntitlement::query()->count());
    }

    public function test_checkout_and_webhook_replays_grant_only_once(): void
    {
        $order = $this->order();
        Http::fake(['api.razorpay.com/v1/payments/*' => Http::response($this->payment($order))]);
        $this->store->verifyPayment($this->request($this->verification($order)));
        $expiry = QuizEntitlement::query()->sole()->expires_at;
        $this->travel(1)->days();
        $this->store->webhook($this->webhook($this->payment($order)));
        $this->store->webhook($this->webhook($this->payment($order), 'order.paid'));
        $this->assertTrue(QuizEntitlement::query()->sole()->expires_at->equalTo($expiry));
        $this->assertSame('paid', $order->fresh()->status);
    }

    public function test_forged_webhook_and_mismatched_currency_are_rejected(): void
    {
        $order = $this->order();
        $this->assertAborts(400, fn () => $this->store->webhook($this->webhook($this->payment($order), valid: false)));
        $this->assertAborts(400, fn () => $this->store->webhook($this->webhook($this->payment($order, ['currency' => 'USD']))));
        $this->assertSame(0, QuizEntitlement::query()->count());
    }

    public function test_second_captured_order_extends_existing_access(): void
    {
        $first = $this->order();
        $second = $this->order('order_second');
        $this->store->webhook($this->webhook($this->payment($first)));
        $this->store->webhook($this->webhook($this->payment($second, ['id' => 'pay_second'])));
        $this->assertTrue(QuizEntitlement::query()->sole()->expires_at->equalTo(now()->addDays(60)));
    }

    public function test_paid_paper_content_and_attempts_require_current_entitlement(): void
    {
        $quizController = new \App\Http\Controllers\QuizController();
        $attemptController = app(\App\Http\Controllers\AttemptController::class);
        $this->assertSame(402, $quizController->show($this->request(), $this->paper->id)->getStatusCode());
        $this->assertSame(402, $attemptController->start($this->request(), $this->paper->id)->getStatusCode());
        QuizEntitlement::query()->create([
            'user_id' => $this->student->id, 'quiz_id' => $this->paper->id,
            'source' => 'purchase', 'expires_at' => now()->subSecond(),
        ]);
        $this->assertSame(402, $quizController->show($this->request(), $this->paper->id)->getStatusCode());
        $this->assertSame(402, $attemptController->start($this->request(), $this->paper->id)->getStatusCode());
        QuizEntitlement::query()->sole()->update(['expires_at' => now()->addDay()]);
        $this->assertSame(200, $quizController->show($this->request(), $this->paper->id)->getStatusCode());
    }

    public function test_delayed_payment_does_not_shorten_lifetime_access(): void
    {
        $order = $this->order();
        QuizEntitlement::query()->create([
            'user_id' => $this->student->id, 'quiz_id' => $this->paper->id,
            'source' => 'manager_grant', 'expires_at' => null,
        ]);
        $this->store->webhook($this->webhook($this->payment($order)));
        $this->assertNull(QuizEntitlement::query()->sole()->expires_at);
    }

    public function test_students_cannot_change_prices(): void
    {
        $this->assertAborts(403, fn () => $this->store->updatePrice($this->request(['price_paise' => 0]), $this->paper->id));
        $this->assertSame(9900, $this->paper->fresh()->price_paise);
    }

    public function test_expired_unavailable_purchases_remain_in_library(): void
    {
        $order = $this->order();
        $this->store->webhook($this->webhook($this->payment($order)));
        $this->travel(31)->days();
        $this->paper->update(['is_active' => false]);
        $paper = $this->store->myPapers($this->request())->getData(true)['papers'][0];
        $this->assertTrue($paper['expired']);
        $this->assertFalse($paper['has_access']);
        $this->assertFalse($paper['available']);
    }
}
