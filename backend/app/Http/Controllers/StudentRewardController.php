<?php

namespace App\Http\Controllers;

use App\Models\ProSubscription;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class StudentRewardController extends Controller
{
    private const SECTOR_COUNT = 8;
    private const EXPIRY_DAYS = 7;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthenticated'], 401);
        }

        $quota = $this->dailyQuota($user);
        $rewards = $this->getUserRewards($user);

        return response()->json([
            'quota' => $quota,
            'rewards' => $rewards,
        ]);
    }

    public function spin(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthenticated'], 401);
        }

        $quota = $this->dailyQuota($user);
        if ($quota['remaining'] <= 0) {
            return response()->json([
                'error' => 'You have already spun today. Come back tomorrow after midnight IST!',
                'quota' => $quota,
            ], 429);
        }

        // 10 Wheel Slices:
        // 0: 5% OFF (Upto ₹50) (18%)
        // 1: 30 Days Free Pro Plan (8%)
        // 2: ₹50 OFF Coupon (10%)
        // 3: Better Luck Next Time (9%)
        // 4: 25% OFF Coupon (8%)
        // 5: 1 Free Extra Spin (10%)
        // 6: ₹100 OFF Coupon (5%)
        // 7: 50 Bonus XP (12%)
        // 8: Free 1 Test Yourself (10%)
        // 9: Free 1 Paper Upload (10%)
        $prizes = [
            0 => ['type' => 'coupon_pct',          'title' => '5% OFF (Upto ₹50)',      'value' => '5% OFF (Upto ₹50)', 'prefix' => 'GENZ5-'],
            1 => ['type' => 'free_pro',            'title' => '30 Days Free Pro',       'value' => '30 Days Pro',       'prefix' => ''],
            2 => ['type' => 'coupon_flat',         'title' => '₹50 OFF Coupon',         'value' => '₹50 OFF',           'prefix' => 'GENZ50-'],
            3 => ['type' => 'try_again',           'title' => 'Better Luck Next Time',  'value' => 'Try Tomorrow',      'prefix' => ''],
            4 => ['type' => 'coupon_pct',          'title' => '25% OFF Coupon',         'value' => '25% OFF',           'prefix' => 'GENZ25-'],
            5 => ['type' => 'free_spin',           'title' => '1 Free Extra Spin',      'value' => '1 Extra Spin',      'prefix' => ''],
            6 => ['type' => 'coupon_flat',         'title' => '₹100 OFF Coupon',        'value' => '₹100 OFF',          'prefix' => 'GENZ100-'],
            7 => ['type' => 'bonus_xp',            'title' => '+50 Study XP',           'value' => '50 XP',             'prefix' => ''],
            8 => ['type' => 'free_test',           'title' => 'Free 1 Test Yourself',   'value' => '1 Free Test',       'prefix' => 'TEST1-'],
            9 => ['type' => 'free_paper_upload',   'title' => 'Free 1 Paper Upload',   'value' => '1 Free Upload',     'prefix' => 'UPLOAD1-'],
        ];

        // Weighted probabilities (Sum = 100%):
        $weights = [
            0 => 18, // 5% OFF (Upto ₹50) - 18% (#1 most common)
            1 => 8,  // 30 Days Free Pro - 8%
            2 => 10, // ₹50 OFF Coupon - 10%
            3 => 9,  // Better Luck Next Time - 9%
            4 => 8,  // 25% OFF Coupon - 8%
            5 => 10, // 1 Free Extra Spin - 10%
            6 => 5,  // ₹100 OFF Coupon - 5% (super rare)
            7 => 12, // +50 XP - 12% (#2 most common)
            8 => 10, // Free 1 Test Yourself - 10%
            9 => 10, // Free 1 Paper Upload - 10%
        ];

        $rand = mt_rand(1, array_sum($weights));
        $cumulative = 0;
        $segment = 0;
        foreach ($weights as $idx => $w) {
            $cumulative += $w;
            if ($rand <= $cumulative) {
                $segment = $idx;
                break;
            }
        }

        $prizeData = $prizes[$segment];
        $now = now();
        $reward = null;

        if ($prizeData['type'] !== 'try_again') {
            $isInApp = in_array($prizeData['type'], ['free_test', 'free_paper_upload', 'free_pro', 'free_spin', 'bonus_xp'], true);
            $code = (!$isInApp && $prizeData['prefix']) ? $prizeData['prefix'] . strtoupper(Str::random(4)) : null;
            $reward = [
                'id' => (string) Str::uuid(),
                'type' => $prizeData['type'],
                'title' => $prizeData['title'],
                'value' => $prizeData['value'],
                'code' => $code,
                'created_at' => $now->toIso8601String(),
                'expires_at' => in_array($prizeData['type'], ['coupon_pct', 'coupon_flat'], true)
                    ? $now->copy()->addDays(self::EXPIRY_DAYS)->toIso8601String()
                    : null,
                'is_scratched' => false,
                'is_claimed' => in_array($prizeData['type'], ['free_spin', 'bonus_xp', 'free_test', 'free_paper_upload'], true),
            ];

            // If bonus XP: immediately add to user
            if ($prizeData['type'] === 'bonus_xp' && isset($user->xp)) {
                $user->increment('xp', 50);
            }

            // If free test yourself spin: grant +1 bonus spin directly
            if ($prizeData['type'] === 'free_test') {
                Cache::increment('user_bonus_spins_'.$user->id, 1);
            }

            // If free paper upload: grant +1 bonus upload directly
            if ($prizeData['type'] === 'free_paper_upload') {
                Cache::increment('user_bonus_uploads_'.$user->id, 1);
            }

            $this->saveUserReward($user, $reward);
        }

        // Record spin usage for today (unless user won a Free Extra Spin!)
        if ($prizeData['type'] !== 'free_spin') {
            $this->markSpunToday($user);
        }

        // Record to active manager rewards log
        $this->logSpinResult($user, $prizeData, $reward, $now);

        return response()->json([
            'segment' => $segment,
            'reward' => $reward,
            'prize' => $prizeData,
            'quota' => $this->dailyQuota($user),
        ]);
    }

    public function claimPro(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthenticated'], 401);
        }

        $now = now();
        $subscription = ProSubscription::create([
            'user_id' => $user->id,
            'provider' => 'reward',
            'status' => 'active',
            'amount_paise' => 0,
            'currency' => 'INR',
            'started_at' => $now,
            'current_period_ends_at' => $now->copy()->addDays(30),
        ]);

        $user->update(['is_pro' => true]);

        // Mark any unclaimed pro reward as claimed
        $rewards = $this->getUserRewards($user);
        foreach ($rewards as &$r) {
            if ($r['type'] === 'free_pro' && empty($r['is_claimed'])) {
                $r['is_claimed'] = true;
                $r['claimed_at'] = $now->toIso8601String();
            }
        }
        $this->setUserRewards($user, $rewards);
        $this->updateLogProClaim($user);

        return response()->json([
            'success' => true,
            'message' => '30 Days Free Pro plan activated successfully!',
            'is_pro' => true,
            'current_period_ends_at' => $subscription->current_period_ends_at->toIso8601String(),
        ]);
    }

    public function scratch(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthenticated'], 401);
        }

        $id = (string) $request->input('id');
        $rewards = $this->getUserRewards($user);
        $found = false;

        foreach ($rewards as &$r) {
            if (($r['id'] ?? '') === $id) {
                $r['is_scratched'] = true;
                $r['scratched_at'] = now()->toIso8601String();
                $found = true;
                break;
            }
        }

        if ($found) {
            $this->setUserRewards($user, $rewards);
            $this->updateLogScratch($id);
        }

        return response()->json(['success' => true, 'id' => $id]);
    }

    private function dailyQuota(User $user): array
    {
        $day = now('Asia/Kolkata')->startOfDay();
        $cacheKey = "user_daily_reward_spin_{$user->id}_{$day->format('Y-m-d')}";
        $used = Cache::has($cacheKey) ? 1 : 0;
        $resetsAt = $day->copy()->addDay()->toIso8601String();

        return [
            'limit' => 1,
            'used' => $used,
            'remaining' => max(0, 1 - $used),
            'resets_at' => $resetsAt,
            'timezone' => 'Asia/Kolkata',
            'is_pro' => $user->hasProAccess(),
        ];
    }

    private function markSpunToday(User $user): void
    {
        $day = now('Asia/Kolkata')->startOfDay();
        $cacheKey = "user_daily_reward_spin_{$user->id}_{$day->format('Y-m-d')}";
        $seconds = max(60, now()->diffInSeconds($day->copy()->addDay()));
        Cache::put($cacheKey, 1, $seconds);
    }

    private function getUserRewards(User $user): array
    {
        $raw = Cache::get("user_rewards_list_{$user->id}", []);
        $now = now();

        // Calculate expiration and status for each reward
        return array_values(array_map(function ($r) use ($now) {
            $isExpired = false;
            if (! empty($r['expires_at'])) {
                $isExpired = $now->greaterThan(\Carbon\Carbon::parse($r['expires_at']));
            }
            $r['is_expired'] = $isExpired;
            if ($isExpired) {
                // If scratched and expired: code is masked
                $r['code_masked'] = '••••••••';
            }
            return $r;
        }, (array) $raw));
    }

    private function saveUserReward(User $user, array $reward): void
    {
        $list = $this->getUserRewards($user);
        array_unshift($list, $reward);
        $this->setUserRewards($user, $list);
    }

    private function setUserRewards(User $user, array $rewards): void
    {
        Cache::put("user_rewards_list_{$user->id}", $rewards, now()->addYear());
    }

    public function managerLog(Request $request): JsonResponse
    {
        $log = (array) Cache::get('manager_rewards_log', []);
        $now = now();
        $enriched = array_map(function ($row) use ($now) {
            $isExpired = false;
            if (!empty($row['expires_at'])) {
                $isExpired = $now->greaterThan(\Carbon\Carbon::parse($row['expires_at']));
            }
            $row['is_expired'] = $isExpired;
            if ($isExpired && !in_array($row['status'], ['Try Again', 'Claimed (+50 XP)'], true)) {
                $row['status'] = 'Expired';
            }
            return $row;
        }, $log);

        $totalSpins = count($enriched);
        $activeCoupons = count(array_filter($enriched, function ($r) {
            return in_array($r['prize_type'] ?? '', ['coupon_pct', 'coupon_flat'], true) && empty($r['is_expired']);
        }));
        $proWins = count(array_filter($enriched, function ($r) {
            return ($r['prize_type'] ?? '') === 'free_pro';
        }));
        $totalXp = array_sum(array_map(function ($r) {
            return ($r['prize_type'] ?? '') === 'bonus_xp' ? 50 : 0;
        }, $enriched));

        return response()->json([
            'log' => array_values($enriched),
            'metrics' => [
                'total_spins' => $totalSpins,
                'active_coupons' => $activeCoupons,
                'pro_wins' => $proWins,
                'total_xp' => $totalXp,
            ],
        ]);
    }

    private function logSpinResult(User $user, array $prizeData, ?array $reward, \Carbon\Carbon $now): void
    {
        $log = (array) Cache::get('manager_rewards_log', []);
        $status = 'Unscratched';
        if ($prizeData['type'] === 'try_again') {
            $status = 'Try Again';
        } elseif ($prizeData['type'] === 'bonus_xp') {
            $status = 'Claimed (+50 XP)';
        } elseif ($prizeData['type'] === 'free_spin') {
            $status = 'Free Spin Won';
        } elseif ($prizeData['type'] === 'free_pro') {
            $status = 'Unclaimed Pro';
        } elseif ($prizeData['type'] === 'free_test') {
            $status = 'Test Pass Won';
        } elseif ($prizeData['type'] === 'free_paper_upload') {
            $status = 'Upload Pass Won';
        }

        $entry = [
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'user_name' => $user->name ?: ('Student #' . $user->id),
            'user_email' => $user->email,
            'prize_title' => $prizeData['title'],
            'prize_type' => $prizeData['type'],
            'prize_value' => $prizeData['value'],
            'coupon_code' => $reward['code'] ?? null,
            'reward_id' => $reward['id'] ?? null,
            'created_at' => $now->toIso8601String(),
            'expires_at' => $reward['expires_at'] ?? null,
            'is_scratched' => false,
            'is_claimed' => !empty($reward['is_claimed']),
            'status' => $status,
        ];

        array_unshift($log, $entry);
        if (count($log) > 500) {
            $log = array_slice($log, 0, 500);
        }
        Cache::put('manager_rewards_log', $log, now()->addYear());
    }

    private function updateLogScratch(string $rewardId): void
    {
        $log = (array) Cache::get('manager_rewards_log', []);
        foreach ($log as &$row) {
            if (($row['reward_id'] ?? '') === $rewardId) {
                $row['is_scratched'] = true;
                $row['status'] = 'Active (Scratched)';
                $row['scratched_at'] = now()->toIso8601String();
                break;
            }
        }
        Cache::put('manager_rewards_log', $log, now()->addYear());
    }

    private function updateLogProClaim(User $user): void
    {
        $log = (array) Cache::get('manager_rewards_log', []);
        foreach ($log as &$row) {
            if (($row['user_id'] ?? null) === $user->id && ($row['prize_type'] ?? '') === 'free_pro' && empty($row['is_claimed'])) {
                $row['is_claimed'] = true;
                $row['status'] = 'Pro Claimed';
                $row['claimed_at'] = now()->toIso8601String();
                break;
            }
        }
        Cache::put('manager_rewards_log', $log, now()->addYear());
    }
}
