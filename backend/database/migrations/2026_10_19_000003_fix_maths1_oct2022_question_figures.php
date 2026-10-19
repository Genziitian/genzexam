<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // 1. Permanently associate Figure 1 image with the Maths 1 Oct 2022 questions
        DB::table('questions')
            ->where(function ($q) {
                $q->where('stem', 'like', '%Figure 1%')
                  ->orWhere('stem', 'like', '%oct2022_q1_figure1.png%');
            })
            ->where(function ($q) {
                $q->where('stem', 'like', '%quadratic functions%')
                  ->orWhere('stem', 'like', '%p(x)%');
            })
            ->update([
                'stem_image' => '/assets/exam-examples/question-crops/mathematics-1/quiz1/oct2022_q1_figure1.png',
            ]);

        // 2. Hide or deactivate duplicate legacy paper (ID 185) when Schema 1.1 paper (ID 709) is present
        $hasCleanPaper = DB::table('quizzes')
            ->where('title', 'like', 'Mathematics 1%Oct 2022%QPA1%Part 1%')
            ->exists();

        if ($hasCleanPaper) {
            DB::table('quizzes')
                ->where('id', 185)
                ->update(['is_active' => false]);
        }
    }

    public function down(): void
    {
    }
};
