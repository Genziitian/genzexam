<?php

namespace App\Http\Middleware;

use App\Models\Question;
use App\Models\Quiz;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class ManagerPaperDraft
{
    public function handle(Request $request, Closure $next): Response
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');
        $quizId = $request->route('quizId');
        if ($quizId === null) {
            $quizId = Question::query()->findOrFail($request->route('id'))->quiz_id;
        }
        return DB::transaction(function () use ($request, $next, $quizId) {
            // Publication takes the same row lock so a live paper cannot change mid-review.
            $quiz = Quiz::query()->lockForUpdate()->findOrFail($quizId);
            abort_if($quiz->is_active, 409, 'Unpublish this paper before editing its questions.');
            return $next($request);
        });
    }
}
