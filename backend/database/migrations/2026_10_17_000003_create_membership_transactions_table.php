<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('membership_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('pro_subscription_id')->constrained()->cascadeOnDelete();
            $table->string('provider', 32);
            $table->string('reference', 200);
            $table->string('status', 40);
            $table->bigInteger('amount_paise');
            $table->string('currency', 3);
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
            $table->unique(['provider', 'reference']);
            $table->index(['user_id', 'created_at']);
        });
    }
    public function down(): void { Schema::dropIfExists('membership_transactions'); }
};
