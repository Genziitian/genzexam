<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class IsManager
{
    public function handle(Request $request, Closure $next): Response|JsonResponse
    {
        if (! $request->user() || ! $request->user()->isManager()) {
            return response()->json(['error' => 'Forbidden. Manager access required.'], 403);
        }

        return $next($request);
    }
}
