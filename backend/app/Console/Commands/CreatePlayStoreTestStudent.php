<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreatePlayStoreTestStudent extends Command
{
    protected $signature = 'playstore:create-test-student';

    protected $description = 'Create a verified student account for Google Play review';

    public function handle(): int
    {
        $email = 'test.student@gmail.com';

        if (User::query()->where('email', $email)->exists()) {
            $this->error("{$email} is already registered. No account or password was changed.");

            return self::FAILURE;
        }

        $password = (string) random_int(10_000_000, 99_999_999);

        User::create([
            'name' => 'Play Store Test Student',
            'email' => $email,
            'password' => Hash::make($password),
            'email_verified_at' => now(),
            'is_admin' => false,
            'is_pro' => false,
            'is_active' => true,
            'role' => User::ROLE_STUDENT,
        ]);

        $this->newLine();
        $this->info('Play Store student account created. Save these credentials in Play Console:');
        $this->line('Email: '.$email);
        $this->line('Password: '.$password);
        $this->newLine();
        $this->warn('This password is shown only once. Do not share it publicly or commit it to source control.');

        return self::SUCCESS;
    }
}
