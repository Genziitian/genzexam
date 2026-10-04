<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;

class ExamPlatformController extends Controller
{
    protected function getStateFilePath(): string
    {
        $dir = storage_path('app');
        if (!File::isDirectory($dir)) {
            File::makeDirectory($dir, 0755, true);
        }
        return storage_path('app/exam_state.json');
    }

    protected function getDefaultState(): array
    {
        $questions = [
            [
                'id' => 'q1',
                'sectionId' => 'sec-a',
                'type' => 'mcq_single',
                'marks' => 2,
                'negative' => 0.5,
                'prompt' => 'What is the output of the following Python slice operation on a list?',
                'code' => "x = [1, 2, 3, 4, 5]\nprint(x[::-1])",
                'options' => ['[1, 2, 3, 4, 5]', '[5, 4, 3, 2, 1]', '(5, 4, 3, 2, 1)', 'SyntaxError'],
                'correct' => 1,
                'explanation' => 'Slice x[::-1] steps backward through list x from end to start, reversing it to [5, 4, 3, 2, 1].'
            ],
            [
                'id' => 'q2',
                'sectionId' => 'sec-a',
                'type' => 'mcq_multi',
                'marks' => 2,
                'negative' => 0.5,
                'prompt' => 'Which of the following statements correctly create a Python dictionary? (Select all that apply)',
                'code' => null,
                'options' => [
                    "d = {'roll': 101, 'name': 'Aditi'}",
                    "d = dict(roll=101, name='Aditi')",
                    "d = { ('id', 1): 'admin' }",
                    "d = { ['id']: 'admin' }"
                ],
                'correct' => [0, 1, 2],
                'explanation' => "Tuples are immutable and hashable, so ('id', 1) is a valid dict key. Lists are mutable and cannot be dict keys."
            ],
            [
                'id' => 'q3',
                'sectionId' => 'sec-a',
                'type' => 'true_false',
                'marks' => 2,
                'negative' => 0.5,
                'prompt' => 'In Python, a standard dictionary preserves insertion order of keys starting from Python 3.7+.',
                'code' => null,
                'options' => ['True', 'False'],
                'correct' => 0,
                'explanation' => 'Starting in Python 3.7, dict insertion order is an official part of the Python language specification.'
            ],
            [
                'id' => 'q4',
                'sectionId' => 'sec-a',
                'type' => 'numerical',
                'marks' => 2,
                'negative' => 0,
                'prompt' => 'What is the returned integer value of the following set length expression?',
                'code' => 'len(set([10, 20, 20, 30, 10, 40, 50]))',
                'correct' => 5,
                'explanation' => 'Unique values in [10, 20, 20, 30, 10, 40, 50] are {10, 20, 30, 40, 50}, which has 5 elements.'
            ],
            [
                'id' => 'q5',
                'sectionId' => 'sec-b',
                'type' => 'mcq_single',
                'marks' => 3,
                'negative' => 1.0,
                'prompt' => 'What is the worst-case time complexity of searching in a balanced Binary Search Tree (AVL tree) of N nodes?',
                'code' => null,
                'options' => ['O(1)', 'O(log N)', 'O(N)', 'O(N log N)'],
                'correct' => 1,
                'explanation' => 'Balanced BSTs (AVL / Red-Black) maintain height of O(log N), so search is guaranteed O(log N) in worst case.'
            ],
            [
                'id' => 'q6',
                'sectionId' => 'sec-b',
                'type' => 'short_answer',
                'marks' => 3,
                'negative' => 0,
                'prompt' => 'What keyword is used in Python inside an inner function to modify a variable defined in the enclosing (non-global) scope?',
                'code' => null,
                'correct' => 'nonlocal',
                'explanation' => "The 'nonlocal' keyword binds an inner function variable to its closest enclosing non-global scope."
            ],
            [
                'id' => 'q7',
                'sectionId' => 'sec-b',
                'type' => 'mcq_single',
                'marks' => 3,
                'negative' => 1.0,
                'prompt' => 'What will be printed when running this generator function?',
                'code' => "def gen():\n    yield 1\n    yield 2\n\ng = gen()\nnext(g)\nprint(next(g))",
                'options' => ['1', '2', 'StopIteration', 'None'],
                'correct' => 1,
                'explanation' => 'First next(g) yields 1. Second next(g) yields 2 and print() outputs 2.'
            ],
            [
                'id' => 'q8',
                'sectionId' => 'sec-b',
                'type' => 'numerical',
                'marks' => 3,
                'negative' => 0,
                'prompt' => 'Calculate the exact output value of the arithmetic precedence expression:',
                'code' => "res = 2 ** 3 * 2 + 10 // 3\nprint(res)",
                'correct' => 19,
                'explanation' => '2**3 = 8; 8*2 = 16; 10//3 = 3; 16 + 3 = 19.'
            ]
        ];

        $allowedEmails = [];

        return [
            'activeView' => 'login',
            'studentActiveTab' => 'scheduled_exams',
            'activeOnboardingModal' => null,
            'currentUser' => [
                'id' => 'candidate',
                'name' => 'Candidate',
                'email' => '',
                'role' => 'student',
            ],
            'exam' => [
                'id' => 'iitm-python-endterm',
                'title' => 'GenZ IITian — Python & Computational Thinking Endterm',
                'subject' => 'Python Programming & Data Structures',
                'type' => 'final',
                'status' => 'live',
                'resultsPublished' => false,
                'durationMinutes' => 60,
                'extendedMinutes' => 0,
                'startedAt' => (int)(microtime(true) * 1000) - (15 * 60 * 1000),
                'instructions' => 'No outside aids permitted. Exiting the exam window requires manager approval to re-enter.',
                'chatEnabled' => true,
                'allowedEmails' => $allowedEmails,
                'sections' => [
                    ['id' => 'sec-coc', 'title' => 'Code of Conduct (COC)', 'isCoc' => true],
                    ['id' => 'sec-a', 'title' => 'Section A: Core Concepts', 'marksEach' => 2, 'negativeEach' => 0.5],
                    ['id' => 'sec-b', 'title' => 'Section B: Algorithmic Logic & Output', 'marksEach' => 3, 'negativeEach' => 1.0],
                ],
                'questions' => $questions,
            ],
            'reentryRequests' => [],
            'studentSessions' => (object)[],
            'chatMessages' => [
                [
                    'id' => 'msg-1',
                    'senderName' => 'Exam Manager',
                    'role' => 'manager',
                    'text' => 'Welcome students. Ensure your internet connection is stable. Leaving the window triggers re-entry lock.',
                    'timestamp' => (int)(microtime(true) * 1000) - (14 * 60 * 1000),
                    'isAnnouncement' => true,
                ],
            ],
        ];
    }

    protected function loadState(): array
    {
        $path = $this->getStateFilePath();
        if (File::exists($path)) {
            $content = File::get($path);
            $decoded = json_decode($content, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
        $default = $this->getDefaultState();
        $this->saveState($default);
        return $default;
    }

    protected function saveState(array $state): void
    {
        $path = $this->getStateFilePath();
        File::put($path, json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }

    public function health(): JsonResponse
    {
        return response()->json([
            'status' => 'ok',
            'service' => 'genzexam-laravel-backend',
            'timestamp' => microtime(true),
        ]);
    }

    public function state(): JsonResponse
    {
        return response()->json($this->loadState());
    }

    public function syncState(Request $request): JsonResponse
    {
        $payload = $request->all();
        $state = $this->loadState();

        if (isset($payload['exam']) && is_array($payload['exam'])) {
            $state['exam'] = array_merge($state['exam'] ?? [], $payload['exam']);
        }
        if (isset($payload['studentSessions']) && is_array($payload['studentSessions'])) {
            $state['studentSessions'] = array_merge($state['studentSessions'] ?? [], $payload['studentSessions']);
        }
        if (isset($payload['chatMessages']) && is_array($payload['chatMessages'])) {
            $state['chatMessages'] = $payload['chatMessages'];
        }
        if (isset($payload['reentryRequests']) && is_array($payload['reentryRequests'])) {
            $state['reentryRequests'] = $payload['reentryRequests'];
        }
        if (isset($payload['activeView'])) {
            $state['activeView'] = $payload['activeView'];
        }
        if (isset($payload['studentActiveTab'])) {
            $state['studentActiveTab'] = $payload['studentActiveTab'];
        }

        $this->saveState($state);
        return response()->json(['success' => true, 'state' => $state]);
    }

    public function action(Request $request): JsonResponse
    {
        $action = $request->input('action');
        $state = $this->loadState();

        switch ($action) {
            case 'start_exam':
                $state['exam']['status'] = 'live';
                $state['exam']['startedAt'] = (int)(microtime(true) * 1000);
                break;

            case 'pause_exam':
                $state['exam']['status'] = 'paused';
                break;

            case 'resume_exam':
                $state['exam']['status'] = 'live';
                break;

            case 'end_exam':
                $state['exam']['status'] = 'ended';
                foreach ($state['studentSessions'] as $email => &$sess) {
                    if (in_array($sess['status'] ?? '', ['in_progress', 'not_started'])) {
                        $sess['status'] = 'submitted';
                        $sess['submittedAt'] = (int)(microtime(true) * 1000);
                    }
                }
                break;

            case 'extend_time':
                $mins = (int)$request->input('minutes', 5);
                $state['exam']['extendedMinutes'] = ($state['exam']['extendedMinutes'] ?? 0) + $mins;
                break;

            case 'toggle_type':
                $state['exam']['type'] = $request->input('type', 'final');
                break;

            case 'publish_results':
                $state['exam']['resultsPublished'] = (bool)$request->input('resultsPublished', true);
                break;

            case 'add_whitelist':
                $email = $request->input('email');
                if ($email && !in_array($email, $state['exam']['allowedEmails'] ?? [])) {
                    $state['exam']['allowedEmails'][] = $email;
                }
                break;

            case 'remove_whitelist':
                $email = $request->input('email');
                if ($email) {
                    $state['exam']['allowedEmails'] = array_values(array_filter(
                        $state['exam']['allowedEmails'] ?? [],
                        fn($e) => $e !== $email
                    ));
                }
                break;

            case 'sync_student_session':
                $email = $request->input('email');
                $updates = $request->input('updates', []);
                if ($email && is_array($updates)) {
                    $existing = $state['studentSessions'][$email] ?? [];
                    $state['studentSessions'][$email] = array_merge($existing, $updates, [
                        'lastActive' => (int)(microtime(true) * 1000)
                    ]);
                }
                break;

            case 'request_reentry':
                $req = $request->input('request');
                if ($req && is_array($req)) {
                    $state['reentryRequests'][] = $req;
                }
                break;

            case 'approve_reentry':
                $reqId = $request->input('requestId');
                $email = $request->input('email');
                foreach ($state['reentryRequests'] as &$r) {
                    if (($r['id'] ?? '') === $reqId) {
                        $r['status'] = 'approved';
                    }
                }
                if ($email && isset($state['studentSessions'][$email])) {
                    $state['studentSessions'][$email]['status'] = 'in_progress';
                }
                break;

            case 'reject_reentry':
                $reqId = $request->input('requestId');
                foreach ($state['reentryRequests'] as &$r) {
                    if (($r['id'] ?? '') === $reqId) {
                        $r['status'] = 'rejected';
                    }
                }
                break;

            case 'lock_session':
                $email = $request->input('email');
                if ($email && isset($state['studentSessions'][$email])) {
                    $state['studentSessions'][$email]['status'] = 'reentry_required';
                }
                break;

            default:
                return response()->json(['error' => "Unknown action: {$action}"], 400);
        }

        $this->saveState($state);
        return response()->json(['success' => true, 'action' => $action, 'state' => $state]);
    }

    public function getChat(): JsonResponse
    {
        $state = $this->loadState();
        return response()->json($state['chatMessages'] ?? []);
    }

    public function sendChat(Request $request): JsonResponse
    {
        $msg = $request->input('message');
        if (!$msg || !is_array($msg)) {
            return response()->json(['error' => 'Missing message object'], 400);
        }

        if (empty($msg['id'])) {
            $msg['id'] = 'msg-' . (int)(microtime(true) * 1000);
        }
        if (empty($msg['timestamp'])) {
            $msg['timestamp'] = (int)(microtime(true) * 1000);
        }

        $state = $this->loadState();
        $state['chatMessages'][] = $msg;
        $this->saveState($state);

        return response()->json(['success' => true, 'message' => $msg]);
    }

    public function getReentry(): JsonResponse
    {
        $state = $this->loadState();
        return response()->json($state['reentryRequests'] ?? []);
    }

    public function resetState(): JsonResponse
    {
        $state = $this->getDefaultState();
        $this->saveState($state);
        return response()->json(['success' => true, 'state' => $state]);
    }
}
