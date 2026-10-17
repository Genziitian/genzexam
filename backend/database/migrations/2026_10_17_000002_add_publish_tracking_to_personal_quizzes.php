<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            // A manager publishes a copy of a student's upload; the student keeps their private test.
            $table->unsignedBigInteger('published_quiz_id')->nullable()->after('owner_user_id');
            $table->timestamp('upload_reviewed_at')->nullable()->after('published_quiz_id');
        });
    }

    public function down(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            $table->dropColumn(['published_quiz_id', 'upload_reviewed_at']);
        });
    }
};
