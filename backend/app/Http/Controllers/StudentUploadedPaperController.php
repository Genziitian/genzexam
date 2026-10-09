<?php

namespace App\Http\Controllers;

use App\Exceptions\DeepSeekGenerationException;
use App\Models\Course;
use App\Models\Quiz;
use App\Services\DeepSeekQuizGenerator;
use App\Services\QuestionImporter;
use App\Support\StudentAppMode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Smalot\PdfParser\Parser as PdfParser;
use Throwable;

class StudentUploadedPaperController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        abort_if(! StudentAppMode::isStudent($request), 403, 'Student uploads only.');

        $papers = Quiz::withoutGlobalScope('exclude_personal_uploads')->where('is_personal', true)
            ->where('owner_user_id', $request->user()->id)
            ->withCount('questions')->latest('id')->get()
            ->map(fn (Quiz $quiz) => [
                'id' => $quiz->id,
                'title' => $quiz->title,
                'question_count' => $quiz->questions_count,
                'created_at' => $quiz->created_at,
            ])->values();

        return response()->json(['papers' => $papers]);
    }

    public function store(Request $request, DeepSeekQuizGenerator $generator, QuestionImporter $importer): JsonResponse
    {
        abort_if(! StudentAppMode::isStudent($request), 403, 'Student uploads only.');
        @set_time_limit(0);
        @ini_set('max_execution_time', '0');

        $validated = $request->validate([
            'paper' => ['required', 'file', 'mimes:pdf,json', 'max:10240'],
            'title' => ['nullable', 'string', 'max:200'],
        ]);
        $file = $request->file('paper');
        $rows = [];
        $suggestedTitle = '';
        $warnings = [];

        if (strtolower($file->getClientOriginalExtension()) === 'json') {
            $payload = json_decode(file_get_contents($file->getRealPath()), true);
            if (! is_array($payload)) {
                return response()->json(['error' => 'The JSON file could not be read.'], 422);
            }
            $rows = $payload['questions'] ?? $payload;
            $suggestedTitle = (string) ($payload['quiz_title'] ?? '');
            if (! is_array($rows) || ! array_is_list($rows)) {
                return response()->json(['error' => 'JSON must contain a questions array.'], 422);
            }
            $maxQuestions = max(1, (int) config('services.deepseek.max_questions', 100));
            if (count($rows) > $maxQuestions) {
                return response()->json(['error' => "A paper can contain up to {$maxQuestions} questions."], 422);
            }
        } else {
            $path = $file->store('tmp-student-papers', 'local');
            try {
                $document = (new PdfParser())->parseFile(storage_path('app/'.$path));
                $maxPages = max(1, (int) config('services.student_paper_uploads.max_pdf_pages', 30));
                if (count($document->getPages()) > $maxPages) {
                    return response()->json(['error' => "PDFs can contain up to {$maxPages} pages."], 422);
                }
                $text = $document->getText();
                if (trim($text) === '') {
                    return response()->json(['error' => 'This PDF has no selectable text. Scanned image PDFs are not supported yet.'], 422);
                }
                $maxInputChars = max(1000, (int) config('services.deepseek.max_input_chars', 60000));
                if (mb_strlen(trim($text)) > $maxInputChars) {
                    return response()->json(['error' => 'This PDF contains too much text. Please split it into smaller papers.'], 422);
                }
                if (! $this->looksLikeQuestionPaper($text)) {
                    return response()->json(['error' => 'This file does not look like a question paper. Upload a paper containing questions.'], 422);
                }

                $dailyLimit = max(1, (int) config('services.student_paper_uploads.daily_ai_conversions', 10));
                $rateLimitKey = 'student-paper-ai:'.$request->user()->id;
                if (RateLimiter::tooManyAttempts($rateLimitKey, $dailyLimit)) {
                    return response()->json(['error' => 'You have reached the paper conversion limit. Please try again after it resets.'], 429);
                }
                RateLimiter::hit($rateLimitKey, 86400);

                try {
                    $generated = $generator->generateFromText($text);
                } catch (DeepSeekGenerationException $exception) {
                    Log::warning('Student PDF conversion failed', ['error' => $exception->getMessage()]);
                    return response()->json(['error' => 'Could not turn this PDF into questions. Please try another PDF.'], 502);
                }
                $rows = $generated['questions'] ?? [];
                $suggestedTitle = (string) ($generated['quiz_title'] ?? '');
            } catch (Throwable $exception) {
                Log::warning('Student uploaded PDF could not be parsed', ['error' => $exception->getMessage()]);
                return response()->json(['error' => 'Could not read this PDF. Please try a text-based PDF.'], 422);
            } finally {
                $absolute = storage_path('app/'.$path);
                if (is_file($absolute)) @unlink($absolute);
            }
        }

        $normalized = $importer->normalizeMany($rows);
        if (count($normalized['rows']) === 0) {
            return response()->json([
                'error' => 'No valid questions were found. Check the PDF or JSON and try again.',
                'warnings' => $normalized['errors'],
            ], 422);
        }

        $courseId = Course::query()->where('is_active', true)->orderBy('sort_order')->value('id');
        abort_if(! $courseId, 503, 'Paper uploads are temporarily unavailable.');
        $title = trim((string) ($validated['title'] ?? '')) ?: trim($suggestedTitle) ?: pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME);
        $user = $request->user();

        $quiz = DB::transaction(function () use ($courseId, $title, $normalized, $importer, $user) {
            $quiz = Quiz::query()->create([
                'course_id' => $courseId,
                'week_id' => null,
                'section' => 'practice',
                'title' => mb_substr($title, 0, 200),
                'description' => 'Private test created from your upload.',
                'time_limit_minutes' => null,
                'price_paise' => 0,
                'is_active' => true,
                'approval_status' => 'approved',
                'created_by' => $user->id,
                'reviewed_by' => null,
                'reviewed_at' => null,
                'is_personal' => true,
                'owner_user_id' => $user->id,
            ]);
            $importer->persist($quiz->id, $normalized['rows']);
            return $quiz;
        });

        return response()->json([
            'id' => $quiz->id,
            'title' => $quiz->title,
            'question_count' => count($normalized['rows']),
            'warnings' => $normalized['errors'],
        ], 201);
    }

    private function looksLikeQuestionPaper(string $text): bool
    {
        $numberedQuestions = preg_match_all('/(?:^|\R)\s*(?:Q(?:uestion)?\s*\.?\s*)?\d{1,3}\s*[.)\]:-]\s+/iu', $text);
        $taskLanguage = preg_match('/\b(?:choose|select|calculate|solve|find|determine|evaluate|which|what|answer|true or false)\b|\?/iu', $text);

        return $numberedQuestions >= 1 && $taskLanguage === 1;
    }
}
