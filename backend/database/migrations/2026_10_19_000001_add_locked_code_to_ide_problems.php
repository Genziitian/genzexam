<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ide_problems', function (Blueprint $table) {
            // Read-only code shown in grey above/below the editable area. The runner executes prefix + student code + suffix.
            $table->text('prefix_code')->nullable()->after('sample_output');
            $table->text('starter_code')->nullable()->after('prefix_code');
            $table->text('suffix_code')->nullable()->after('starter_code');
        });
    }

    public function down(): void
    {
        Schema::table('ide_problems', function (Blueprint $table) {
            $table->dropColumn(['prefix_code', 'starter_code', 'suffix_code']);
        });
    }
};
