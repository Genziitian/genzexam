<?php

namespace Database\Seeders;

use App\Models\Course;
use Illuminate\Database\Seeder;

/** Adds Diploma-level subjects that have paper files but no course yet. Safe to run again. */
class ExtraDiplomaCoursesSeeder extends Seeder
{
    public function run(): void
    {
        $courses = [
            ['name' => 'Deep Learning', 'slug' => 'deep-learning', 'description' => 'Neural networks and deep learning'],
            ['name' => 'Tools in Data Science', 'slug' => 'tools-in-data-science', 'description' => 'Practical tools for data science work'],
            ['name' => 'Deep Learning Practice', 'slug' => 'deep-learning-practice', 'description' => 'Hands-on deep learning'],
            ['name' => 'Large Language Models', 'slug' => 'large-language-models', 'description' => 'Large language models and their applications'],
            ['name' => 'Software Engineering', 'slug' => 'software-engineering', 'description' => 'Software design and engineering practice'],
            ['name' => 'Software Testing', 'slug' => 'software-testing', 'description' => 'Testing methods and practice'],
        ];

        $order = (int) Course::query()->max('sort_order');
        foreach ($courses as $data) {
            Course::query()->firstOrCreate(
                ['slug' => $data['slug']],
                $data + ['level' => 'diploma', 'icon' => '', 'has_ide' => false, 'is_active' => true, 'sort_order' => ++$order]
            );
        }
    }
}
