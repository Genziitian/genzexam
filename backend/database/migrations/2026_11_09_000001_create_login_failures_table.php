<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('login_failures')) {
            return;
        }

        Schema::create('login_failures', function (Blueprint $table) {
            $table->id();
            $table->string('email', 191)->nullable()->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('method', 20);            // email, otp, register, google, google_app, client
            $table->string('reason', 40)->index();   // short code, e.g. wrong_password
            $table->string('message', 500)->nullable();
            $table->text('detail')->nullable();      // exception text, server status, etc.
            $table->string('source', 10)->default('server'); // server | browser
            $table->string('ip_address', 45)->nullable();
            $table->string('user_agent', 300)->nullable();
            $table->string('page', 300)->nullable();
            $table->timestamp('created_at')->useCurrent()->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('login_failures');
    }
};
