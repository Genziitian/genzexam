<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('google_play_notifications', function (Blueprint $table) {
            $table->id();
            $table->string('message_id', 200)->unique();
            $table->string('kind', 24);
            $table->unsignedSmallInteger('notification_type')->nullable();
            $table->string('purchase_token_hash', 64)->nullable();
            $table->string('status', 24)->default('pending');
            $table->unsignedInteger('attempts')->default(0);
            $table->string('last_error', 100)->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('google_play_notifications');
    }
};
