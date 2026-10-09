<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class RazorpayProSubscriptions
{
    private function request()
    {
        $key = (string) config('services.razorpay.key_id');
        $secret = (string) config('services.razorpay.key_secret');
        if ($key === '' || $secret === '') throw new RuntimeException('Razorpay subscription keys are not configured.');
        return Http::withBasicAuth($key, $secret)->acceptJson()->connectTimeout(5)->timeout(20);
    }

    public function createPlan(int $amountPaise): string
    {
        $response = $this->request()->post('https://api.razorpay.com/v1/plans', [
            'period' => 'monthly',
            'interval' => 1,
            'item' => ['name' => 'Quiz LAB Pro', 'amount' => $amountPaise, 'currency' => 'INR', 'description' => 'Quiz LAB Pro monthly membership'],
        ]);
        if (! $response->successful() || ! $response->json('id')) throw new RuntimeException('Razorpay could not create the monthly Pro plan.');
        return (string) $response->json('id');
    }

    public function createSubscription(string $planId, int $trialDays, int $userId, string $email): array
    {
        $now = now();
        $startAt = $now->copy()->addDays($trialDays)->timestamp;
        $response = $this->request()->post('https://api.razorpay.com/v1/subscriptions', [
            'plan_id' => $planId,
            'total_count' => 120,
            'quantity' => 1,
            'customer_notify' => 0,
            'start_at' => $startAt,
            'expire_by' => $now->copy()->addHours(1)->timestamp,
            'notes' => ['quiz_lab_user_id' => (string) $userId, 'product' => 'quiz_lab_pro'],
        ]);
        if (! $response->successful() || ! $response->json('id') || ! $response->json('short_url')) throw new RuntimeException('Razorpay could not create a secure checkout link.');
        return [...$response->json(), 'trial_days' => $trialDays, 'email' => $email];
    }

    public function cancel(string $subscriptionId, bool $atCycleEnd = true): array
    {
        $response = $this->request()->post('https://api.razorpay.com/v1/subscriptions/'.rawurlencode($subscriptionId).'/cancel', ['cancel_at_cycle_end' => $atCycleEnd ? 1 : 0]);
        if (! $response->successful()) throw new RuntimeException('Razorpay could not cancel this subscription renewal.');
        return $response->json();
    }

    public function verifyWebhook(string $payload, string $signature): bool
    {
        $secret = (string) config('services.razorpay.webhook_secret');
        if ($secret === '' || $signature === '') return false;
        return hash_equals(hash_hmac('sha256', $payload, $secret), $signature);
    }
}
