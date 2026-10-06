<?php

namespace App\Console\Commands;

use App\Http\Controllers\ExamPlatformController;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

class FinalizeExpiredProctoredExams extends Command
{
    protected $signature = 'proctored-exams:finalize-expired';

    protected $description = 'Finalize proctored exam sessions whose server-side deadline has passed';

    public function handle(ExamPlatformController $exams): int
    {
        $count = $exams->expireDueExams();
        Cache::put('proctored_exams.scheduler_last_success', now()->getTimestamp(), now()->addDay());
        $this->info("Finalized {$count} expired proctored exam(s).");
        return self::SUCCESS;
    }
}
