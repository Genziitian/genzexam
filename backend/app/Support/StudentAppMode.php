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
        $client = strtolower((string) $request->header('X-QuizLab-Client'));
        return in_array($client, ['mobile', 'web'], true)
            || $request->header('X-QuizLab-Mode') === 'student';
    }

    public static function isStudent(Request $request): bool
    {
        return self::enabled($request) || $request->user()?->isStudent() === true;
    }
}
