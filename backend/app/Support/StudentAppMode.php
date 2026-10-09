<?php

namespace App\Support;

use Illuminate\Http\Request;

/**
 * Select the native app's student experience for the signed-in account.
 * The marker changes UI/business behavior only: API authentication still
 * identifies the current account and student-owned queries stay user-scoped.
 */
final class StudentAppMode
{
    public static function enabled(Request $request): bool
    {
        return $request->header('X-QuizLab-Client') === 'mobile';
    }

    public static function isStudent(Request $request): bool
    {
        return self::enabled($request) || $request->user()?->isStudent() === true;
    }
}
