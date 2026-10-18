<?php

namespace Tests\Feature;

use App\Models\Quiz;
use App\Models\User;
use App\Services\QuestionImporter;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\UploadedFile;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Mockery;
use Tests\TestCase;

class SpinPracticeQuotaTest extends TestCase
{
    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'spin_quota_test',
            'database.connections.spin_quota_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'cache.default' => 'array', 'services.student_paper_uploads.free_limit' => 1,
            'services.student_paper_uploads.limit' => 5, 'services.student_paper_uploads.window_days' => 7]);
        DB::purge('spin_quota_test');
        Schema::create('users', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->string('email'); $t->string('role')->default('student');
            $t->boolean('is_admin')->default(false); $t->boolean('is_pro')->default(false);
            $t->timestamp('last_seen_at')->nullable(); $t->timestamps();
        });
        Schema::create('courses', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->string('slug'); $t->boolean('is_active')->default(true); $t->integer('sort_order')->default(0);
        });
        Schema::create('weeks', function (Blueprint $t) { $t->id(); $t->integer('week_number'); $t->string('title'); });
        Schema::create('quizzes', function (Blueprint $t) {
            $t->id(); $t->unsignedBigInteger('course_id'); $t->unsignedBigInteger('week_id')->nullable();
            $t->string('section'); $t->string('title'); $t->text('description')->nullable();
            $t->integer('time_limit_minutes')->nullable(); $t->integer('price_paise')->default(0);
            $t->boolean('is_active')->default(true); $t->string('approval_status')->default('approved');
            $t->unsignedBigInteger('created_by')->nullable(); $t->unsignedBigInteger('reviewed_by')->nullable();
            $t->timestamp('reviewed_at')->nullable(); $t->boolean('is_personal')->default(false);
            $t->unsignedBigInteger('owner_user_id')->nullable(); $t->timestamps();
        });
        Schema::create('questions', function (Blueprint $t) {
            $t->id(); $t->unsignedBigInteger('quiz_id'); $t->string('type'); $t->text('stem');
            foreach (['stem_image', 'stem_code', 'stem_code_language', 'stem_table', 'explanation'] as $column) $t->text($column)->nullable();
            $t->integer('marks')->default(1); $t->string('difficulty')->default('medium'); $t->integer('position');
            $t->string('numerical_answer')->nullable(); $t->string('numerical_tolerance')->nullable(); $t->softDeletes(); $t->timestamps();
        });
        Schema::create('question_options', function (Blueprint $t) {
            $t->id(); $t->unsignedBigInteger('question_id'); $t->string('option_type'); $t->text('option_text');
            $t->string('code_language')->nullable(); $t->boolean('is_correct'); $t->integer('position'); $t->timestamps();
        });
        Schema::create('short_answer_acceptables', function (Blueprint $t) {
            $t->id(); $t->unsignedBigInteger('question_id'); $t->text('acceptable_text'); $t->timestamps();
        });
        DB::table('courses')->insert(['id' => 1, 'name' => 'Maths 1', 'slug' => 'maths-1']);
        DB::table('quizzes')->insert(['id' => 1, 'course_id' => 1, 'section' => 'practice', 'title' => 'Source paper']);
        for ($i = 1; $i <= 12; $i++) {
            DB::table('questions')->insert(['quiz_id' => 1, 'type' => 'numerical', 'stem' => "Question {$i}", 'position' => $i, 'numerical_answer' => '1']);
        }
        $this->travelTo(now()->startOfSecond());
        $this->student = User::query()->create(['name' => 'Student', 'email' => 'spin@example.test']);
        $this->actingAs($this->student, 'sanctum');
        $this->withoutMiddleware(ThrottleRequests::class);
        Http::preventStrayRequests();
    }

    protected function tearDown(): void
    {
        $this->travelBack(); DB::purge('spin_quota_test'); parent::tearDown();
    }

    private function spin(string $client = 'web'): int
    {
        $response = $this->postJson('/public/api/student/spin-practice', [
            'course_id' => 1, 'week_min' => 1, 'week_max' => 12, 'paper_types' => ['all'],
        ], ['X-QuizLab-Client' => $client])->assertCreated()->assertJsonPath('question_count', 10);
        $id = $response->json('id');
        $paper = Quiz::withoutGlobalScope('exclude_personal_uploads')->findOrFail($id);
        $this->assertSame(0, $paper->price_paise);
        $this->assertSame($this->student->id, $paper->owner_user_id);
        $this->getJson("/public/api/quizzes/{$id}", ['X-QuizLab-Client' => $client])->assertOk()->assertJsonCount(10, 'questions');
        return $id;
    }

    public function test_free_spins_and_legacy_spin_papers_never_use_upload_allowance(): void
    {
        // Match already-created production papers independently of the new constant.
        Quiz::query()->create(['course_id' => 1, 'section' => 'practice', 'title' => 'Old spin',
            'description' => 'Unified practice paper generated from Spin Wheel (Maths 1, Weeks 1–12).',
            'is_personal' => true, 'owner_user_id' => $this->student->id]);
        foreach (['web', 'mobile'] as $client) {
            $this->spin($client);
            $this->getJson('/public/api/student/uploaded-papers', ['X-QuizLab-Client' => $client])
                ->assertOk()->assertJsonCount(0, 'papers')->assertJsonPath('quota.used', 0)
                ->assertJsonPath('quota.remaining', 1)->assertJsonPath('quota.resets_at', null);
        }
        $this->assertSame(0, Quiz::withoutGlobalScope('exclude_personal_uploads')->fileUploads()->count());
    }

    public function test_spinning_still_works_when_upload_allowance_is_exhausted_and_does_not_change_reset_time(): void
    {
        // Legacy uploads can have no description and must still count.
        Quiz::query()->create(['course_id' => 1, 'section' => 'practice', 'title' => 'Actual upload',
            'is_personal' => true, 'owner_user_id' => $this->student->id,
            'created_at' => now()->subDays(2), 'updated_at' => now()->subDays(2)]);
        $before = $this->getJson('/public/api/student/uploaded-papers')->assertOk()
            ->assertJsonPath('quota.remaining', 0)->json('quota');
        $this->spin(); $this->spin('mobile');
        $this->getJson('/public/api/student/uploaded-papers')->assertOk()->assertJsonCount(1, 'papers')->assertJsonPath('quota', $before);
        $this->student->update(['is_pro' => true]);
        $this->getJson('/public/api/student/uploaded-papers')->assertJsonPath('quota.used', 1)->assertJsonPath('quota.remaining', 4);
    }

    public function test_real_file_upload_still_uses_exactly_one_slot_after_free_spins(): void
    {
        $this->spin(); $this->spin('mobile');
        $importer = Mockery::mock(QuestionImporter::class);
        $importer->shouldReceive('normalizeMany')->once()->andReturn(['rows' => [['stem' => 'Fixture']], 'errors' => []]);
        $importer->shouldReceive('persist')->once()->andReturn([]);
        $this->app->instance(QuestionImporter::class, $importer);
        $this->withHeaders(['Accept' => 'application/json', 'X-QuizLab-Client' => 'mobile'])
            ->post('/public/api/student/uploaded-papers', ['paper' => UploadedFile::fake()->createWithContent('paper.json', '[{"stem":"Fixture"}]')])
            ->assertCreated()->assertJsonPath('quota.used', 1)->assertJsonPath('quota.remaining', 0);
        $this->getJson('/public/api/student/uploaded-papers')->assertJsonCount(1, 'papers')->assertJsonPath('quota.used', 1);
    }
}
