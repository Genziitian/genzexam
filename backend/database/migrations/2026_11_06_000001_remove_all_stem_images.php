<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        DB::table('questions')
            ->whereNotNull('stem_image')
            ->update([
                'stem_image' => null,
            ]);
    }

    public function down(): void
    {
    }
};
