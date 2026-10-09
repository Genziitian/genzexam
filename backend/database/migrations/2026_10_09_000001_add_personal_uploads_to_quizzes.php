<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            $table->boolean('is_personal')->default(false)->after('reviewed_at');
            $table->foreignId('owner_user_id')->nullable()->after('is_personal')
                ->constrained('users')->cascadeOnDelete();
            $table->index(['is_personal', 'owner_user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            $table->dropIndex(['is_personal', 'owner_user_id']);
            $table->dropConstrainedForeignId('owner_user_id');
            $table->dropColumn('is_personal');
        });
    }
};
