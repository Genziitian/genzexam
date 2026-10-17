<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Throwable;

class GooglePlayPushAuthentication
{
    public function verify(Request $request): void
    {
        $audience = (string) config('services.google_play.rtdn_audience');
        $email = (string) config('services.google_play.rtdn_service_account_email');
        abort_if($audience === '' || $email === '', 503, 'Play notification authentication is not configured.');
        $token = $request->bearerToken();
        abort_unless(is_string($token) && $token !== '' && strlen($token) <= 16384, 401, 'Google authentication required.');

        // Google validates the signature. Never trust a locally decoded JWT or
        // log the token/HTTP exception (the request URL contains the ID token).
        try {
            $response = Http::acceptJson()->connectTimeout(3)->timeout(10)
                ->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $token]);
        } catch (Throwable) {
            abort(503, 'Google authentication is temporarily unavailable.');
        }
        abort_if($response->serverError() || $response->status() === 429, 503, 'Google authentication is temporarily unavailable.');
        abort_unless($response->successful(), 401, 'Invalid Google authentication.');
        $claims = $response->json();
        $valid = is_array($claims)
            && in_array($claims['iss'] ?? null, ['accounts.google.com', 'https://accounts.google.com'], true)
            && is_string($claims['aud'] ?? null) && hash_equals($audience, $claims['aud'])
            && is_string($claims['email'] ?? null) && hash_equals($email, $claims['email'])
            && filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN)
            && ! empty($claims['sub'])
            && (int) ($claims['exp'] ?? 0) > now()->timestamp
            && (int) ($claims['iat'] ?? 0) > 0
            && (int) $claims['iat'] <= now()->timestamp + 60;
        abort_unless($valid, 403, 'Unexpected Google notification identity.');
    }
}
