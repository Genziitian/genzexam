<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            // Prices are stored in paise so amounts remain exact in checkout.
            $table->unsignedInteger('price_paise')->default(0)->after('time_limit_minutes');
            $table->unsignedSmallInteger('access_days')->nullable()->after('price_paise');
        });

        Schema::create('quiz_storefront_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('quiz_id')->constrained()->restrictOnDelete();
            $table->string('razorpay_order_id')->nullable()->unique();
            $table->string('razorpay_payment_id')->nullable()->unique();
            $table->unsignedInteger('amount_paise');
            $table->unsignedSmallInteger('access_days')->nullable();
            $table->string('currency', 3)->default('INR');
            $table->string('status', 24)->default('created');
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });

        Schema::create('quiz_entitlements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('quiz_id')->constrained()->cascadeOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('quiz_storefront_orders')->nullOnDelete();
            $table->string('source', 20); // free_claim, purchase, or manager_grant
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'quiz_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quiz_entitlements');
        Schema::dropIfExists('quiz_storefront_orders');

        Schema::table('quizzes', function (Blueprint $table) {
            $table->dropColumn(['price_paise', 'access_days']);
        });
    }
};
