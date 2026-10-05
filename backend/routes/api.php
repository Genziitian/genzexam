<?php

use App\Http\Controllers\Admin\AdminCourseController;
use App\Http\Controllers\Admin\AdminDashboardController;
use App\Http\Controllers\Admin\AdminUserController;
use App\Http\Controllers\Admin\AdminIDEController;
use App\Http\Controllers\Admin\AdminQuestionController;
use App\Http\Controllers\Admin\AdminQuizController;
use App\Http\Controllers\Admin\AdminVideoSolutionController;
use App\Http\Controllers\Admin\BulkJsonQuizImportController;
use App\Http\Controllers\Admin\JsonQuizImportController;
use App\Http\Controllers\Admin\JsonVideoImportController;
use App\Http\Controllers\Admin\PdfQuizImportController;
use App\Http\Controllers\AttemptController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CodePlaygroundController;
use App\Http\Controllers\CourseController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DiscussionController;
use App\Http\Controllers\IDEController;
use App\Http\Controllers\LeaderboardController;
use App\Http\Controllers\QuizController;
use App\Http\Controllers\StudentProgressController;
use App\Http\Controllers\VideoSolutionController;
use App\Http\Controllers\ExamPlatformController;
use App\Http\Controllers\StorefrontController;
use Illuminate\Support\Facades\Route;

// Public auth routes
Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
Route::post('/auth/verify-otp', [AuthController::class, 'verifyOtp'])->middleware('throttle:5,1');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
Route::post('/auth/resend-otp', [AuthController::class, 'resendOtp'])->middleware('throttle:3,10');
Route::post('/auth/password/forgot', [AuthController::class, 'forgotPassword'])->middleware('throttle:3,10');
Route::post('/auth/password/reset', [AuthController::class, 'resetPassword'])->middleware('throttle:5,10');
Route::get('/auth/google', [AuthController::class, 'googleRedirect']);
Route::get('/auth/google/callback', [AuthController::class, 'googleCallback'])->middleware('throttle:10,1');

// Hardened video player page. Reached only via a short-lived signed URL issued by
// the gated /video-solutions/{id}/play endpoint, and framed by the SPA.
Route::get('/video-solutions/embed/{id}', [VideoSolutionController::class, 'embed'])
    ->whereNumber('id')
    ->middleware('signed')
    ->name('video.embed');

// Public metadata only; quiz questions stay behind the authenticated quiz API.
Route::get('/storefront/papers', [StorefrontController::class, 'papers'])->middleware('throttle:120,1');
Route::post('/storefront/razorpay/webhook', [StorefrontController::class, 'webhook'])->middleware('throttle:120,1');

// Authenticated student routes
Route::middleware(['auth:sanctum', 'track.seen'])->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/password/change', [AuthController::class, 'changePassword'])->middleware('throttle:5,10');

    // Courses
    Route::get('/courses', [CourseController::class, 'index']);
    Route::get('/courses/{slug}', [CourseController::class, 'show']);
    Route::get('/courses/{slug}/weeks', [CourseController::class, 'weeks']);
    Route::get('/courses/{slug}/practice', [CourseController::class, 'practice']);
    Route::get('/courses/{slug}/weeks/{weekNumber}/quizzes', [CourseController::class, 'weekQuizzes']);
    Route::get('/courses/{slug}/exam-prep', [CourseController::class, 'examPrep']);
    Route::get('/courses/{slug}/ide-problems', [IDEController::class, 'bySlug']);

    // Quizzes and attempts
    Route::get('/quizzes/{id}', [QuizController::class, 'show']);
    Route::post('/quizzes/{id}/attempts', [AttemptController::class, 'start']);
    Route::post('/attempts/{id}/submit', [AttemptController::class, 'submit']);
    Route::get('/attempts/{id}/result', [AttemptController::class, 'result']);
    Route::get('/quizzes/{id}/leaderboard', [QuizController::class, 'leaderboard']);

    // IDE
    Route::get('/ide-problems/{id}', [IDEController::class, 'show']);
    Route::post('/ide-problems/{id}/run', [IDEController::class, 'run'])->middleware('throttle:30,1');
    Route::post('/ide-problems/{id}/submit', [IDEController::class, 'submit'])->middleware('throttle:30,1');
    Route::get('/ide-problems/{id}/my-submissions', [IDEController::class, 'mySubmissions']);
    Route::post('/code/playground/run', [CodePlaygroundController::class, 'run'])->middleware('throttle:30,1');

    // Student progress
    Route::get('/student/progress', [StudentProgressController::class, 'index']);
    Route::get('/student/profile', [StudentProgressController::class, 'profile']);
    Route::patch('/student/profile', [StudentProgressController::class, 'updateProfile']);
    Route::get('/student/dashboard', [DashboardController::class, 'index']);

    // Self-serve paper access and Razorpay checkout.
    Route::get('/storefront/my-papers', [StorefrontController::class, 'myPapers']);
    Route::post('/storefront/papers/{quizId}/claim', [StorefrontController::class, 'claimFree'])->whereNumber('quizId');
    Route::post('/storefront/papers/{quizId}/orders', [StorefrontController::class, 'createOrder'])->whereNumber('quizId')->middleware('throttle:10,1');
    Route::post('/storefront/payments/verify', [StorefrontController::class, 'verifyPayment'])->middleware('throttle:20,1');

    // Video solutions
    Route::get('/video-solutions', [VideoSolutionController::class, 'index']);
    Route::get('/video-solutions/{id}/play', [VideoSolutionController::class, 'play'])
        ->whereNumber('id')
        ->middleware('throttle:60,1');

    // Leaderboard
    Route::get('/leaderboard', [LeaderboardController::class, 'index']);

    // Discussions include student identities, so teacher admins cannot browse them.
    Route::middleware('teacher.content_only')->group(function () {
        Route::get('/discussions/subjects', [DiscussionController::class, 'subjects']);
        Route::get('/discussions', [DiscussionController::class, 'index']);
        Route::post('/discussions', [DiscussionController::class, 'store'])->middleware('throttle:10,1');
        Route::get('/discussions/{id}', [DiscussionController::class, 'show'])->whereNumber('id');
        Route::delete('/discussions/{id}', [DiscussionController::class, 'destroy'])->whereNumber('id');
        Route::post('/discussions/{id}/replies', [DiscussionController::class, 'reply'])->whereNumber('id')->middleware('throttle:20,1');
        Route::delete('/discussions/replies/{id}', [DiscussionController::class, 'destroyReply'])->whereNumber('id');
        Route::post('/discussions/{id}/vote', [DiscussionController::class, 'voteDiscussion'])->whereNumber('id');
        Route::post('/discussions/replies/{id}/vote', [DiscussionController::class, 'voteReply'])->whereNumber('id');
        Route::post('/discussions/{id}/accept', [DiscussionController::class, 'accept'])->whereNumber('id');
        Route::post('/discussions/{id}/unaccept', [DiscussionController::class, 'unaccept'])->whereNumber('id');
        Route::post('/discussions/replies/{id}/endorse', [DiscussionController::class, 'endorse'])->whereNumber('id');
    });
});

// Admin routes
Route::middleware(['auth:sanctum', 'is_admin', 'track.seen'])->prefix('admin')->group(function () {
    Route::middleware('is_manager')->group(function () {
        Route::get('/stats', [AdminDashboardController::class, 'stats']);
        Route::get('/analytics', [AdminDashboardController::class, 'analytics']);
    });

    // Course management
    Route::get('/courses', [AdminCourseController::class, 'index']);
    Route::post('/courses', [AdminCourseController::class, 'store']);
    Route::put('/courses/{id}', [AdminCourseController::class, 'update']);
    Route::patch('/courses/{id}/toggle', [AdminCourseController::class, 'toggle']);
    Route::delete('/courses/{id}', [AdminCourseController::class, 'destroy']);

    // Quiz management
    Route::get('/quizzes', [AdminQuizController::class, 'index']);
    Route::post('/quizzes', [AdminQuizController::class, 'store']);
    Route::post('/quizzes/import-pdf', PdfQuizImportController::class)->middleware('throttle:3,1');
    Route::post('/quizzes/import-json', JsonQuizImportController::class)->middleware('throttle:10,1');
    Route::post('/quizzes/import-json-bulk', BulkJsonQuizImportController::class)->middleware('throttle:10,1');
    Route::get('/quizzes/{id}', [AdminQuizController::class, 'show']);
    Route::put('/quizzes/{id}', [AdminQuizController::class, 'update']);
    Route::delete('/quizzes/{id}', [AdminQuizController::class, 'destroy']);
    Route::patch('/quizzes/{id}/toggle', [AdminQuizController::class, 'toggle'])->middleware('is_manager');

    // Managers review submitted papers and control publication.
    Route::middleware('is_manager')->group(function () {
        Route::patch('/quizzes/{id}/approve', [AdminQuizController::class, 'approve']);
    });

    // Question management (inside a quiz)
    Route::get('/quizzes/{quizId}/questions', [AdminQuestionController::class, 'index']);
    Route::post('/quizzes/{quizId}/questions', [AdminQuestionController::class, 'store']);
    Route::post('/quizzes/{quizId}/questions/import-json', [AdminQuestionController::class, 'importJson'])->middleware('throttle:5,1');
    Route::get('/questions/{id}', [AdminQuestionController::class, 'show']);
    Route::put('/questions/{id}', [AdminQuestionController::class, 'update']);
    Route::delete('/questions/{id}', [AdminQuestionController::class, 'destroy']);
    Route::patch('/quizzes/{quizId}/questions/reorder', [AdminQuestionController::class, 'reorder']);

    // IDE problem management
    Route::get('/ide-problems', [AdminIDEController::class, 'index']);
    Route::post('/ide-problems', [AdminIDEController::class, 'store']);
    Route::get('/ide-problems/{id}', [AdminIDEController::class, 'show']);
    Route::put('/ide-problems/{id}', [AdminIDEController::class, 'update']);
    Route::delete('/ide-problems/{id}', [AdminIDEController::class, 'destroy']);
    Route::post('/ide-problems/{id}/test-cases', [AdminIDEController::class, 'addTestCase']);
    Route::put('/test-cases/{id}', [AdminIDEController::class, 'updateTestCase']);
    Route::delete('/test-cases/{id}', [AdminIDEController::class, 'deleteTestCase']);

    // Video solution management
    Route::get('/video-solutions', [AdminVideoSolutionController::class, 'index']);
    Route::post('/video-solutions', [AdminVideoSolutionController::class, 'store']);
    Route::put('/video-solutions/{id}', [AdminVideoSolutionController::class, 'update']);
    Route::delete('/video-solutions/{id}', [AdminVideoSolutionController::class, 'destroy']);

    // User records and course assignments are manager-only. Admins never see student accounts.
    Route::middleware('is_manager')->group(function () {
        Route::post('/video-solutions/import-json', JsonVideoImportController::class)->middleware('throttle:10,1');
        Route::get('/users', [AdminUserController::class, 'index']);
        Route::patch('/users/{userId}/toggle-active', [AdminUserController::class, 'toggleActive']);
        Route::patch('/users/{userId}/toggle-pro', [AdminUserController::class, 'togglePro']);
        Route::patch('/users/{userId}/role', [AdminUserController::class, 'setRole']);
        Route::put('/users/{userId}/courses', [AdminUserController::class, 'assignCourses']);
        Route::delete('/users/{userId}', [AdminUserController::class, 'destroy']);
        Route::patch('/storefront/papers/{quizId}', [StorefrontController::class, 'updatePrice'])->whereNumber('quizId');
    });
});

// =========================================================================
// GenZ IITian Examination Platform (Proctored B2B SaaS Engine) Routes
// =========================================================================
// Exam platform. Everything but the health probe requires a session: these
// endpoints drive live exam state, so they must not be callable by anyone who
// knows the URL. Exam control is admin-and-above, a full reset is manager-only,
// and syncState itself narrows what a candidate may write.
$examPlatformRoutes = function () {
    Route::get('/health', [ExamPlatformController::class, 'health']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/state', [ExamPlatformController::class, 'state']);
        Route::post('/state', [ExamPlatformController::class, 'syncState']);
        Route::get('/chat', [ExamPlatformController::class, 'getChat']);
        Route::post('/chat', [ExamPlatformController::class, 'sendChat']);
        Route::get('/reentry', [ExamPlatformController::class, 'getReentry']);
        Route::post('/violation', [ExamPlatformController::class, 'recordViolation']);
        Route::post('/submit', [ExamPlatformController::class, 'submitExam']);

        Route::middleware('is_manager')->group(function () {
            Route::post('/action', [ExamPlatformController::class, 'action']);
        });

        Route::middleware('is_manager')->group(function () {
            Route::post('/reset', [ExamPlatformController::class, 'resetState']);
        });
    });
};

Route::prefix('exam-platform')->group($examPlatformRoutes);
Route::group([], $examPlatformRoutes);
