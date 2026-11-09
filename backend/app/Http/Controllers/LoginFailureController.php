<?php

namespace App\Http\Controllers;

use App\Models\LoginFailure;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LoginFailureController extends Controller
{
    public const REASONS = [
        'no_account' => 'No account with this email',
        'wrong_password' => 'Wrong password',
        'google_only_account' => 'Account made with Google, tried a password',
        'not_verified' => 'Email never verified (OTP not completed)',
        'deactivated' => 'Account deactivated',
        'otp_wrong' => 'Wrong OTP',
        'otp_expired' => 'OTP expired',
        'otp_email_failed' => 'OTP email could not be sent',
        'rate_limited' => 'Too many attempts (blocked by rate limit)',
        'validation' => 'Form rejected (bad email / empty field)',
        'google_cancelled' => 'Cancelled on the Google screen',
        'google_error' => 'Google returned an error',
        'google_exception' => 'Google sign-in crashed on the server',
        'google_unreachable' => 'Server could not reach Google',
        'token_invalid' => 'Google token rejected (app)',
        'bad_id_token' => 'App sent a broken Google token',
        'server_config' => 'Server is missing Google settings',
        'network_error' => 'Phone/browser could not reach the server',
        'server_error' => 'Server error (5xx)',
        'callback_failed' => 'Google return page failed in the browser',
        'profile_failed' => 'Signed in, but loading the profile failed',
        'other' => 'Other',
    ];

    /** Public: the browser reports failures the server never saw (no network, 5xx, return page errors). */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['nullable', 'string', 'max:191'],
            'method' => ['nullable', 'string', 'max:20'],
            'reason' => ['required', 'string', 'max:40'],
            'message' => ['nullable', 'string', 'max:500'],
            'detail' => ['nullable', 'string', 'max:2000'],
            'page' => ['nullable', 'string', 'max:300'],
        ]);

        $reason = array_key_exists($data['reason'], self::REASONS) ? $data['reason'] : 'other';
        $email = isset($data['email']) && filter_var($data['email'], FILTER_VALIDATE_EMAIL) ? $data['email'] : null;
        $user = $email ? User::where('email', $email)->first() : null;
        $method = preg_replace('/[^a-z_]/', '', strtolower((string) ($data['method'] ?? 'client'))) ?: 'client';

        LoginFailure::record($method, $reason, $email, $user, $data['message'] ?? null,
            ($reason === 'other' ? '['.$data['reason'].'] ' : '').($data['detail'] ?? ''), 'browser', $data['page'] ?? null);

        return response()->json(['ok' => true], 202);
    }

    /** Manager: recent failures, counts by reason and the emails failing most. */
    public function index(Request $request): JsonResponse
    {
        $days = max(1, min(90, (int) $request->query('days', 7)));
        $since = now()->subDays($days);
        $base = LoginFailure::query()->where('created_at', '>=', $since);

        if ($reason = (string) $request->query('reason', '')) {
            $base->where('reason', $reason);
        }
        if ($method = (string) $request->query('method', '')) {
            $base->where('method', $method);
        }
        if ($q = trim((string) $request->query('q', ''))) {
            $base->where(function ($w) use ($q) {
                $w->where('email', 'like', '%'.$q.'%')->orWhere('ip_address', 'like', '%'.$q.'%')->orWhere('message', 'like', '%'.$q.'%');
            });
        }

        $rows = (clone $base)->orderByDesc('id')->limit(500)->get();
        $userIds = $rows->pluck('user_id')->filter()->unique();
        $users = User::whereIn('id', $userIds)->get(['id', 'name', 'email', 'google_id', 'password', 'email_verified_at', 'is_active', 'created_at'])->keyBy('id');

        $byReason = (clone $base)->select('reason', DB::raw('count(*) as n'))->groupBy('reason')->orderByDesc('n')->pluck('n', 'reason');
        $byMethod = (clone $base)->select('method', DB::raw('count(*) as n'))->groupBy('method')->orderByDesc('n')->pluck('n', 'method');
        $topEmails = (clone $base)->whereNotNull('email')->select('email', DB::raw('count(*) as n'), DB::raw('max(created_at) as last_at'))
            ->groupBy('email')->orderByDesc('n')->limit(15)->get();

        return response()->json([
            'days' => $days,
            'total' => array_sum($byReason->all()),
            'reasons' => self::REASONS,
            'by_reason' => $byReason,
            'by_method' => $byMethod,
            'top_emails' => $topEmails,
            'failures' => $rows->map(function (LoginFailure $f) use ($users) {
                $u = $f->user_id ? $users->get($f->user_id) : null;

                return [
                    'id' => $f->id,
                    'at' => $f->created_at?->toIso8601String(),
                    'email' => $f->email,
                    'method' => $f->method,
                    'reason' => $f->reason,
                    'message' => $f->message,
                    'detail' => $f->detail,
                    'source' => $f->source,
                    'ip' => $f->ip_address,
                    'user_agent' => $f->user_agent,
                    'page' => $f->page,
                    'user' => $u ? [
                        'id' => $u->id,
                        'name' => $u->name,
                        'has_password' => (bool) $u->password,
                        'has_google' => (bool) $u->google_id,
                        'verified' => (bool) $u->email_verified_at,
                        'active' => (bool) $u->is_active,
                        'joined' => $u->created_at?->toIso8601String(),
                    ] : null,
                ];
            })->values(),
        ]);
    }
}
