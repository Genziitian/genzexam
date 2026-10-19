<?php

namespace App\Http\Controllers;

use App\Models\IDEProblem;
use App\Models\Question;
use App\Models\QuestionReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class QuestionReportController extends Controller
{
    public const REASONS = [
        'wrong_question' => 'This question is wrong',
        'wrong_answer' => 'The correct answer is wrong',
        'wrong_format' => 'The format is wrong',
        'typo' => 'Typo or unclear wording',
        'missing_info' => 'Image, table or data is missing',
        'options_wrong' => 'Options are wrong or missing',
        'other' => 'Something else is wrong',
    ];

    public const IDE_REASONS = [
        'ide_statement' => 'The problem statement is wrong or unclear',
        'ide_testcase' => 'A test case or expected output is wrong',
        'ide_sample' => 'The sample input or output is wrong',
        'ide_template' => 'The given (locked) code or function template is wrong',
        'ide_format' => 'The input or output format is wrong or missing',
        'typo' => 'Typo or unclear wording',
        'other' => 'Something else is wrong',
    ];

    /** Student: report a problem with an IDE coding question. */
    public function storeIde(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'reasons' => ['required', 'array', 'min:1', 'max:7'],
            'reasons.*' => ['string', 'in:'.implode(',', array_keys(self::IDE_REASONS))],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);
        $problem = IDEProblem::query()->where('is_active', true)->findOrFail($id);
        $report = QuestionReport::create([
            'ide_problem_id' => $problem->id,
            'user_id' => $request->user()->id,
            'question_number' => $problem->sort_order ?: null,
            'reasons' => array_values(array_unique($data['reasons'])),
            'comment' => $data['comment'] ?? null,
            'status' => 'open',
        ]);
        return response()->json(['ok' => true, 'id' => $report->id], 201);
    }

    /** Student: report a problem with a question they can see. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'question_id' => ['required', 'integer'],
            'question_number' => ['nullable', 'integer', 'min:1', 'max:1000'],
            'reasons' => ['required', 'array', 'min:1', 'max:7'],
            'reasons.*' => ['string', 'in:'.implode(',', array_keys(self::REASONS))],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);
        $question = Question::query()->findOrFail($data['question_id']);
        $report = QuestionReport::create([
            'question_id' => $question->id,
            'quiz_id' => $question->quiz_id,
            'user_id' => $request->user()->id,
            'question_number' => $data['question_number'] ?? null,
            'reasons' => array_values(array_unique($data['reasons'])),
            'comment' => $data['comment'] ?? null,
            'status' => 'open',
        ]);
        return response()->json(['ok' => true, 'id' => $report->id], 201);
    }

    /** Manager: every report with the question, paper and reporter. */
    public function index(Request $request): JsonResponse
    {
        $request->validate(['status' => ['sometimes', 'string', 'in:open,resolved,dismissed,all']]);
        $status = $request->input('status', 'open');
        $query = QuestionReport::query()
            ->with([
                'question:id,quiz_id,type,stem,marks,numerical_answer,numerical_tolerance',
                'question.questionOptions:id,question_id,option_text,is_correct,position',
                'quiz:id,title,section,course_id,is_active',
                'quiz.course:id,name',
                'ideProblem:id,course_id,title,description,sample_input,sample_output',
                'ideProblem.course:id,name',
                'user:id,name,email',
                'resolver:id,name',
            ])
            ->latest()->orderByDesc('id');
        if ($status !== 'all') $query->where('status', $status);
        $rows = $query->limit(300)->get();
        $counts = QuestionReport::query()->selectRaw('status, count(*) as c')->groupBy('status')->pluck('c', 'status');
        return response()->json(['reports' => $rows, 'counts' => $counts, 'reasons' => self::REASONS + self::IDE_REASONS]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', 'in:open,resolved,dismissed'],
            'manager_note' => ['nullable', 'string', 'max:1000'],
        ]);
        $report = QuestionReport::query()->findOrFail($id);
        $report->status = $data['status'];
        if (array_key_exists('manager_note', $data)) $report->manager_note = $data['manager_note'];
        $report->resolved_by = $data['status'] === 'open' ? null : $request->user()->id;
        $report->resolved_at = $data['status'] === 'open' ? null : now();
        $report->save();
        return response()->json(['ok' => true]);
    }
}
