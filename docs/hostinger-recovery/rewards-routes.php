<?php

use App\Http\Controllers\StudentRewardController;
use Illuminate\Support\Facades\Route;

// Included at the end of api.php by the recovery installer. Existing routes win,
// so the include remains safe when a later full deployment restores those routes.
$rewardRouteExists = static function (string $method, string $path): bool {
    foreach (Route::getRoutes() as $route) {
        $uri = trim($route->uri(), '/');
        if (in_array($method, $route->methods(), true)
            && ($uri === $path || str_ends_with($uri, '/'.$path))) {
            return true;
        }
    }
    return false;
};

Route::middleware(['auth:sanctum', 'track.seen'])->group(function () use ($rewardRouteExists) {
    foreach ([
        ['GET', 'student/rewards', 'index', '60,1'],
        ['POST', 'student/rewards/spin', 'spin', '10,1'],
        ['POST', 'student/rewards/claim-pro', 'claimPro', '5,1'],
        ['POST', 'student/rewards/scratch', 'scratch', '30,1'],
    ] as [$method, $path, $action, $throttle]) {
        if (! $rewardRouteExists($method, $path)) {
            Route::match([$method], '/'.$path, [StudentRewardController::class, $action])
                ->middleware('throttle:'.$throttle);
        }
    }
});

if (! $rewardRouteExists('GET', 'manager/rewards/log')) {
    Route::get('/manager/rewards/log', [StudentRewardController::class, 'managerLog'])
        ->middleware(['auth:sanctum', 'is_manager', 'throttle:120,1']);
}
