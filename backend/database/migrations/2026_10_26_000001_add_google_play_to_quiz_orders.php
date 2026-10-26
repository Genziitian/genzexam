<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('quiz_storefront_orders', function (Blueprint $table) {
            $table->string('provider', 20)->default('razorpay')->after('currency');
            $table->string('google_token_hash', 64)->nullable()->unique()->after('provider');
            $table->string('google_order_id')->nullable()->unique()->after('google_token_hash');
        });
    }

    public function down(): void
    {
        Schema::table('quiz_storefront_orders', function (Blueprint $table) {
            $table->dropColumn(['provider', 'google_token_hash', 'google_order_id']);
        });
    }
};
