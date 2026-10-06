<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Deployment gate; never prints credentials or modifies exam records. */
class CheckProctoredExamReadiness extends Command
{
    protected $signature = 'proctored-exams:check {--skip-scheduler : Check configuration before installing the scheduler}';
    protected $description = 'Check production configuration, exam schema, database, cache and scheduler heartbeat';

    public function handle(): int
    {
        $checks = [
            'Production environment' => app()->environment('production'),
            'Debug disabled' => !config('app.debug'),
            'Application key configured' => strlen((string) config('app.key')) >= 32,
            'HTTPS application URL' => str_starts_with((string) config('app.url'), 'https://'),
            'Shared persistent cache (database or Redis)' => in_array(config('cache.default'), ['database', 'redis'], true),
            'Production database (MySQL or PostgreSQL)' => in_array(config('database.default'), ['mysql', 'pgsql'], true),
            'Explicit frontend CORS origins' => count(config('cors.allowed_origins', [])) > 0 && !in_array('*', config('cors.allowed_origins', []), true),
        ];
        try {
            DB::connection()->getPdo();
            $checks['Database connected'] = true;
            foreach (['proctored_exams', 'proctored_exam_enrollments', 'proctored_exam_sessions', 'proctored_exam_events', 'proctored_exam_messages', 'proctored_exam_audit_logs'] as $table) {
                $checks['Schema '.$table] = Schema::hasTable($table);
            }
            $checks['Question metadata migration complete'] = Schema::hasColumn('proctored_exams', 'question_count');
            $checks['Cache readable'] = Cache::get('proctored_exams.readiness_probe', 'available') === 'available';
            if (!$this->option('skip-scheduler')) {
                $last = Cache::get('proctored_exams.scheduler_last_success');
                $checks['Scheduler ran successfully in the last 3 minutes'] = is_numeric($last) && now()->getTimestamp() - (int) $last <= 180;
            }
        } catch (\Throwable $e) {
            $checks['Database/cache available (see private application logs)'] = false;
            report($e);
        }
        foreach ($checks as $name => $passed) {
            $passed ? $this->info('PASS '.$name) : $this->error('FAIL '.$name);
        }
        $this->line('Also verify backups, HTTPS/CORS in a browser, staging load, and the manager/candidate journey before opening enrollment.');
        return in_array(false, $checks, true) ? self::FAILURE : self::SUCCESS;
    }
}
