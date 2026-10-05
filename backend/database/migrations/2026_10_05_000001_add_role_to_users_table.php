<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->enum('role', ['student', 'admin', 'manager'])
                ->default('student')
                ->after('is_admin');
        });

        // Everyone who was an admin stays an admin.
        DB::table('users')->where('is_admin', true)->update(['role' => 'admin']);

        // Bootstrap a single manager so the top tier is reachable: the
        // longest-standing admin account is promoted. Without this nobody
        // could ever grant the manager role.
        $firstAdmin = DB::table('users')->where('is_admin', true)->orderBy('id')->first();
        if ($firstAdmin) {
            DB::table('users')->where('id', $firstAdmin->id)->update(['role' => 'manager']);
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('role');
        });
    }
};
