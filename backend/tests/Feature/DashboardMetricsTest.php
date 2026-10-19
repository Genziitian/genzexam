<?php

namespace Tests\Feature;

use App\Http\Controllers\DashboardController;
use Carbon\Carbon;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use ReflectionMethod;
use Tests\TestCase;

class DashboardMetricsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'database.default' => 'metrics_test',
            'database.connections.metrics_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => ''],
        ]);
        DB::purge('metrics_test');
        Schema::create('attempts', function (Blueprint $table) {
            $table->id(); $table->unsignedBigInteger('user_id'); $table->unsignedBigInteger('quiz_id')->default(1);
            $table->timestamp('started_at')->nullable(); $table->timestamp('submitted_at')->nullable();
            $table->boolean('is_complete')->default(true);
            $table->float('score')->nullable(); $table->float('total_marks')->nullable();
        });
    }

    protected function tearDown(): void
    {
        DB::purge('metrics_test');
        parent::tearDown();
    }

    private function attempt(array $data = []): void
    {
        DB::table('attempts')->insert(array_merge([
            'user_id' => 7, 'started_at' => '2026-10-19 07:00:00',
            'submitted_at' => '2026-10-19 07:05:00',
            'is_complete' => true, 'score' => 8, 'total_marks' => 10,
        ], $data));
    }

    private function metric(string $method): array
    {
        return (new ReflectionMethod(DashboardController::class, $method))->invoke(
            new DashboardController(), 7, Carbon::parse('2026-10-19 08:00:00', 'UTC'),
        );
    }

    public function test_completed_attempts_produce_accuracy_study_time_and_speed(): void
    {
        $this->attempt();
        $this->assertEquals(80, $this->metric('accuracyWidget')['value']);
        $hours = $this->metric('hoursWidget');
        $this->assertEquals(0.1, $hours['value']);
        $this->assertEquals(0.08, $hours['history'][11]);
        $week = $this->metric('performance')[11];
        $this->assertSame(1, $week['attempts']);
        $this->assertEquals(80, $week['accuracy']);
        $this->assertEquals(80, $week['score']);
        $this->assertEqualsWithDelta(55.6, $week['speed'], 0.01);
    }

    public function test_a_thirty_minute_submission_counts_as_half_an_hour(): void
    {
        $this->attempt(['submitted_at' => '2026-10-19 07:30:00']);
        $this->assertEquals(0.5, $this->metric('hoursWidget')['value']);
    }

    public function test_monday_resets_the_weekly_cards_but_keeps_sundays_result_in_the_chart(): void
    {
        $this->attempt([
            'started_at' => '2026-10-18 22:00:00', 'submitted_at' => '2026-10-18 22:30:00',
            'score' => 2,
        ]);
        $accuracy = $this->metric('accuracyWidget');
        $this->assertEquals(0, $accuracy['value']);
        $this->assertEquals(-20, $accuracy['delta']);
        $this->assertEquals(0, $this->metric('hoursWidget')['value']);
        $performance = $this->metric('performance');
        $this->assertCount(12, $performance);
        $this->assertEquals(20, $performance[10]['accuracy']);
        $this->assertSame(1, $performance[10]['attempts']);
        $this->assertSame(0, $performance[11]['attempts']);
    }

    public function test_zero_score_is_a_real_attempt_and_other_users_and_unsubmitted_work_are_excluded(): void
    {
        $this->attempt(['score' => 0]);
        $this->attempt(['user_id' => 8]);
        $this->attempt(['is_complete' => false]);
        $this->attempt(['submitted_at' => null]);
        $this->attempt(['total_marks' => 0]);
        $this->attempt(['started_at' => '2026-07-01 07:00:00', 'submitted_at' => '2026-07-01 07:30:00']);
        $weeks = $this->metric('performance');
        $this->assertSame(1, array_sum(array_column($weeks, 'attempts')));
        $this->assertEquals(0, $weeks[11]['accuracy']);
        $this->assertEquals(0, $weeks[11]['score']);
        $this->assertGreaterThan(0, $weeks[11]['speed']);
    }

    public function test_invalid_reversed_timestamps_do_not_add_study_time(): void
    {
        $this->attempt(['started_at' => '2026-10-19 07:10:00']);
        $this->assertEquals(0, $this->metric('hoursWidget')['value']);
        $this->assertEquals(0, $this->metric('performance')[11]['speed']);
    }
}
