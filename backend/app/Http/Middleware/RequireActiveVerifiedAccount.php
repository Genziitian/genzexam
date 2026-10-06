<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireActiveVerifiedAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        if (strlen($request->getContent()) > 5 * 1024 * 1024) {
            return response()->json(['message' => 'Request exceeds the 5 MB limit.'], 413)
                ->header('Cache-Control', 'no-store, private');
        }
        $user = $request->user();
        if (!$user || !$user->is_active || !$user->email_verified_at) {
            return response()->json(['error' => 'An active, verified account is required.'], 403)
                ->header('Cache-Control', 'no-store, private');
        }

        $response = $next($request);
        $response->headers->set('Cache-Control', 'no-store, private, max-age=0');
        $response->headers->set('Pragma', 'no-cache');
        return $response;
    }
}
