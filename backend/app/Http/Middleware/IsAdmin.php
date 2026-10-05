<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class IsAdmin
{
    /**
     * Allows admins and managers. Managers sit above admins, so anything an
     * admin may do, a manager may do too.
     */
    public function handle(Request $request, Closure $next): Response|JsonResponse
    {
        if (! $request->user() || ! $request->user()->hasAdminAccess()) {
            return response()->json(['error' => 'Forbidden. Admin access required.'], 403);
        }

        return $next($request);
    }
}
