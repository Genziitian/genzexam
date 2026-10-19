<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('question_reports', function (Blueprint $table) {
            // IDE problems are reported through the same table and manager page as quiz questions.
            $table->foreignId('ide_problem_id')->nullable()->after('quiz_id')->constrained('ide_problems')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('question_reports', function (Blueprint $table) {
            $table->dropConstrainedForeignId('ide_problem_id');
        });
    }
};
