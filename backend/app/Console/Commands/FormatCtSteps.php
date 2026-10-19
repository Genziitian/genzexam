<?php

namespace App\Console\Commands;

use App\Models\Question;
use Illuminate\Console\Command;

class FormatCtSteps extends Command
{
    protected $signature = 'quiz:format-ct-steps {--dry-run : Inspect and output questions without modifying the database}';

    protected $description = 'Scan questions in the database with unformatted procedure steps and extract them into pseudocode stem_code blocks.';

    public function handle(): int
    {
        $isDryRun = (bool) $this->option('dry-run');

        $questions = Question::query()
            ->whereNull('stem_code')
            ->where('stem', 'LIKE', '%Step 1%')
            ->get();

        $this->info("Found {$questions->count()} candidate questions with 'Step 1' and no stem_code.");

        $updatedCount = 0;

        foreach ($questions as $q) {
            $parsed = $this->parseProcedureSteps($q->stem);
            if (! $parsed) {
                continue;
            }

            $updatedCount++;
            $this->line("Question ID {$q->id} (Quiz {$q->quiz_id}): Extracted " . count($parsed['steps']) . " steps.");

            if (! $isDryRun) {
                $newStem = trim($parsed['intro'] . ($parsed['outro'] ? "\n\n" . $parsed['outro'] : ''));
                $q->update([
                    'stem' => $newStem ?: $q->stem,
                    'stem_code' => implode("\n", $parsed['steps']),
                    'stem_code_language' => 'pseudocode',
                ]);
            }
        }

        if ($isDryRun) {
            $this->warn("Dry run completed. {$updatedCount} questions can be formatted. Run without --dry-run to apply changes.");
        } else {
            $this->info("Successfully formatted {$updatedCount} questions in the database.");
        }

        return self::SUCCESS;
    }

    /**
     * @return array{intro: string, steps: string[], outro: string}|null
     */
    private function parseProcedureSteps(string $rawText): ?array
    {
        preg_match_all('/\b(Step\s*\d+\s*[:.-])\s*/i', $rawText, $matches, PREG_OFFSET_CAPTURE);

        if (empty($matches[0]) || count($matches[0]) < 2) {
            return null;
        }

        $firstHeader = trim($matches[1][0][0]);
        if (! preg_match('/^step\s*1\b/i', $firstHeader)) {
            return null;
        }

        $intro = trim(substr($rawText, 0, $matches[0][0][1]));
        $steps = [];
        $outro = '';
        $count = count($matches[0]);

        for ($i = 0; $i < $count; $i++) {
            $m = $matches[0][$i];
            preg_match('/\d+/', $m[0], $numMatch);
            $num = $numMatch ? $numMatch[0] : (string) ($i + 1);
            $header = "Step {$num}:";

            $start = $m[1] + strlen($m[0]);

            if ($i + 1 < $count) {
                $end = $matches[0][$i + 1][1];
                $body = trim(substr($rawText, $start, $end - $start));
                $steps[] = "{$header} {$body}";
            } else {
                $fullLast = trim(substr($rawText, $start));
                if (preg_match('/(?:(?<=\brepeat from step \d)|(?<=\brepeat from step \d\.)|(?<=\bstop the iteration)|(?<=\.))\s+(The value of\b.*|What will\b.*|It is a\b.*)/i', $fullLast, $outroMatch, PREG_OFFSET_CAPTURE)) {
                    $body = trim(substr($fullLast, 0, $outroMatch[0][1]));
                    $outro = trim($outroMatch[0][0]);
                    $steps[] = "{$header} {$body}";
                } else {
                    $steps[] = "{$header} {$fullLast}";
                }
            }
        }

        return [
            'intro' => $intro,
            'steps' => $steps,
            'outro' => $outro,
        ];
    }
}
