<?php

namespace App\Http\Controllers;

use App\Models\ProctoredExam;
use App\Models\ProctoredExamAuditLog;
use App\Models\ProctoredExamEnrollment;
use App\Models\ProctoredExamEvent;
use App\Models\ProctoredExamMessage;
use App\Models\ProctoredExamSession;
use App\Models\User;
use App\Services\ProctoredQuestionService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ExamPlatformController extends Controller
{
    public function __construct(private readonly ProctoredQuestionService $questionService)
    {
    }

    public function health(): JsonResponse
    {
        return response()->json(['status' => 'ok', 'service' => 'proctored-exams']);
    }

    public function legacyGone(): JsonResponse
    {
        return response()->json([
            'error' => 'This legacy singleton exam API has been retired. Use /exam-platform/exams and the per-exam API.',
            'code' => 'legacy_exam_api_retired',
        ], 410);
    }

    /** Finalize live exams that reached their server-side deadline. */
    public function expireDueExams(): int
    {
        $ids = ProctoredExam::query()->where('status', 'live')->whereNotNull('started_at')->select('id')->lazyById(100);
        $expired = 0;
        foreach ($ids as $id) {
            if ($this->expireExamIfNeeded((string) $id->id)) $expired++;
        }
        return $expired;
    }

    public function index(Request $request): JsonResponse
    {
        $request->validate(['page' => ['sometimes', 'integer', 'min:1', 'max:100000']]);
        $user = $request->user();
        $query = ProctoredExam::query()->select(['id','owner_id','title','subject','instructions','duration_minutes','extension_minutes','max_warnings','scheduled_at','status','results_published','question_count','created_at','updated_at']);
        if ($user->isManager()) {
            $query->where('owner_id', $user->id)->withCount(['enrollments', 'sessions']);
        } else {
            abort_unless(!$user->hasAdminAccess(), 403, 'Only managers and enrolled candidates can access exams.');
            $query->whereIn('id', ProctoredExamEnrollment::query()->select('exam_id')->whereIn('email', $this->normalizedEmailsForUser($user)))
                ->whereIn('status', ['published', 'live', 'paused', 'ended', 'archived']);
        }
        $page = $query->latest()->orderByDesc('id')->simplePaginate(50);
        return response()->json([
            'exams' => $page->getCollection()->map(fn (ProctoredExam $exam) => $user->isManager() ? $this->managerExam($exam, false) : $this->candidateExamMetadata($exam))->values(),
            'next_page' => $page->hasMorePages() ? $page->currentPage() + 1 : null,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'subject' => ['nullable', 'string', 'max:200'],
            'instructions' => ['nullable', 'string', 'max:10000'],
            'duration_minutes' => ['required', 'integer', 'min:1', 'max:600'],
            'max_warnings' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'scheduled_at' => ['nullable', 'date'],
        ]);

        $data['subject'] = $data['subject'] ?? '';

        $exam = DB::transaction(function () use ($data, $request) {
            $exam = ProctoredExam::create([
                ...$data,
                'owner_id' => $request->user()->id,
                'status' => 'draft',
                'results_published' => false,
                'questions' => [],
            ]);
            $this->recordAudit($exam, $request->user(), 'exam.created', ['title' => $exam->title]);
            return $exam;
        });

        return response()->json(['exam' => $this->managerExam($exam, true)], 201);
    }

    public function show(Request $request, string $exam): JsonResponse
    {
        $this->findAccessibleExam($request, $exam);
        $this->expireExamIfNeeded($exam);
        $record = $this->findAccessibleExam($request, $exam);
        if ($request->user()->isManager()) {
            return response()->json(['exam' => $this->managerExam($record, true)]);
        }

        return response()->json(['exam' => $this->candidateExamMetadata($record)]);
    }

    public function update(Request $request, string $exam): JsonResponse
    {
        $record = $this->ownedExam($request->user(), $exam);
        abort_unless($record->status === 'draft', 409, 'Published exam configuration is immutable.');
        $data = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:200'],
            'subject' => ['sometimes', 'nullable', 'string', 'max:200'],
            'instructions' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'duration_minutes' => ['sometimes', 'required', 'integer', 'min:1', 'max:600'],
            'max_warnings' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'scheduled_at' => ['sometimes', 'nullable', 'date'],
        ]);
        abort_if($data === [], 422, 'No exam configuration fields were provided.');
        if (array_key_exists('subject', $data)) $data['subject'] = $data['subject'] ?? '';

        DB::transaction(function () use ($record, $data, $request) {
            $locked = ProctoredExam::query()->whereKey($record->id)->lockForUpdate()->firstOrFail();
            abort_unless($locked->status === 'draft', 409, 'Published exam configuration is immutable.');
            $locked->fill($data)->save();
            $this->recordAudit($locked, $request->user(), 'exam.updated', ['fields' => array_keys($data)]);
        });

        return response()->json(['exam' => $this->managerExam($record->fresh(), true)]);
    }

    public function importQuestions(Request $request, string $exam): JsonResponse
    {
        $record = $this->ownedExam($request->user(), $exam);
        abort_unless($record->status === 'draft', 409, 'Questions cannot be changed after publication.');
        $data = $request->validate(['questions' => ['required', 'array', 'min:1', 'max:500']]);
        $questions = $this->questionService->normalize($data['questions']);

        DB::transaction(function () use ($record, $questions, $request) {
            $locked = ProctoredExam::query()->whereKey($record->id)->lockForUpdate()->firstOrFail();
            abort_unless($locked->status === 'draft', 409, 'Questions cannot be changed after publication.');
            $locked->questions = $questions;
            $locked->question_count = count($questions);
            $locked->save();
            $this->recordAudit($locked, $request->user(), 'questions.imported', ['count' => count($questions)]);
        });

        return response()->json(['exam' => $this->managerExam($record->fresh(), true)]);
    }

    public function replaceEnrollments(Request $request, string $exam): JsonResponse
    {
        $record = $this->ownedExam($request->user(), $exam);
        abort_unless(in_array($record->status, ['draft', 'published'], true), 409, 'Enrollments are locked after the exam starts.');
        $data = $request->validate(['emails' => ['present', 'array', 'max:1000'], 'emails.*' => ['required', 'email', 'max:254']]);
        $emails = array_values(array_unique(array_map(fn ($email) => mb_strtolower(trim($email)), $data['emails'])));

        DB::transaction(function () use ($record, $request, $emails) {
            $locked = ProctoredExam::query()->whereKey($record->id)->lockForUpdate()->firstOrFail();
            abort_unless(in_array($locked->status, ['draft', 'published'], true), 409, 'Enrollments are locked after the exam starts.');
            $users = User::query()->whereIn(DB::raw('LOWER(email)'), $emails)->get()->keyBy(fn (User $u) => mb_strtolower($u->email));
            $locked->enrollments()->delete();
            foreach ($emails as $email) {
                $locked->enrollments()->create([
                    'email' => $email,
                    'user_id' => $users->get($email)?->id,
                    'added_by' => $request->user()->id,
                ]);
            }
            $this->recordAudit($locked, $request->user(), 'enrollments.replaced', ['count' => count($emails)]);
        });

        return response()->json(['exam' => $this->managerExam($record->fresh(), true)]);
    }

    public function action(Request $request, string $exam): JsonResponse
    {
        $data = $request->validate([
            'action' => ['required', 'in:publish,start,pause,resume,end,extend,publish_results,archive'],
            'minutes' => ['required_if:action,extend', 'integer', 'min:1', 'max:180'],
        ]);

        $this->ownedExam($request->user(), $exam);
        $this->expireExamIfNeeded($exam);
        $record = DB::transaction(function () use ($request, $exam, $data) {
            $locked = $this->ownedExam($request->user(), $exam, true);
            $action = $data['action'];
            $now = now();
            $details = [];
            switch ($action) {
                case 'publish':
                    abort_unless($locked->status === 'draft', 409, 'Only a draft can be published.');
                    abort_if(count($locked->questions ?? []) === 0, 422, 'Import at least one question before publishing.');
                    $locked->status = 'published';
                    break;
                case 'start':
                    abort_unless($locked->status === 'published', 409, 'Only a published exam can start.');
                    abort_if($locked->scheduled_at && $locked->scheduled_at->isFuture(), 409, 'The scheduled start time has not arrived.');
                    $locked->status = 'live';
                    $locked->started_at = $now;
                    break;
                case 'pause':
                    abort_unless($locked->status === 'live', 409, 'Only a live exam can be paused.');
                    $locked->status = 'paused';
                    $locked->paused_at = $now;
                    break;
                case 'resume':
                    abort_unless($locked->status === 'paused', 409, 'Only a paused exam can be resumed.');
                    $locked->paused_seconds += $locked->paused_at ? max(0, $now->getTimestamp() - $locked->paused_at->getTimestamp()) : 0;
                    $locked->paused_at = null;
                    $locked->status = 'live';
                    break;
                case 'extend':
                    abort_unless(in_array($locked->status, ['live', 'paused'], true), 409, 'Only a live or paused exam can be extended.');
                    abort_if($locked->extension_minutes + (int) $data['minutes'] > 600, 422, 'An exam can be extended by at most 600 minutes in total.');
                    $locked->extension_minutes += (int) $data['minutes'];
                    $details['minutes'] = (int) $data['minutes'];
                    break;
                case 'end':
                    abort_unless(in_array($locked->status, ['published', 'live', 'paused'], true), 409, 'This exam cannot be ended from its current state.');
                    if ($locked->status === 'paused' && $locked->paused_at) {
                        $locked->paused_seconds += max(0, $now->getTimestamp() - $locked->paused_at->getTimestamp());
                        $locked->paused_at = null;
                    }
                    $locked->status = 'ended';
                    $locked->ended_at = $now;
                    $this->finalizeActiveSessions($locked, $now, $request->user());
                    break;
                case 'publish_results':
                    abort_unless($locked->status === 'ended', 409, 'End the exam before publishing results.');
                    $locked->results_published = true;
                    break;
                case 'archive':
                    abort_unless($locked->status === 'ended', 409, 'Only an ended exam can be archived.');
                    $locked->status = 'archived';
                    break;
            }
            $locked->save();
            $this->recordAudit($locked, $request->user(), 'exam.action.' . $action, $details);
            return $locked;
        });

        return response()->json(['exam' => $this->managerExam($record->fresh(), true)]);
    }

    public function state(Request $request, string $exam): JsonResponse
    {
        $user = $request->user();
        $compact = $request->boolean('compact');
        $this->findAccessibleExam($request, $exam, $compact);
        $this->expireExamIfNeeded($exam);
        $record = $this->findAccessibleExam($request, $exam, $compact);
        $now = now();
        if ($user->isManager()) {
            return response()->json([
                'exam' => $this->managerExam($record, !$compact),
                'session' => null,
                'sessions' => $record->sessions()->with('user:id,name,email')->orderBy('id')->get()
                    ->map(fn (ProctoredExamSession $session) => $this->sessionForManager($session)),
                'server_now' => $now->toIso8601String(),
                'remaining_seconds' => $this->remainingSeconds($record, $now),
                'messages' => $this->messagesFor($record, $user),
            ]);
        }

        $session = $record->sessions()->where('user_id', $user->id)->first();
        $messages = $this->messagesFor($record, $user);
        $sessionData = $session ? $this->sessionForCandidate($session, $record) : null;
        if ($compact && $sessionData) unset($sessionData['answers'], $sessionData['score_breakdown']);
        return response()->json([
            'exam' => $compact ? $this->candidateExamMetadata($record) : $this->candidateExam($record, $session),
            'session' => $sessionData,
            'server_now' => $now->toIso8601String(),
            'remaining_seconds' => $this->remainingSeconds($record, $now),
            'messages' => $messages,
        ]);
    }

    public function join(Request $request, string $exam): JsonResponse
    {
        $request->validate(['acceptedRules' => ['required', 'accepted']]);
        $user = $request->user();
        $this->findAccessibleExam($request, $exam);
        $this->expireExamIfNeeded($exam);
        $session = DB::transaction(function () use ($request, $exam, $user) {
            $record = $this->candidateExamRecord($user, $exam, true);
            abort_unless($record->status === 'live', 409, 'This exam is not live.');
            abort_if(($record->scheduled_at && $record->scheduled_at->isFuture()) || $this->remainingSeconds($record, now()) <= 0, 409, 'The exam is not currently accepting candidates.');
            $session = ProctoredExamSession::query()->where('exam_id', $record->id)->where('user_id', $user->id)->lockForUpdate()->first();
            if (!$session) {
                $session = ProctoredExamSession::create([
                    'exam_id' => $record->id, 'user_id' => $user->id, 'status' => 'in_exam',
                    'warnings' => 0, 'revision' => 0, 'answers' => [], 'joined_at' => now(),
                ]);
                $this->recordAudit($record, $user, 'candidate.joined');
            } else {
                abort_if($session->status !== 'in_exam', 409, 'This candidate session is locked or already submitted.');
            }
            return $session;
        });

        $record = ProctoredExam::findOrFail($exam);
        return response()->json(['session' => $this->sessionForCandidate($session, $record)], 201);
    }

    public function saveAnswers(Request $request, string $exam): JsonResponse
    {
        $data = $request->validate([
            'answers' => ['present', 'array', 'max:500'],
            'revision' => ['required', 'integer', 'min:0'],
        ]);
        $user = $request->user();
        $this->candidateExamRecord($user, $exam);
        $this->expireExamIfNeeded($exam);
        $result = DB::transaction(function () use ($request, $exam, $user, $data) {
            $record = $this->candidateExamRecord($user, $exam, true);
            abort_unless($record->status === 'live', 409, 'Answers can only be changed during a live exam.');
            $session = ProctoredExamSession::query()->where('exam_id', $record->id)->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            abort_unless($session->status === 'in_exam', 409, 'This candidate session is not writable.');
            $this->assertNotExpired($record);
            abort_unless((int) $data['revision'] === $session->revision, 409, 'Answer revision is stale.', ['revision' => $session->revision]);
            $answers = $session->answers ?? [];
            foreach ($data['answers'] as $questionId => $answer) {
                if ($answer === null) {
                    unset($answers[$questionId]);
                } else {
                    $answers[$questionId] = $answer;
                }
            }
            $answers = $this->questionService->validateAnswers($record->questions ?? [], $answers);
            $session->answers = $answers;
            $session->revision++;
            $session->save();
            return [$record, $session];
        });

        return response()->json(['session' => $this->sessionForCandidate($result[1], $result[0])]);
    }

    public function submit(Request $request, string $exam): JsonResponse
    {
        $data = $request->validate([
            'answers' => ['sometimes', 'array', 'max:500'],
            'revision' => ['sometimes', 'integer', 'min:0'],
        ]);
        $user = $request->user();
        $this->candidateExamRecord($user, $exam);
        $this->expireExamIfNeeded($exam);
        [$record, $session] = DB::transaction(function () use ($request, $exam, $user, $data) {
            $record = $this->candidateExamRecord($user, $exam, true);
            $session = ProctoredExamSession::query()->where('exam_id', $record->id)->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            if ($session->status === 'submitted') {
                return [$record, $session]; // Idempotent finalization; never rescore altered payloads.
            }
            abort_unless($session->status === 'in_exam', 409, 'This candidate session cannot be submitted.');
            abort_unless(in_array($record->status, ['live', 'ended'], true), 409, 'The exam is not accepting submissions.');
            abort_if($record->status === 'ended', 409, 'This candidate session was finalized when the exam ended.');
            $expired = $this->remainingSeconds($record, now()) <= 0;
            if (array_key_exists('answers', $data)) {
                abort_if($expired, 409, 'The exam deadline has passed; submit the last server-saved answers.');
                abort_unless(isset($data['revision']) && (int) $data['revision'] === $session->revision, 409, 'Answer revision is stale.', ['revision' => $session->revision]);
                $answers = $data['answers'];
            } else {
                $answers = $session->answers ?? [];
                if (isset($data['revision'])) {
                    abort_unless((int) $data['revision'] === $session->revision, 409, 'Answer revision is stale.', ['revision' => $session->revision]);
                }
            }
            $answers = $this->questionService->validateAnswers($record->questions ?? [], $answers);
            $score = $this->questionService->score($record->questions ?? [], $answers);
            $session->answers = $answers;
            $session->score = $score['score'];
            $session->total_marks = $score['total_marks'];
            $session->score_breakdown = $score['breakdown'];
            $session->status = 'submitted';
            $session->submitted_at = now();
            $session->revision++;
            $session->save();
            $this->recordAudit($record, $user, 'candidate.submitted', ['revision' => $session->revision]);
            return [$record, $session];
        });

        return response()->json([
            'session' => $this->sessionForCandidate($session, $record),
            'score' => $record->results_published && in_array($record->status, ['ended', 'archived'], true) ? $session->score : null,
            'total_marks' => $record->results_published && in_array($record->status, ['ended', 'archived'], true) ? $session->total_marks : null,
            'status' => $session->status,
            'submitted_at' => $session->submitted_at?->toIso8601String(),
        ]);
    }

    public function events(Request $request, string $exam): JsonResponse
    {
        $data = $request->validate([
            'id' => ['required', 'uuid'],
            'type' => ['required', 'in:blur,fullscreen_exit,visibility_hidden,camera_unavailable'],
        ]);
        $user = $request->user();
        $this->candidateExamRecord($user, $exam);
        $this->expireExamIfNeeded($exam);
        [$record, $session, $inserted] = DB::transaction(function () use ($request, $exam, $user, $data) {
            $record = $this->candidateExamRecord($user, $exam, true);
            abort_unless($record->status === 'live', 409, 'Proctoring events are only accepted during a live exam.');
            $session = ProctoredExamSession::query()->where('exam_id', $record->id)->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            $exists = ProctoredExamEvent::query()->where('exam_id', $record->id)->where('user_id', $user->id)->where('client_event_id', $data['id'])->exists();
            if ($exists) {
                return [$record, $session, false];
            }
            abort_unless($session->status === 'in_exam', 409, 'This candidate session is not active.');
            ProctoredExamEvent::create([
                'exam_id' => $record->id, 'user_id' => $user->id,
                'client_event_id' => $data['id'], 'type' => $data['type'], 'occurred_at' => now(),
            ]);
            $session->warnings++;
            if ($session->warnings >= $record->max_warnings + $session->warning_allowance) {
                $session->status = 'locked';
            }
            $session->save();
            $this->recordAudit($record, $user, 'proctoring.event', ['type' => $data['type'], 'warnings' => $session->warnings]);
            return [$record, $session, true];
        });

        return response()->json(['session' => $this->sessionForCandidate($session, $record), 'recorded' => $inserted]);
    }

    public function sessionAction(Request $request, string $exam, string $targetUser): JsonResponse
    {
        $data = $request->validate(['action' => ['required', 'in:lock,unlock']]);
        $this->ownedExam($request->user(), $exam);
        $this->expireExamIfNeeded($exam);
        [$record, $session] = DB::transaction(function () use ($request, $exam, $targetUser, $data) {
            $record = $this->ownedExam($request->user(), $exam, true);
            $session = $record->sessions()->where('user_id', $targetUser)->lockForUpdate()->firstOrFail();
            if ($data['action'] === 'lock') {
                abort_unless($session->status === 'in_exam', 409, 'Only an active candidate can be locked.');
                $session->status = 'locked';
            } else {
                abort_unless($session->status === 'locked' && $record->status === 'live', 409, 'Only a locked session in a live exam can be unlocked.');
                $session->warning_allowance++;
                $session->status = 'in_exam';
            }
            $session->save();
            $this->recordAudit($record, $request->user(), 'candidate.session.' . $data['action'], ['user_id' => (int) $targetUser]);
            return [$record, $session];
        });

        return response()->json(['session' => $this->sessionForManager($session)]);
    }

    public function messages(Request $request, string $exam): JsonResponse
    {
        $record = $this->findAccessibleExam($request, $exam);
        return response()->json(['messages' => $this->messagesFor($record, $request->user())]);
    }

    public function sendMessage(Request $request, string $exam): JsonResponse
    {
        $data = $request->validate(['text' => ['required', 'string', 'max:2000']]);
        $record = $this->findAccessibleExam($request, $exam);
        $manager = $request->user()->isManager();
        abort_unless($manager || $record->status === 'live', 409, 'Candidate chat is not open.');
        if (!$manager) {
            $session = $record->sessions()->where('user_id', $request->user()->id)->first();
            abort_unless($session && in_array($session->status, ['in_exam', 'locked'], true), 409, 'Join the exam before using candidate chat.');
        }
        $text = trim($data['text']);
        abort_if($text === '', 422, 'Message cannot be blank.');
        $message = DB::transaction(function () use ($record, $request, $text, $manager) {
            $message = ProctoredExamMessage::create([
                'exam_id' => $record->id,
                'sender_id' => $request->user()->id,
                'text' => $text,
                'is_announcement' => $manager,
            ]);
            $this->recordAudit($record, $request->user(), $manager ? 'message.announced' : 'message.sent', ['message_id' => $message->id]);
            return $message;
        });

        return response()->json(['message' => $this->messageProjection($message)], 201);
    }

    public function export(Request $request, string $exam): StreamedResponse
    {
        $record = $this->ownedExam($request->user(), $exam);
        $filename = 'exam-' . $record->id . '-results.csv';
        return response()->streamDownload(function () use ($record) {
            $out = fopen('php://output', 'w');
            fputcsv($out, ['user_id', 'name', 'email', 'status', 'warnings', 'score', 'total_marks', 'submitted_at']);
            $record->sessions()->with('user:id,name,email')->orderBy('id')->chunk(200, function ($sessions) use ($out) {
                foreach ($sessions as $session) {
                    fputcsv($out, [
                        $session->user_id, $this->safeCsvCell($session->user?->name), $this->safeCsvCell($session->user?->email),
                        $session->status, $session->warnings,
                        $session->score, $session->total_marks,
                        $session->submitted_at?->toIso8601String(),
                    ]);
                }
            });
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function audit(Request $request, string $exam): JsonResponse
    {
        $record = $this->ownedExam($request->user(), $exam);
        $request->validate(['before' => ['sometimes', 'integer', 'min:1']]);
        $rows = $record->auditLogs()->with('actor:id,name,email')->when($request->input('before'), fn ($query, $before) => $query->where('id', '<', $before))->orderByDesc('id')->limit(501)->get();
        $hasMore = $rows->count() > 500;
        $logs = $rows->take(500)
            ->map(fn (ProctoredExamAuditLog $log) => [
                'id' => $log->id, 'actor' => $log->actor ? ['id' => $log->actor->id, 'name' => $log->actor->name, 'email' => $log->actor->email] : null,
                'event' => $log->event, 'details' => $log->details, 'created_at' => $log->created_at?->toIso8601String(),
            ]);
        return response()->json(['audit' => $logs->values(), 'next_before' => $hasMore ? $logs->last()['id'] : null]);
    }

    private function ownedExam(User $user, string $id, bool $lock = false, bool $metadataOnly = false): ProctoredExam
    {
        abort_unless($user->isManager(), 403, 'Manager access required.');
        $query = ProctoredExam::query()->whereKey($id)->where('owner_id', $user->id);
        if ($metadataOnly) $query->select(['id','owner_id','title','subject','instructions','duration_minutes','extension_minutes','max_warnings','scheduled_at','status','results_published','question_count','started_at','paused_at','paused_seconds','ended_at','created_at','updated_at']);
        if ($lock) $query->lockForUpdate();
        return $query->firstOrFail();
    }

    private function candidateExamRecord(User $user, string $id, bool $lock = false, bool $metadataOnly = false): ProctoredExam
    {
        abort_unless(!$user->hasAdminAccess(), 403, 'Only candidates may use candidate exam operations.');
        $emails = $this->normalizedEmailsForUser($user);
        $query = ProctoredExam::query()->whereKey($id);
        if ($metadataOnly) $query->select(['id','owner_id','title','subject','instructions','duration_minutes','extension_minutes','max_warnings','scheduled_at','status','results_published','question_count','started_at','paused_at','paused_seconds','ended_at','created_at','updated_at']);
        if ($lock) $query->lockForUpdate();
        $record = $query->firstOrFail();
        $enrollment = $record->enrollments()->whereIn('email', $emails)->first();
        abort_unless($enrollment !== null, 404, 'Exam not found.');
        if ($enrollment->user_id === null) {
            $enrollment->user_id = $user->id;
            $enrollment->save();
        }
        abort_unless($enrollment->user_id === $user->id, 404, 'Exam not found.');
        return $record;
    }

    private function findAccessibleExam(Request $request, string $id, bool $metadataOnly = false): ProctoredExam
    {
        return $request->user()->isManager()
            ? $this->ownedExam($request->user(), $id, false, $metadataOnly)
            : $this->candidateExamRecord($request->user(), $id, false, $metadataOnly);
    }

    private function normalizedEmailsForUser(User $user): array
    {
        return [mb_strtolower(trim($user->email))];
    }

    private function managerExam(ProctoredExam $exam, bool $withRelations): array
    {
        if (!isset($exam->enrollments_count)) $exam->loadCount(['enrollments', 'sessions']);
        $result = [
            'id' => $exam->id, 'title' => $exam->title, 'subject' => $exam->subject,
            'instructions' => $exam->instructions, 'duration_minutes' => $exam->duration_minutes,
            'extension_minutes' => $exam->extension_minutes, 'max_warnings' => $exam->max_warnings,
            'scheduled_at' => $exam->scheduled_at?->toIso8601String(), 'status' => $exam->status,
            'results_published' => $exam->results_published,
            'question_count' => (int) $exam->question_count,
            'enrollment_count' => $exam->enrollments_count, 'session_count' => $exam->sessions_count,
            'created_at' => $exam->created_at?->toIso8601String(), 'updated_at' => $exam->updated_at?->toIso8601String(),
        ];
        if ($withRelations) $result['questions'] = $exam->questions ?? [];
        if ($withRelations) {
            $result['enrollments'] = $exam->enrollments()->orderBy('email')->get(['email', 'user_id'])
                ->map(fn (ProctoredExamEnrollment $enrollment) => ['email' => $enrollment->email, 'user_id' => $enrollment->user_id])->values();
        }
        return $result;
    }

    private function candidateExamMetadata(ProctoredExam $exam): array
    {
        return [
            'id' => $exam->id, 'title' => $exam->title, 'subject' => $exam->subject,
            'instructions' => $exam->instructions, 'duration_minutes' => $exam->duration_minutes,
            'question_count' => (int) $exam->question_count, 'max_warnings' => $exam->max_warnings,
            'scheduled_at' => $exam->scheduled_at?->toIso8601String(), 'status' => $exam->status,
            'results_published' => $exam->results_published,
        ];
    }

    private function candidateExam(ProctoredExam $exam, ?ProctoredExamSession $session): array
    {
        $released = $exam->results_published && in_array($exam->status, ['ended', 'archived'], true);
        $questions = [];
        if ($session) {
            $questions = array_map(function (array $question) use ($released) {
                if (!$released) {
                    unset($question['correct_answer'], $question['correct_answers'], $question['acceptable_answers'], $question['numerical_answer'], $question['numerical_tolerance'], $question['explanation']);
                }
                return $question;
            }, $exam->questions ?? []);
        }
        return [...$this->candidateExamMetadata($exam), 'questions' => $questions];
    }

    private function sessionForCandidate(ProctoredExamSession $session, ProctoredExam $exam): array
    {
        $result = [
            'user_id' => $session->user_id, 'status' => $session->status,
            'warnings' => $session->warnings, 'warning_allowance' => $session->warning_allowance,
            'revision' => $session->revision,
            'answers' => $session->answers ?? [], 'joined_at' => $session->joined_at?->toIso8601String(),
            'submitted_at' => $session->submitted_at?->toIso8601String(),
        ];
        if ($exam->results_published && in_array($exam->status, ['ended', 'archived'], true)) {
            $result['score'] = $session->score;
            $result['total_marks'] = $session->total_marks;
            $result['score_breakdown'] = $session->score_breakdown;
        }
        return $result;
    }

    private function sessionForManager(ProctoredExamSession $session): array
    {
        return [
            'user_id' => $session->user_id, 'name' => $session->user?->name,
            'email' => $session->user?->email, 'status' => $session->status,
            'warnings' => $session->warnings, 'warning_allowance' => $session->warning_allowance,
            'revision' => $session->revision,
            'answered_count' => count(array_filter($session->answers ?? [], fn ($answer) => $answer !== null && $answer !== '' && $answer !== [])),
            'updated_at' => $session->updated_at?->toIso8601String(), 'score' => $session->score,
            'total_marks' => $session->total_marks,
            'submitted_at' => $session->submitted_at?->toIso8601String(),
        ];
    }

    private function remainingSeconds(ProctoredExam $exam, Carbon $now): ?int
    {
        if (in_array($exam->status, ['ended', 'archived'], true)) return 0;
        if (!$exam->started_at) return null;
        $elapsed = max(0, $now->getTimestamp() - $exam->started_at->getTimestamp());
        $paused = $exam->paused_seconds + ($exam->status === 'paused' && $exam->paused_at ? max(0, $now->getTimestamp() - $exam->paused_at->getTimestamp()) : 0);
        return max(0, ($exam->duration_minutes + $exam->extension_minutes) * 60 - $elapsed + $paused);
    }

    private function assertNotExpired(ProctoredExam $exam): void
    {
        abort_if($this->remainingSeconds($exam, now()) <= 0, 409, 'The exam deadline has passed.');
    }

    private function expireExamIfNeeded(string $id): bool
    {
        $current = ProctoredExam::select(['id','status','started_at','duration_minutes','extension_minutes','paused_at','paused_seconds'])->findOrFail($id);
        if ($current->status !== 'live' || $this->remainingSeconds($current, now()) > 0) return false;
        return DB::transaction(function () use ($id) {
            $exam = ProctoredExam::query()->whereKey($id)->lockForUpdate()->firstOrFail();
            $now = now();
            if ($exam->status !== 'live' || $this->remainingSeconds($exam, $now) > 0) {
                return false;
            }
            $exam->status = 'ended';
            $exam->ended_at = $now;
            $exam->save();
            $this->finalizeActiveSessions($exam, $now, null);
            $this->recordAudit($exam, null, 'exam.deadline_reached');
            return true;
        });
    }

    private function finalizeActiveSessions(ProctoredExam $exam, Carbon $now, ?User $actor): void
    {
        $exam->sessions()->whereIn('status', ['in_exam', 'locked'])->lockForUpdate()->get()->each(function (ProctoredExamSession $session) use ($exam, $now, $actor) {
            $answers = $this->questionService->validateAnswers($exam->questions ?? [], $session->answers ?? []);
            $score = $this->questionService->score($exam->questions ?? [], $answers);
            $session->answers = $answers;
            $session->score = $score['score'];
            $session->total_marks = $score['total_marks'];
            $session->score_breakdown = $score['breakdown'];
            $session->status = 'submitted';
            $session->submitted_at = $now;
            $session->revision++;
            $session->save();
            $this->recordAudit($exam, $actor, 'candidate.force_submitted', ['user_id' => $session->user_id]);
        });
    }

    private function messagesFor(ProctoredExam $exam, User $user): array
    {
        $query = $exam->messages()->with('sender:id,name,email,role,is_admin')->latest('id');
        if (!$user->isManager()) {
            $query->where(function (Builder $builder) use ($user) {
                $builder->where('sender_id', $user->id)
                    ->orWhere('is_announcement', true);
            });
        }
        return $query->limit(200)->get()->reverse()->values()->map(fn (ProctoredExamMessage $message) => $this->messageProjection($message))->all();
    }

    private function messageProjection(ProctoredExamMessage $message): array
    {
        return [
            'id' => $message->id, 'sender_id' => $message->sender_id,
            'sender_name' => $message->sender?->name,
            'sender_role' => $message->sender?->role ?? ($message->sender?->is_admin ? 'admin' : 'student'),
            'text' => $message->text, 'is_announcement' => $message->is_announcement,
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }

    private function recordAudit(ProctoredExam $exam, ?User $actor, string $event, array $details = []): void
    {
        ProctoredExamAuditLog::create([
            'exam_id' => $exam->id, 'actor_id' => $actor?->id,
            'event' => $event, 'details' => $details, 'created_at' => now(),
        ]);
    }

    private function safeCsvCell(?string $value): ?string
    {
        if ($value !== null && preg_match('/^[\s\x00-\x1f]*[=+@-]/u', $value)) {
            return "'".$value;
        }
        return $value;
    }
}
