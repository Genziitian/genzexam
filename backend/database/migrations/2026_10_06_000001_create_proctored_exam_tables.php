<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('proctored_exams', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('owner_id')->constrained('users')->restrictOnDelete();
            $table->string('title', 200);
            $table->string('subject', 200)->default('');
            $table->text('instructions')->nullable();
            $table->unsignedSmallInteger('duration_minutes');
            $table->unsignedSmallInteger('extension_minutes')->default(0);
            $table->unsignedSmallInteger('max_warnings')->default(3);
            $table->timestamp('scheduled_at')->nullable();
            $table->string('status', 24)->default('draft');
            $table->boolean('results_published')->default(false);
            $table->json('questions')->nullable();
            $table->unsignedSmallInteger('question_count')->default(0);
            $table->timestamp('started_at')->nullable();
            $table->timestamp('paused_at')->nullable();
            $table->unsignedInteger('paused_seconds')->default(0);
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();
            $table->index(['owner_id', 'status']);
        });

        Schema::create('proctored_exam_enrollments', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('exam_id')->constrained('proctored_exams')->cascadeOnDelete();
            $table->string('email', 254);
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('added_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['exam_id', 'email']);
            $table->unique(['exam_id', 'user_id']);
            $table->index(['email', 'exam_id']);
        });

        Schema::create('proctored_exam_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('exam_id')->constrained('proctored_exams')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->string('status', 24)->default('not_started');
            $table->unsignedSmallInteger('warnings')->default(0);
            $table->unsignedSmallInteger('warning_allowance')->default(0);
            $table->unsignedInteger('revision')->default(0);
            $table->json('answers')->nullable();
            $table->decimal('score', 10, 2)->nullable();
            $table->decimal('total_marks', 10, 2)->nullable();
            $table->json('score_breakdown')->nullable();
            $table->timestamp('joined_at')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamps();
            $table->unique(['exam_id', 'user_id']);
            $table->index(['exam_id', 'status']);
        });

        Schema::create('proctored_exam_events', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('exam_id')->constrained('proctored_exams')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->uuid('client_event_id');
            $table->string('type', 40);
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->unique(['exam_id', 'user_id', 'client_event_id'], 'proctored_event_dedupe');
            $table->index(['exam_id', 'user_id', 'occurred_at']);
        });

        Schema::create('proctored_exam_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('exam_id')->constrained('proctored_exams')->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->restrictOnDelete();
            $table->string('text', 2000);
            $table->boolean('is_announcement')->default(false);
            $table->timestamps();
            $table->index(['exam_id', 'created_at']);
        });

        Schema::create('proctored_exam_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('exam_id')->constrained('proctored_exams')->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event', 80);
            $table->json('details')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->index(['exam_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('proctored_exam_audit_logs');
        Schema::dropIfExists('proctored_exam_messages');
        Schema::dropIfExists('proctored_exam_events');
        Schema::dropIfExists('proctored_exam_sessions');
        Schema::dropIfExists('proctored_exam_enrollments');
        Schema::dropIfExists('proctored_exams');
    }
};
