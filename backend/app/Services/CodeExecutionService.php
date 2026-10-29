<?php

namespace App\Services;

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;
use Illuminate\Process\Exceptions\ProcessTimedOutException;
use Illuminate\Support\Str;
use Symfony\Component\Process\ExecutableFinder;

class CodeExecutionService
{
    /** Run one test case and compare. Shared by Run and Submit so both always agree. */
    public function judge(string $language, string $code, string $input, string $expected, int $timeLimit = 5): array
    {
        $run = $this->execute($language, $code, $input, $timeLimit);
        $got = $this->normalizeOutput((string) $run['stdout']);
        $expected = $this->normalizeOutput($expected);
        $error = trim((string) $run['stderr']);

        if ($error === '' && $got === '' && $expected !== '') {
            $error = 'Your program printed nothing. Check that every line of your code is complete and that the function returns a value.';
        }

        return [
            'input' => $input,
            'expected' => $expected,
            'got' => $got,
            'error' => $error,
            'timed_out' => (bool) ($run['timed_out'] ?? false),
            'exit_code' => $run['exit_code'],
            'passed' => $run['exit_code'] === 0 && $got === $expected,
        ];
    }

    /** Line endings and trailing spaces never decide a verdict; inner spacing still does. */
    public function normalizeOutput(string $text): string
    {
        return trim(implode("\n", array_map('rtrim', preg_split('/\R/', $text))));
    }

    public function execute(string $language, string $code, string $input = '', int $timeLimit = 5): array
    {
        // Laravel's Process skips stdin when the input is falsy, so a lone "0" never reached the program. A trailing newline is also what a terminal sends.
        $input = rtrim($input, "\r\n")."\n";
        $result = $this->dispatch($language, $code, $input, $timeLimit);
        $result['exit_code'] = (int) ($result['exit_code'] ?? 1);
        $result['stdout'] = (string) ($result['stdout'] ?? '');
        $result['stderr'] = trim((string) ($result['stderr'] ?? ''));

        // A failed run must always say why; never let it look like "blank output".
        if ($result['exit_code'] !== 0 && $result['stderr'] === '') {
            $result['stderr'] = 'Program exited with code '.$result['exit_code'].' without any error message.';
        }

        return $result;
    }

    private function dispatch(string $language, string $code, string $input, int $timeLimit): array
    {
        $defaultExecutor = app()->isProduction() ? 'piston' : 'local';
        $executor = strtolower((string) env('CODE_EXECUTOR', $defaultExecutor));
        if ($executor === 'local') {
            return $this->executeLocally($language, $code, $input, $timeLimit);
        }

        $remote = $this->executeViaPiston($language, $code, $input, $timeLimit);
        if (! $this->shouldFallbackToLocal($remote)) {
            return $remote;
        }

        return $this->executeLocally($language, $code, $input, $timeLimit);
    }

    private function shouldFallbackToLocal(array $remote): bool
    {
        // Never fall back to host execution in production.
        if (app()->isProduction()) {
            return false;
        }

        $stderr = trim((string) ($remote['stderr'] ?? ''));
        if ($stderr === 'Execution service unavailable') {
            return true;
        }

        $stdout = trim((string) ($remote['stdout'] ?? ''));
        $code = (int) ($remote['exit_code'] ?? 1);

        // Some remote environments can return crash exit codes without any output.
        if ($stdout === '' && $stderr === '' && $code !== 0) {
            return true;
        }

        return false;
    }

    private function executeViaPiston(string $language, string $code, string $input, int $timeLimit): array
    {
        $langMap = [
            'python' => ['language' => 'python', 'version' => '3.10.0'],
            'java' => ['language' => 'java', 'version' => '15.0.2'],
            'cpp' => ['language' => 'c++', 'version' => '10.2.0'],
            'c++' => ['language' => 'c++', 'version' => '10.2.0'],
        ];

        $lang = $langMap[$language] ?? $langMap['python'];

        try {
            $response = Http::timeout($timeLimit + 5)->post(rtrim((string) env('PISTON_API_URL', config('services.piston.url')), '/').'/execute', [
                'language' => $lang['language'],
                'version' => $lang['version'],
                'files' => [['content' => $code]],
                'stdin' => $input,
                'run_timeout' => $timeLimit * 1000,
            ]);
        } catch (\Throwable) {
            return [
                'stdout' => '',
                'stderr' => 'Execution service unavailable',
                'exit_code' => 1,
            ];
        }

        if ($response->failed()) {
            return [
                'stdout' => '',
                'stderr' => 'Execution service unavailable',
                'exit_code' => 1,
            ];
        }

        $compile = $response->json('compile');
        if (is_array($compile) && (int) ($compile['code'] ?? 0) !== 0) {
            return [
                'stdout' => '',
                'stderr' => $compile['stderr'] ?? $compile['output'] ?? 'Compilation failed',
                'exit_code' => (int) $compile['code'],
            ];
        }

        $run = $response->json('run');
        if (! is_array($run)) {
            return [
                'stdout' => '',
                'stderr' => (string) ($response->json('message') ?: 'Execution service returned no result'),
                'exit_code' => 1,
            ];
        }

        $timedOut = ($run['signal'] ?? null) === 'SIGKILL';

        return [
            'stdout' => $run['stdout'] ?? '',
            'stderr' => $timedOut ? 'Time limit exceeded' : ($run['stderr'] ?? ''),
            'exit_code' => $timedOut ? 124 : (int) ($run['code'] ?? 0),
            'timed_out' => $timedOut,
        ];
    }

    private function executeLocally(string $language, string $code, string $input, int $timeLimit): array
    {
        if (app()->isProduction()) {
            return ['stdout' => '', 'stderr' => 'Local execution is disabled in production.', 'exit_code' => 1];
        }

        $lang = strtolower($language);
        $workDir = storage_path('app/code-runner/'.Str::uuid()->toString());
        File::ensureDirectoryExists($workDir);

        try {
            return match ($lang) {
                'python' => $this->runPython($workDir, $code, $input, $timeLimit),
                'java' => $this->runJava($workDir, $code, $input, $timeLimit),
                'cpp', 'c++' => $this->runCpp($workDir, $code, $input, $timeLimit),
                default => [
                    'stdout' => '',
                    'stderr' => 'Unsupported language for local executor',
                    'exit_code' => 1,
                ],
            };
        } catch (ProcessTimedOutException) {
            return ['stdout' => '', 'stderr' => 'Time limit exceeded', 'exit_code' => 124, 'timed_out' => true];
        } catch (\Throwable $e) {
            return [
                'stdout' => '',
                'stderr' => 'Local execution failed: '.$e->getMessage(),
                'exit_code' => 1,
            ];
        } finally {
            File::deleteDirectory($workDir);
        }
    }

    private function pythonBinary(): string
    {
        // Most Linux hosts ship only `python3`; a bare `python` then fails before any code runs.
        return (string) (env('PYTHON_BIN') ?: (new ExecutableFinder)->find('python3', 'python'));
    }

    private function runPython(string $workDir, string $code, string $input, int $timeLimit): array
    {
        File::put($workDir.'/solution.py', $code);

        $run = Process::path($workDir)
            ->timeout($timeLimit + 2)
            ->input($input)
            ->run([$this->pythonBinary(), 'solution.py']);

        return [
            'stdout' => $run->output(),
            'stderr' => $run->errorOutput(),
            'exit_code' => $run->exitCode() ?? 1,
        ];
    }

    private function runJava(string $workDir, string $code, string $input, int $timeLimit): array
    {
        $className = $this->extractJavaMainClassName($code) ?? 'Solution';
        $fileName = $className.'.java';
        $javacBin = (string) env('JAVAC_BIN', 'javac');
        $javaBin = (string) env('JAVA_BIN', 'java');

        File::put($workDir.'/'.$fileName, $code);

        $compile = Process::path($workDir)
            ->timeout($timeLimit + 5)
            ->run([$javacBin, $fileName]);

        if (! $compile->successful()) {
            return [
                'stdout' => $compile->output(),
                'stderr' => $this->normalizeProcessError(
                    $compile->errorOutput(),
                    $compile->exitCode(),
                    'Java compilation failed'
                ),
                'exit_code' => $compile->exitCode() ?? 1,
            ];
        }

        $run = Process::path($workDir)
            ->timeout($timeLimit + 2)
            ->input($input)
            ->run([$javaBin, '-cp', $workDir, $className]);

        // Retry using plain invocation for environments where -cp with absolute path behaves oddly.
        if (! $run->successful() && trim($run->output()) === '' && trim($run->errorOutput()) === '') {
            $run = Process::path($workDir)
                ->timeout($timeLimit + 2)
                ->input($input)
                ->run([$javaBin, $className]);
        }

        return [
            'stdout' => $run->output(),
            'stderr' => $this->normalizeProcessError(
                $run->errorOutput(),
                $run->exitCode(),
                'Java runtime failed'
            ),
            'exit_code' => $run->exitCode() ?? 1,
        ];
    }

    private function normalizeProcessError(?string $stderr, ?int $exitCode, string $context): string
    {
        $errorText = trim((string) $stderr);
        $code = (int) ($exitCode ?? 1);

        if ($errorText !== '') {
            return $errorText;
        }

        if ($code !== 0) {
            return $context.' (exit code '.$code.'). Check JAVA_BIN/JAVAC_BIN in .env if this persists.';
        }

        return '';
    }

    private function runCpp(string $workDir, string $code, string $input, int $timeLimit): array
    {
        $outputBinary = PHP_OS_FAMILY === 'Windows' ? 'main.exe' : 'main';
        $runBinary = PHP_OS_FAMILY === 'Windows' ? 'main.exe' : './main';

        File::put($workDir.'/main.cpp', $code);

        $compile = Process::path($workDir)
            ->timeout($timeLimit + 5)
            ->run(['g++', 'main.cpp', '-std=c++17', '-O2', '-o', $outputBinary]);

        if (! $compile->successful()) {
            return [
                'stdout' => $compile->output(),
                'stderr' => $compile->errorOutput(),
                'exit_code' => $compile->exitCode() ?? 1,
            ];
        }

        $run = Process::path($workDir)
            ->timeout($timeLimit + 2)
            ->input($input)
            ->run([$runBinary]);

        return [
            'stdout' => $run->output(),
            'stderr' => $run->errorOutput(),
            'exit_code' => $run->exitCode() ?? 1,
        ];
    }

    private function extractJavaMainClassName(string $code): ?string
    {
        if (preg_match('/public\s+class\s+([A-Za-z_][A-Za-z0-9_]*)/', $code, $matches) === 1) {
            return $matches[1];
        }

        if (preg_match('/\bclass\s+([A-Za-z_][A-Za-z0-9_]*)/', $code, $matches) === 1) {
            return $matches[1];
        }

        return null;
    }
}
