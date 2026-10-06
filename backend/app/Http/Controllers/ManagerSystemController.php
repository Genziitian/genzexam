<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Manager-only maintenance for hosts without shell access: report whether the
 * database schema is up to date and apply the pending migrations shipped with
 * this release. Nothing here accepts SQL or file paths from the request.
 */
class ManagerSystemController extends Controller
{
    private const PROCTORING_TABLES = [
        'proctored_exams', 'proctored_exam_enrollments', 'proctored_exam_sessions',
        'proctored_exam_events', 'proctored_exam_messages', 'proctored_exam_audit_logs',
    ];

    public function status(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');

        return response()->json($this->report());
    }

    public function migrate(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');

        try {
            Artisan::call('migrate', ['--force' => true]);
            $output = trim(Artisan::output());
        } catch (\Throwable $e) {
            report($e);

            return response()->json([
                'ok' => false,
                'message' => 'The database update failed: '.$e->getMessage(),
                ...$this->report(),
            ], 500);
        }

        return response()->json(['ok' => true, 'output' => $output, ...$this->report()]);
    }

    private function report(): array
    {
        $report = ['database' => false, 'pending' => [], 'missing_tables' => [], 'missing_columns' => [], 'error' => null];

        try {
            DB::connection()->getPdo();
            $report['database'] = true;

            $migrator = app('migrator');
            $files = array_keys($migrator->getMigrationFiles([database_path('migrations')]));
            $ran = $migrator->repositoryExists() ? $migrator->getRepository()->getRan() : [];
            $report['pending'] = array_values(array_diff($files, $ran));

            foreach (self::PROCTORING_TABLES as $table) {
                if (! Schema::hasTable($table)) $report['missing_tables'][] = $table;
            }
            if (Schema::hasTable('proctored_exams')) {
                foreach (['question_count', 'closes_at'] as $column) {
                    if (! Schema::hasColumn('proctored_exams', $column)) $report['missing_columns'][] = 'proctored_exams.'.$column;
                }
            }
        } catch (\Throwable $e) {
            report($e);
            $report['error'] = $e->getMessage();
        }

        $report['up_to_date'] = $report['database'] && ! $report['error']
            && $report['pending'] === [] && $report['missing_tables'] === [] && $report['missing_columns'] === [];

        return $report;
    }
}
