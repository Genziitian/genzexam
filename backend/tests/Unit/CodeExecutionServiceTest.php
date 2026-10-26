<?php

namespace Tests\Unit;

use App\Models\IDEProblem;
use App\Services\CodeExecutionService;
use Tests\TestCase;

class CodeExecutionServiceTest extends TestCase
{
    private function problem(): IDEProblem
    {
        return new IDEProblem([
            'starter_code' => "def sum_squares_abs_diff_squares(a: int, b: int) -> tuple:\n    ",
            'suffix_code' => "a = int(input())\nb = int(input())\nprint(sum_squares_abs_diff_squares(a, b))",
        ]);
    }

    private function judge(string $studentCode, string $input, string $expected, ?IDEProblem $p = null): array
    {
        config(['services.piston.url' => 'http://127.0.0.1:1']);
        putenv('CODE_EXECUTOR=local');
        $p ??= $this->problem();

        return (new CodeExecutionService)->judge('python', $p->composeCode($studentCode), $input, $expected, 5);
    }

    private const SOLUTION = "def sum_squares_abs_diff_squares(a: int, b: int) -> tuple:\n    return (a*a + b*b, abs(a*a - b*b))";

    public function test_function_problem_passes_with_locked_harness(): void
    {
        $this->assertTrue($this->judge(self::SOLUTION, "3\n4", '(25, 7)')['passed']);
        $this->assertTrue($this->judge(self::SOLUTION, "0\n0", '(0, 0)')['passed']);
    }

    public function test_starter_code_alone_fails_with_a_visible_error(): void
    {
        $r = $this->judge($this->problem()->starter_code, "3\n4", '(25, 7)');
        $this->assertFalse($r['passed']);
        $this->assertStringContainsString('IndentationError', $r['error']);
    }

    public function test_empty_output_is_explained_not_blank(): void
    {
        $r = $this->judge("def sum_squares_abs_diff_squares(a, b):\n    return (0, 0)", "3\n4", '(25, 7)', new IDEProblem(['suffix_code' => 'pass']));
        $this->assertFalse($r['passed']);
        $this->assertNotSame('', $r['error']);
    }

    public function test_wrong_answer_and_crlf_and_trailing_space_handling(): void
    {
        $this->assertFalse($this->judge("def f(a, b):\n    return (1, 2)", "3\n4", '(25, 7)', new IDEProblem(['suffix_code' => "print(f(1, 2))"]))['passed']);
        $this->assertTrue((new CodeExecutionService)->normalizeOutput("(25, 7)  \r\n") === (new CodeExecutionService)->normalizeOutput("(25, 7)"));
    }

    public function test_runtime_error_and_timeout_are_reported(): void
    {
        $err = $this->judge('print(1/0)', '', '1', new IDEProblem());
        $this->assertStringContainsString('ZeroDivisionError', $err['error']);

        $slow = (new CodeExecutionService)->judge('python', "while True:\n    pass", '', '1', 1);
        $this->assertTrue($slow['timed_out']);
        $this->assertSame('Time limit exceeded', $slow['error']);
    }

    /** Seeded starters must be a stub (signature / pass) so a student always has to write the logic. */
    public function test_seeded_starter_code_never_contains_a_solution(): void
    {
        $count = 0;
        foreach (glob(database_path('seeders/oppe/*.json')) as $file) {
            foreach (json_decode(file_get_contents($file), true) as $problem) {
                $count++;
                $body = preg_replace('/^\s*def .*:\s*$/m', '', (string) ($problem['starter_code'] ?? ''));
                $body = trim(preg_replace('/^\s*(pass|#.*)$/m', '', $body));
                $this->assertSame('', $body, $problem['title'].' starter_code leaks code');
                $this->assertStringNotContainsString('return', (string) ($problem['starter_code'] ?? ''), $problem['title']);
            }
        }
        $this->assertGreaterThan(0, $count);
    }
}
