<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@labbygenziitian.com'],
            [
                'name' => 'Quiz Lab Manager',
                'password' => bcrypt('Admin@123'),
                'role' => \App\Models\User::ROLE_MANAGER,
                'email_verified_at' => now(),
                'is_active' => true,
            ]
        );
    }
}
