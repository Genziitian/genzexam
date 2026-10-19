<?php

namespace Database\Seeders;

use App\Models\Course;
use App\Models\IDEProblem;
use Illuminate\Database\Seeder;

class PythonOppeSeeder extends Seeder
{
    public function run(): void
    {
        $course = Course::query()->where('slug', 'python')->firstOrFail();
        $course->update(['has_ide' => true]);

        $problems = [];
        foreach (glob(database_path('seeders/oppe/python_*.json')) as $file) {
            $problems = array_merge($problems, json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR));
        }

        foreach ($problems as $data) {
            $testCases = $data['test_cases'];
            // sort_order = section * 100 + position, so the IDE can show Section 1 / 2 / 3 groups.
            $sortOrder = ((int) ($data['section'] ?? 0)) * 100 + (int) $data['position'];
            unset($data['test_cases'], $data['position'], $data['section']);

            $problem = IDEProblem::query()->updateOrCreate(
                ['course_id' => $course->id, 'title' => $data['title']],
                $data + [
                    'difficulty' => 'medium',
                    'language' => 'python',
                    'time_limit_seconds' => 5,
                    'memory_limit_mb' => 256,
                    'is_active' => true,
                    'sort_order' => $sortOrder,
                ]
            );

            $problem->testCases()->delete();
            foreach ($testCases as $i => $case) {
                $problem->testCases()->create($case + ['position' => $i]);
            }
        }
    }
}
