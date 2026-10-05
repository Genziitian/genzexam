<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class TeacherContentOnly
{
    public function handle(Request $request, Closure $next): Response|JsonResponse
    {
        if ($request->user()?->isAdmin()) {
            return response()->json(['error' => 'Teacher accounts can access assigned course content only.'], 403);
        }

        return $next($request);
    }
}
