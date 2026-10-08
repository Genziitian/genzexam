<?php

namespace App\Http\Controllers;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Mail\OtpMail;
use App\Models\LoginLog;
use App\Models\User;
use App\Services\OtpService;
use App\Services\XpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Laravel\Socialite\Facades\Socialite;
use Throwable;

class AuthController extends Controller
{
    public function __construct(private readonly OtpService $otpService)
    {
    }

    public function register(RegisterRequest $request): JsonResponse
    {
        $validated = $request->validated();

        $existingUser = User::where('email', $validated['email'])->first();

        if ($existingUser && $existingUser->email_verified_at) {
            return response()->json([
                'error' => 'Email already registered',
            ], 422);
        }

        if ($existingUser && ! $existingUser->email_verified_at) {
            $existingUser->update([
                'name' => $validated['name'],
                'password' => bcrypt($validated['password']),
            ]);

            $otp = $this->otpService->generate();
            $this->otpService->store($existingUser, $otp);
            Mail::to($existingUser->email)->send(new OtpMail($otp, $existingUser->name));

            return response()->json([
                'message' => 'Account exists but is unverified. OTP resent successfully.',
                'email' => $existingUser->email,
            ]);
        }

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => bcrypt($validated['password']),
            'email_verified_at' => null,
        ]);

        $otp = $this->otpService->generate();
        $this->otpService->store($user, $otp);
        Mail::to($user->email)->send(new OtpMail($otp, $user->name));

        return response()->json([
            'message' => 'Registration successful. Please check your email for the OTP.',
            'email' => $user->email,
        ], 201);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'otp' => ['required', 'digits:6'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        if (! $this->otpService->verify($user, $validated['otp'])) {
            return response()->json(['error' => 'Invalid or expired OTP'], 422);
        }

        $user->update([
            'email_verified_at' => now(),
        ]);

        $this->otpService->clear($user);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_admin' => $user->is_admin,
                'role' => $user->role,
                'avatar' => $user->avatar,
            ],
        ]);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $validated = $request->validated();

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        if (! $user->email_verified_at) {
            return response()->json([
                'error' => 'Please verify your email first.',
                'needs_verification' => true,
                'email' => $user->email,
            ], 403);
        }

        if (! $user->is_active) {
            return response()->json([
                'error' => 'Your account has been deactivated.',
            ], 403);
        }

        if (! Hash::check($validated['password'], (string) $user->password)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        $user->tokens()->delete();
        $token = $user->createToken('auth_token')->plainTextToken;

        LoginLog::create([
            'user_id'      => $user->id,
            'user_agent'   => substr((string) request()->userAgent(), 0, 300),
            'auth_method'  => 'email',
            'logged_in_at' => now(),
        ]);

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_admin' => $user->is_admin,
                'role' => $user->role,
                'avatar' => $user->avatar,
            ],
        ]);
    }

    public function resendOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        if ($user->email_verified_at) {
            return response()->json(['error' => 'Email already verified'], 422);
        }

        if ($user->otp_expires_at) {
            if ($user->otp_expires_at->greaterThan(now()->addMinutes(9))) {
                return response()->json(['error' => 'Please wait before requesting another OTP'], 429);
            }
        }

        $otp = $this->otpService->generate();
        $this->otpService->store($user, $otp);
        Mail::to($user->email)->send(new OtpMail($otp, $user->name));

        return response()->json(['message' => 'OTP resent successfully']);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        if (! $user->email_verified_at) {
            return response()->json(['error' => 'Please verify your email first'], 422);
        }

        if (! $user->is_active) {
            return response()->json(['error' => 'Your account has been deactivated.'], 403);
        }

        if ($user->otp_expires_at && $user->otp_expires_at->greaterThan(now()->addMinutes(9))) {
            return response()->json(['error' => 'Please wait before requesting another OTP'], 429);
        }

        $otp = $this->otpService->generate();
        $this->otpService->store($user, $otp);
        Mail::to($user->email)->send(new OtpMail($otp, $user->name));

        return response()->json(['message' => 'Password reset OTP sent successfully']);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'otp' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'password_confirmation' => ['required'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        if (! $this->otpService->verify($user, $validated['otp'])) {
            return response()->json(['error' => 'Invalid or expired OTP'], 422);
        }

        $user->update([
            'password' => bcrypt($validated['password']),
        ]);

        $this->otpService->clear($user);
        $user->tokens()->delete();

        return response()->json(['message' => 'Password reset successfully. Please login again.']);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        if (! $user->password) {
            return response()->json([
                'error' => 'Password login is not enabled for this account. Use forgot password to set one.',
            ], 422);
        }

        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'different:current_password'],
            'password_confirmation' => ['required'],
        ]);

        if (! Hash::check($validated['current_password'], (string) $user->password)) {
            return response()->json(['error' => 'Current password is incorrect'], 422);
        }

        $user->update([
            'password' => bcrypt($validated['password']),
        ]);

        $currentTokenId = $user->currentAccessToken()?->id;
        $user->tokens()->when($currentTokenId, fn ($query) => $query->where('id', '!=', $currentTokenId))->delete();

        return response()->json(['message' => 'Password changed successfully']);
    }

    /*
     * Home-screen apps on iPhone run Google sign-in in a separate browser sheet that has its own
     * storage, so the app never sees the token. Such an app sends a random handoff id here; the
     * id travels through Google as the OAuth state, the callback parks the login under it for a
     * few minutes, and the app collects it once from googleHandoff().
     */
    private const HANDOFF_PATTERN = '/^[A-Za-z0-9_-]{32,64}$/';
    private const HANDOFF_MINUTES = 10;

    private function handoffFromState(string $state): ?string
    {
        if (! str_starts_with($state, 'h.')) {
            return null;
        }
        $id = substr($state, 2);

        return preg_match(self::HANDOFF_PATTERN, $id) ? $id : null;
    }

    private function handoffDonePage(): Response
    {
        $html = '<!doctype html><html lang="en"><head><meta charset="utf-8">'
            .'<meta name="viewport" content="width=device-width,initial-scale=1"><title>Signed in · Quiz LAB</title>'
            .'<style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#f7f6f1;color:#1c1c1a;'
            .'font:16px/1.5 system-ui,-apple-system,sans-serif;text-align:center;padding:24px;box-sizing:border-box}'
            .'h1{font-size:22px;margin:0 0 8px}p{margin:0;color:#5f5e58}'
            .'@media(prefers-color-scheme:dark){body{background:#121411;color:#eceae3}p{color:#a3a199}}</style>'
            .'</head><body><div><h1>You are signed in</h1>'
            .'<p>Tap <b>&times;</b> at the top left to close this window.<br>The Quiz LAB app opens your dashboard by itself.</p>'
            .'</div></body></html>';

        return response($html, 200)
            ->header('Content-Type', 'text/html; charset=utf-8')
            ->header('Cache-Control', 'no-store');
    }

    public function googleHandoff(Request $request): JsonResponse
    {
        $id = (string) $request->input('handoff', '');
        if (! preg_match(self::HANDOFF_PATTERN, $id)) {
            return response()->json(['message' => 'Invalid handoff.'], 422);
        }
        $payload = Cache::pull('google_handoff:'.$id);
        if (! is_array($payload)) {
            return response()->json(['status' => 'pending'], 404)->header('Cache-Control', 'no-store');
        }

        return response()->json($payload)->header('Cache-Control', 'no-store');
    }

    public function googleRedirect(Request $request): RedirectResponse|\Illuminate\Http\JsonResponse
    {
        try {
            $driver = Socialite::driver('google')->stateless();
            $handoff = (string) $request->query('handoff', '');
            if (preg_match(self::HANDOFF_PATTERN, $handoff)) {
                $driver->with(['state' => 'h.'.$handoff]);
            }

            return $driver->redirect();
        } catch (Throwable $e) {
            Log::error('Google OAuth redirect failed', ['message' => $e->getMessage()]);
            return response()->json(['message' => 'Google OAuth is not configured correctly.'], 500);
        }
    }

    public function googleCallback(): RedirectResponse|Response
    {
        try {
            $googleUser = Socialite::driver('google')->stateless()->user();
            $frontendUrl = rtrim((string) env('FRONTEND_URL', 'http://localhost:5173'), '/');

            $user = User::where('google_id', $googleUser->getId())
                ->orWhere('email', $googleUser->getEmail())
                ->first();

            if ($user && ! $user->is_active) {
                return redirect($frontendUrl.'/auth/callback?error=account_deactivated');
            }

            if ($user) {
                if (! $user->google_id && $googleUser->getId()) {
                    $user->update([
                        'google_id' => $googleUser->getId(),
                        'avatar' => $googleUser->getAvatar(),
                    ]);
                }
            } else {
                $user = User::create([
                    'name' => $googleUser->getName() ?? $googleUser->getNickname() ?? 'Google User',
                    'email' => $googleUser->getEmail(),
                    'password' => null,
                    'email_verified_at' => now(),
                    'google_id' => $googleUser->getId(),
                    'avatar' => $googleUser->getAvatar(),
                    'is_active' => true,
                ]);
            }

            $user->tokens()->delete();
            $token = $user->createToken('auth_token')->plainTextToken;

            LoginLog::create([
                'user_id'      => $user->id,
                    'user_agent'   => substr((string) request()->userAgent(), 0, 300),
                'auth_method'  => 'google',
                'logged_in_at' => now(),
            ]);

            $userPayload = [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_admin' => $user->is_admin,
                'role' => $user->role,
                'avatar' => $user->avatar,
            ];

            $handoff = $this->handoffFromState((string) request()->query('state', ''));
            if ($handoff !== null) {
                Cache::put('google_handoff:'.$handoff, ['token' => $token, 'user' => $userPayload], now()->addMinutes(self::HANDOFF_MINUTES));

                return $this->handoffDonePage();
            }

            $encodedToken = urlencode($token);
            $encodedUser = urlencode(json_encode($userPayload));

            return redirect($frontendUrl.'/auth/callback?token='.$encodedToken.'&user='.$encodedUser);
        } catch (Throwable $e) {
            $frontendUrl = rtrim((string) env('FRONTEND_URL', 'http://localhost:5173'), '/');
            Log::error('Google OAuth callback failed', [
                'message' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
            ]);

            return redirect($frontendUrl.'/auth/callback?error=google_auth_failed');
        }
    }

    public function logout(Request $request): JsonResponse
    {
        $token = $request->user()?->currentAccessToken();
        if ($token) {
            $token->delete();
        }

        return response()->json(['message' => 'Logged out successfully']);
    }

    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthenticated'], 401);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'Account and all associated records permanently deleted']);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        $xp = (int) ($user?->xp ?? 0);
        $progress = XpService::progress($xp);

        return response()->json([
            'user' => [
                'id' => $user?->id,
                'name' => $user?->name,
                'email' => $user?->email,
                'is_admin' => $user?->is_admin,
                'role' => $user?->effectiveRole(),
                'avatar' => $user?->avatar,
                'email_verified_at' => $user?->email_verified_at,
                'xp' => $xp,
                'level' => $progress['level'],
                'level_progress' => $progress,
                'badges' => XpService::badgesForLevel($progress['level']),
            ],
        ]);
    }
}
