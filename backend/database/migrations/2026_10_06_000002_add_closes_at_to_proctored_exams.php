<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('proctored_exams', function (Blueprint $table) {
            // Optional hard closing time for the exam.
            $table->timestamp('closes_at')->nullable()->after('scheduled_at');
        });
    }

    public function down(): void
    {
        Schema::table('proctored_exams', function (Blueprint $table) {
            $table->dropColumn('closes_at');
        });
    }
};
