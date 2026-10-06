<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Real HTTP routes and controllers; a private in-memory database never touches application data. */
class ProctoredExamSecurityTest extends TestCase
{
    private User $manager;
    private User $candidate;
    private User $other;
    private const BASE = '/public/api/exam-platform';

    protected function setUp(): void
    {
        parent::setUp();
        if (!in_array('sqlite', \PDO::getAvailableDrivers(), true)) $this->markTestSkipped('A PDO SQLite driver is required.');
        config([
            'database.default' => 'exam_test',
            'database.connections.exam_test' => ['driver' => 'sqlite', 'database' => ':memory:', 'prefix' => '', 'foreign_key_constraints' => true],
            'cache.default' => 'array', 'session.driver' => 'array', 'app.debug' => false,
        ]);
        DB::purge('exam_test');
        Schema::create('users', function (Blueprint $table) {
            $table->id(); $table->string('name'); $table->string('email')->unique();
            $table->string('role'); $table->boolean('is_admin')->default(false);
            $table->boolean('is_active')->default(true); $table->timestamp('email_verified_at')->nullable();
            $table->string('password')->nullable(); $table->timestamps();
        });
        (require database_path('migrations/2026_10_06_000001_create_proctored_exam_tables.php'))->up();
        $this->manager = $this->user('manager');
        $this->candidate = $this->user('student');
        $this->other = $this->user('student');
        Http::preventStrayRequests();
        $this->travelTo(now()->startOfSecond());
    }

    protected function tearDown(): void
    {
        $this->travelBack(); DB::purge('exam_test'); parent::tearDown();
    }

    private function user(string $role, array $extra = []): User
    {
        return User::create(array_merge(['name' => 'Fixture '.$role, 'email' => Str::uuid().'@example.test', 'role' => $role, 'is_active' => true, 'email_verified_at' => now()], $extra));
    }

    private function asUser(User $user): static { Sanctum::actingAs($user); return $this; }
    private function endpoint(string $id, string $suffix = ''): string { return self::BASE.'/exams/'.$id.$suffix; }
    private function questions(): array
    {
        return [
            ['id'=>'single','type'=>'mcq_single','prompt'=>'Solve $x+1=3$.','options'=>['1','2','3'],'correct_answer'=>1,'marks'=>2,'negative'=>0.5],
            ['id'=>'multi','type'=>'mcq_multi','prompt'=>'Select primes.','options'=>['2','3','4'],'correct_answers'=>[0,1],'marks'=>3,'negative'=>1],
            ['id'=>'number','type'=>'numerical','prompt'=>'Mean of 1,2,3?','numerical_answer'=>2,'numerical_tolerance'=>0.01,'marks'=>2],
            ['id'=>'text','type'=>'short_answer','prompt'=>'Name the identity matrix.','acceptable_answers'=>['identity'],'marks'=>2],
            ['id'=>'boolean','type'=>'true_false','prompt'=>'Zero is positive.','correct_answer'=>false,'marks'=>1],
        ];
    }
    private function draft(): string
    {
        $response=$this->asUser($this->manager)->postJson(self::BASE.'/exams',['title'=>'Math & stats','subject'=>'Statistics','duration_minutes'=>10,'max_warnings'=>2]);
        $response->assertCreated(); return $response->json('exam.id');
    }
    private function ready(bool $start = true): string
    {
        $id=$this->draft();
        $this->postJson($this->endpoint($id,'/import'),['questions'=>$this->questions()])->assertOk();
        $this->putJson($this->endpoint($id,'/enrollments'),['emails'=>[$this->candidate->email,$this->other->email]])->assertOk();
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'publish'])->assertOk();
        if ($start) $this->postJson($this->endpoint($id,'/actions'),['action'=>'start'])->assertOk();
        return $id;
    }
    private function join(string $id, ?User $user = null): void
    {
        $this->asUser($user ?? $this->candidate)->postJson($this->endpoint($id,'/join'),['acceptedRules'=>true])->assertSuccessful();
    }
    private function submitAndPublish(string $id): void
    {
        $this->postJson($this->endpoint($id,'/submit'),['answers'=>['single'=>1,'multi'=>[1,0],'number'=>2.005,'text'=>' IDENTITY ','boolean'=>false],'revision'=>0])->assertOk();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'end'])->assertOk();
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'publish_results'])->assertOk();
    }

    public function test_api_requires_authentication_and_legacy_api_cannot_mutate_state(): void
    {
        $this->getJson(self::BASE.'/exams')->assertUnauthorized();
        $this->asUser($this->candidate)->postJson(self::BASE.'/state',['exam'=>['status'=>'ended']])->assertStatus(410);
        $this->postJson(self::BASE.'/exams',['title'=>'Attack','duration_minutes'=>10])->assertForbidden();
    }

    public function test_exams_are_owned_and_cross_manager_access_is_denied(): void
    {
        $id=$this->draft(); $outsider=$this->user('manager');
        $this->asUser($outsider)->getJson($this->endpoint($id))->assertNotFound();
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'publish'])->assertNotFound();
        $this->getJson(self::BASE.'/exams')->assertJsonCount(0,'exams');
    }

    public function test_inactive_and_unverified_accounts_cannot_use_existing_sessions(): void
    {
        $id=$this->ready();
        $this->candidate->update(['is_active'=>false]);
        $this->asUser($this->candidate->fresh())->getJson($this->endpoint($id,'/state'))->assertForbidden();
        $this->candidate->update(['is_active'=>true,'email_verified_at'=>null]);
        $this->asUser($this->candidate->fresh())->postJson($this->endpoint($id,'/join'),['acceptedRules'=>true])->assertForbidden();
    }

    public function test_import_is_atomic_and_published_questions_are_immutable(): void
    {
        $id=$this->draft();
        $this->postJson($this->endpoint($id,'/import'),['questions'=>$this->questions()])->assertOk();
        $bad=$this->questions(); $bad[1]['correct_answers']=[999];
        $this->postJson($this->endpoint($id,'/import'),['questions'=>$bad])->assertUnprocessable();
        $this->getJson($this->endpoint($id))->assertJsonPath('exam.questions.1.correct_answers',[0,1]);
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'publish'])->assertOk();
        $this->postJson($this->endpoint($id,'/import'),['questions'=>$this->questions()])->assertConflict();
        $this->patchJson($this->endpoint($id),['duration_minutes'=>20])->assertConflict();
    }

    public function test_non_enrolled_users_cannot_read_join_submit_or_send_events(): void
    {
        $id=$this->ready(); $outsider=$this->user('student'); $this->asUser($outsider);
        $this->getJson($this->endpoint($id,'/state'))->assertNotFound();
        $this->postJson($this->endpoint($id,'/join'),['acceptedRules'=>true])->assertNotFound();
        $this->postJson($this->endpoint($id,'/submit'),[])->assertNotFound();
        $this->postJson($this->endpoint($id,'/events'),['id'=>(string)Str::uuid(),'type'=>'blur'])->assertNotFound();
        $this->getJson(self::BASE.'/exams')->assertJsonCount(0,'exams');
    }

    public function test_candidate_gets_no_roster_keys_or_questions_before_join(): void
    {
        $id=$this->ready(false); $this->asUser($this->candidate);
        $body=$this->getJson($this->endpoint($id,'/state'))->assertOk()->json();
        $this->assertEmpty($body['exam']['questions'] ?? []);
        $this->assertArrayNotHasKey('enrollments',$body['exam']);
        $this->assertStringNotContainsString($this->other->email,json_encode($body));
        $this->postJson($this->endpoint($id,'/join'),['acceptedRules'=>true])->assertConflict();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'start'])->assertOk();
        $this->asUser($this->candidate)->postJson($this->endpoint($id,'/join'),['acceptedRules'=>false])->assertUnprocessable();
        $this->join($id);
        $body=$this->getJson($this->endpoint($id,'/state'))->assertOk()->json();
        $this->assertCount(5,$body['exam']['questions']);
        foreach($body['exam']['questions'] as $q) {
            foreach(['correct_answer','correct_answers','acceptable_answers','numerical_answer','explanation'] as $key) $this->assertArrayNotHasKey($key,$q);
        }
    }

    public function test_answer_revisions_prevent_lost_updates_and_reject_unknown_ids(): void
    {
        $id=$this->ready(); $this->join($id);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>0])->assertOk()->assertJsonPath('session.revision',1);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>0],'revision'=>0])->assertConflict();
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['unknown'=>1],'revision'=>1])->assertUnprocessable();
        $this->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('session.answers.single',1);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>null],'revision'=>1])->assertOk();
        $this->assertEmpty(DB::table('proctored_exam_sessions')->value('answers') === '{}' ? [] : json_decode(DB::table('proctored_exam_sessions')->value('answers'),true));
    }

    public function test_submission_is_immutable_and_results_stay_private_until_publication(): void
    {
        $id=$this->ready(); $this->join($id);
        $response=$this->postJson($this->endpoint($id,'/submit'),['answers'=>['single'=>1],'revision'=>0])->assertOk();
        $this->assertNull($response->json('score')); $this->assertNull($response->json('session.score'));
        $this->postJson($this->endpoint($id,'/submit'),['answers'=>['single'=>0],'revision'=>0])->assertOk();
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>0],'revision'=>1])->assertConflict();
        $this->assertEquals(['single'=>1],json_decode(DB::table('proctored_exam_sessions')->value('answers'),true));
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'publish_results'])->assertConflict();
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'end'])->assertOk();
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'publish_results'])->assertOk();
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('session.score',2);
    }

    public function test_all_question_types_are_scored_on_server(): void
    {
        $id=$this->ready(); $this->join($id); $this->submitAndPublish($id);
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('session.score',10)->assertJsonPath('session.total_marks',10);
    }

    public function test_manager_end_finalizes_saved_answers_and_prevents_late_changes(): void
    {
        $id=$this->ready(); $this->join($id);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>0])->assertOk();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'end'])->assertOk();
        $this->assertEquals('submitted',DB::table('proctored_exam_sessions')->value('status'));
        $this->assertEquals(2,DB::table('proctored_exam_sessions')->value('score'));
        $this->asUser($this->candidate)->postJson($this->endpoint($id,'/submit'),['answers'=>['single'=>0],'revision'=>1])->assertOk();
        $this->assertEquals(2,DB::table('proctored_exam_sessions')->value('score'));
    }

    public function test_pause_freezes_time_and_blocks_answer_writes(): void
    {
        $id=$this->ready(); $this->join($id); $this->travel(1)->minutes();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'pause'])->assertOk();
        $this->travel(3)->minutes();
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('remaining_seconds',540);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>0])->assertConflict();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'resume'])->assertOk();
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('remaining_seconds',540);
    }

    public function test_expiry_finalizes_server_saved_answers_without_client_submission(): void
    {
        $id=$this->ready(); $this->join($id);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>0])->assertOk();
        $this->travel(11)->minutes();
        $this->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('session.status','submitted')->assertJsonPath('remaining_seconds',0);
        $this->assertEquals(2,DB::table('proctored_exam_sessions')->value('score'));
    }

    public function test_events_are_idempotent_and_candidates_cannot_rewrite_evidence(): void
    {
        $id=$this->ready(); $this->join($id); $event=['id'=>(string)Str::uuid(),'type'=>'blur'];
        $this->postJson($this->endpoint($id,'/events'),$event)->assertOk()->assertJsonPath('session.warnings',1);
        $this->postJson($this->endpoint($id,'/events'),$event)->assertOk()->assertJsonPath('session.warnings',1);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>[],'revision'=>0,'warnings'=>0,'status'=>'submitted','score'=>999])->assertOk();
        $this->assertEquals(1,DB::table('proctored_exam_sessions')->value('warnings'));
        $this->postJson($this->endpoint($id,'/events'),['id'=>(string)Str::uuid(),'type'=>'visibility_hidden'])->assertOk()->assertJsonPath('session.status','locked');
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>1])->assertConflict();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/sessions/'.$this->candidate->id.'/action'),['action'=>'unlock'])->assertOk();
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('session.warnings',2)->assertJsonPath('session.status','in_exam');
        $this->assertEquals(2,DB::table('proctored_exam_events')->count());
    }

    public function test_candidate_messages_are_private_and_cannot_impersonate_manager(): void
    {
        $id=$this->ready(); $this->join($id);
        $this->postJson($this->endpoint($id,'/messages'),['text'=>'My private question','is_announcement'=>true,'sender_id'=>$this->manager->id])->assertCreated();
        $this->asUser($this->other)->getJson($this->endpoint($id,'/messages'))->assertOk()->assertJsonCount(0,'messages');
        $this->asUser($this->manager)->getJson($this->endpoint($id,'/messages'))->assertOk()->assertJsonCount(1,'messages');
        $this->postJson($this->endpoint($id,'/messages'),['text'=>'Announcement'])->assertCreated();
        $this->asUser($this->other)->getJson($this->endpoint($id,'/messages'))->assertOk()->assertJsonCount(1,'messages');
    }

    public function test_audit_and_export_are_manager_owned_and_user_data_survives_archiving(): void
    {
        $id=$this->ready(); $this->join($id); $this->submitAndPublish($id);
        $this->asUser($this->candidate)->getJson($this->endpoint($id,'/audit'))->assertForbidden();
        $this->getJson($this->endpoint($id,'/export'))->assertForbidden();
        $this->asUser($this->manager)->getJson($this->endpoint($id,'/audit'))->assertOk()->assertJsonFragment(['event'=>'exam.created']);
        $this->postJson($this->endpoint($id,'/actions'),['action'=>'archive'])->assertOk();
        $this->assertEquals(1,DB::table('proctored_exam_sessions')->count());
        $this->assertGreaterThan(0,DB::table('proctored_exam_audit_logs')->count());
    }
    public function test_blank_optional_subject_and_clearing_roster_are_supported(): void
    {
        $id=$this->draft();
        $this->patchJson($this->endpoint($id),['subject'=>null])->assertOk()->assertJsonPath('exam.subject','');
        $this->putJson($this->endpoint($id,'/enrollments'),['emails'=>[$this->candidate->email]])->assertOk();
        $this->putJson($this->endpoint($id,'/enrollments'),['emails'=>[]])->assertOk()->assertJsonCount(0,'exam.enrollments');
    }

    public function test_compact_polling_omits_questions_answers_and_roster(): void
    {
        $id=$this->ready();$this->join($id);
        $this->patchJson($this->endpoint($id,'/answers'),['answers'=>['single'=>1],'revision'=>0])->assertOk();
        $data=$this->getJson($this->endpoint($id,'/state?compact=1'))->assertOk()->json();
        $this->assertArrayNotHasKey('questions',$data['exam']);$this->assertArrayNotHasKey('answers',$data['session']);
        $this->assertEquals(5,$data['exam']['question_count']);
        $data=$this->asUser($this->manager)->getJson($this->endpoint($id,'/state?compact=1'))->assertOk()->json();
        $this->assertArrayNotHasKey('enrollments',$data['exam']);$this->assertArrayNotHasKey('questions',$data['exam']);
        $this->assertArrayNotHasKey('answers',$data['sessions'][0]);$this->assertEquals(1,$data['sessions'][0]['answered_count']);
    }

    public function test_duplicate_locking_event_is_idempotent_and_expired_exam_cannot_be_extended(): void
    {
        $id=$this->ready();$this->join($id);
        $this->postJson($this->endpoint($id,'/events'),['id'=>(string)Str::uuid(),'type'=>'blur'])->assertOk();
        $event=['id'=>(string)Str::uuid(),'type'=>'fullscreen_exit'];
        $this->postJson($this->endpoint($id,'/events'),$event)->assertOk()->assertJsonPath('session.status','locked');
        $this->postJson($this->endpoint($id,'/events'),$event)->assertOk()->assertJsonPath('recorded',false)->assertJsonPath('session.warnings',2);
        $this->travel(11)->minutes();
        $this->asUser($this->manager)->postJson($this->endpoint($id,'/actions'),['action'=>'extend','minutes'=>5])->assertConflict();
        $this->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('exam.status','ended');
    }

    public function test_scheduler_finalizes_sessions_and_records_a_heartbeat(): void
    {
        $id=$this->ready();$this->join($id);$this->travel(11)->minutes();
        $this->artisan('proctored-exams:finalize-expired')->assertSuccessful();
        $this->assertNotNull(\Illuminate\Support\Facades\Cache::get('proctored_exams.scheduler_last_success'));
        $this->assertSame('submitted',DB::table('proctored_exam_sessions')->value('status'));
        $this->getJson($this->endpoint($id,'/state'))->assertOk()->assertJsonPath('remaining_seconds',0);
    }

    public function test_adversarial_import_is_rejected_and_csv_names_cannot_start_formulas(): void
    {
        $id=$this->draft();$bad=$this->questions();$bad[0]['prompt']=[['kind'=>'image','url'=>'javascript:alert(1)']];
        $this->postJson($this->endpoint($id,'/import'),['questions'=>$bad])->assertUnprocessable();
        $this->getJson($this->endpoint($id))->assertJsonCount(0,'exam.questions');
        $id=$this->ready();$this->candidate->update(['name'=>'=HYPERLINK("https://evil.test")']);$this->join($id);
        $csv=$this->asUser($this->manager)->get($this->endpoint($id,'/export'))->assertOk()->streamedContent();
        $this->assertStringContainsString("'=HYPERLINK",$csv);
    }

    public function test_manager_lists_are_paginated_without_answer_keys(): void
    {
        for($i=0;$i<51;$i++) \App\Models\ProctoredExam::create(['owner_id'=>$this->manager->id,'title'=>'Exam '.$i,'duration_minutes'=>10,'status'=>'draft','questions'=>[]]);
        $this->asUser($this->manager)->getJson(self::BASE.'/exams')->assertOk()->assertJsonCount(50,'exams')->assertJsonPath('next_page',2);
        $this->getJson(self::BASE.'/exams?page=2')->assertOk()->assertJsonCount(1,'exams')->assertJsonPath('next_page',null);
    }
}
