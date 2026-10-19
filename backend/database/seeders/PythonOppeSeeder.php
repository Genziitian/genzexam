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

        $problems = json_decode(
            file_get_contents(database_path('seeders/oppe/python_oppe1_2024sep_set1.json')),
            true,
            512,
            JSON_THROW_ON_ERROR
        );

        foreach ($problems as $data) {
            $testCases = $data['test_cases'];
            $position = $data['position'];
            unset($data['test_cases'], $data['position']);

            $problem = IDEProblem::query()->updateOrCreate(
                ['course_id' => $course->id, 'title' => $data['title']],
                $data + [
                    'difficulty' => 'medium',
                    'language' => 'python',
                    'time_limit_seconds' => 5,
                    'memory_limit_mb' => 256,
                    'is_active' => true,
                    'sort_order' => $position,
                ]
            );

            $problem->testCases()->delete();
            foreach ($testCases as $i => $case) {
                $problem->testCases()->create($case + ['position' => $i]);
            }
        }
    }
}
