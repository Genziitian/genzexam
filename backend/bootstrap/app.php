<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'public/api',
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->prepend(\App\Http\Middleware\PreventApiResponseCaching::class);

        $middleware->alias([
            'is_admin' => \App\Http\Middleware\IsAdmin::class,
            'is_manager' => \App\Http\Middleware\IsManager::class,
            'teacher.content_only' => \App\Http\Middleware\TeacherContentOnly::class,
            'track.seen' => \App\Http\Middleware\TrackLastSeen::class,
            'exam.account' => \App\Http\Middleware\RequireActiveVerifiedAccount::class,
        ]);

        $middleware->redirectGuestsTo(fn (Request $request) => null);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Log sign-in attempts the middleware rejects before they reach AuthController.
        $exceptions->render(function (\Illuminate\Http\Exceptions\ThrottleRequestsException $e, Request $request) {
            if ($request->is('public/api/auth/*') && ! $request->is('public/api/auth/login-failure') && ! $request->is('public/api/auth/google/handoff')) {
                \App\Models\LoginFailure::record(
                    str_contains($request->path(), 'google') ? 'google' : (str_contains($request->path(), 'otp') ? 'otp' : 'email'),
                    'rate_limited', $request->input('email'), null,
                    'Blocked: too many attempts from this IP on '.$request->path().'.',
                    'Retry-After: '.($e->getHeaders()['Retry-After'] ?? '?').'s'
                );
            }

            return null;
        });
        $exceptions->render(function (\Illuminate\Validation\ValidationException $e, Request $request) {
            if ($request->is('public/api/auth/login') || $request->is('public/api/auth/verify-otp') || $request->is('public/api/auth/register')) {
                \App\Models\LoginFailure::record(
                    $request->is('public/api/auth/login') ? 'email' : ($request->is('public/api/auth/register') ? 'register' : 'otp'),
                    'validation', is_string($request->input('email')) ? $request->input('email') : null, null,
                    mb_substr(implode(' ', array_map(fn ($m) => implode(' ', (array) $m), $e->errors())), 0, 500)
                );
            }

            return null;
        });
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*') || $request->is('public/api/*')) {
                return response()->json(['message' => 'Unauthenticated.'], 401);
            }

            return null;
        });
    })->create();
