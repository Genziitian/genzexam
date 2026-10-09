<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pro_plan_settings', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('price_paise')->default(9900);
            $table->unsignedInteger('google_play_price_paise')->nullable();
            $table->string('razorpay_plan_id')->nullable();
            $table->unsignedSmallInteger('trial_days')->default(7);
            $table->boolean('enabled')->default(true);
            $table->timestamps();
        });

        Schema::create('pro_subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('provider', 24)->default('manual'); // google_play, razorpay, manual
            $table->string('provider_subscription_id')->nullable()->unique();
            $table->string('provider_reference_hash', 64)->nullable()->unique();
            $table->text('google_purchase_token')->nullable();
            $table->string('product_id')->nullable();
            $table->text('checkout_url')->nullable();
            $table->string('status', 24)->default('active'); // trialing, active, cancelled, expired, revoked
            $table->unsignedInteger('amount_paise')->default(9900);
            $table->string('currency', 3)->default('INR');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('trial_ends_at')->nullable();
            $table->timestamp('current_period_ends_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->boolean('cancel_at_period_end')->default(false);
            $table->string('cancellation_source', 24)->nullable(); // user, manager, provider
            $table->timestamps();
            $table->index(['status', 'current_period_ends_at']);
            $table->index(['user_id', 'status']);
        });

        DB::table('pro_plan_settings')->insert([
            'price_paise' => 9900,
            'trial_days' => 7,
            'enabled' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('pro_subscriptions');
        Schema::dropIfExists('pro_plan_settings');
    }
};
