<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

/** Google profile-picture links can be longer than 255 characters. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->text('avatar')->nullable()->change();
        });
        Cache::forget('users_avatar_limit');
    }

    public function down(): void
    {
        // Not narrowed back: that would truncate stored links.
    }
};
