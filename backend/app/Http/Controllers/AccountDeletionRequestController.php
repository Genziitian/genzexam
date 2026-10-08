<?php

namespace App\Http\Controllers;

use App\Models\AccountDeletionRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

class AccountDeletionRequestController extends Controller
{
    private const REASONS = [
        'no_longer_needed' => 'I no longer need the account',
        'privacy_concerns' => 'Privacy concerns',
        'another_account' => 'I am using another account',
        'app_issue' => 'I had an issue with the app',
        'other' => 'Other',
    ];

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'in:'.implode(',', array_keys(self::REASONS))],
            'details' => ['nullable', 'string', 'max:1200'],
        ]);
        $user = $request->user();

        $deletionRequest = AccountDeletionRequest::create([
            'user_id' => $user->id,
            'user_name' => $user->name,
            'user_email' => $user->email,
            'user_role' => $user->effectiveRole(),
            'account_created_at' => $user->created_at,
            'reason' => self::REASONS[$validated['reason']],
            'details' => trim((string) ($validated['details'] ?? '')) ?: null,
        ]);

        $mailSent = false;
        try {
            $accountCreated = $user->created_at?->toDateTimeString() ?? 'Unavailable';
            $body = implode("\n", [
                'Hello QUIZ LAB team,',
                $user->name.' has requested deletion of their account and all associated data.',
                '',
                'Account details',
                'Name: '.$user->name,
                'Email: '.$user->email,
                'User ID: '.$user->id,
                'Role: '.$user->effectiveRole(),
                'Account created: '.$accountCreated,
                '',
                'Reason: '.$deletionRequest->reason,
                'Additional details: '.($deletionRequest->details ?: 'None provided'),
                'Request ID: '.$deletionRequest->id,
                'Submitted: '.$deletionRequest->created_at->toDateTimeString().' UTC',
            ]);
            Mail::raw($body, function ($message) use ($user): void {
                $message->to('admin@genziitian.org')
                    ->subject('Account deletion request from '.$user->name);
            });
            $mailSent = true;
        } catch (Throwable $error) {
            Log::error('Could not email account deletion request', [
                'request_id' => $deletionRequest->id,
                'message' => $error->getMessage(),
            ]);
        }

        return response()->json([
            'request' => $this->serializeRequest($deletionRequest),
            'mail_sent' => $mailSent,
            'message' => 'Your request was sent to the manager for review. Your account has not been deleted yet.',
        ], 201);
    }

    public function index(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');

        $requests = AccountDeletionRequest::query()
            ->latest()
            ->get()
            ->map(fn (AccountDeletionRequest $row) => $this->serializeRequest($row));

        return response()->json(['requests' => $requests]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        abort_unless($request->user()?->isManager(), 403, 'Manager access is required.');
        $validated = $request->validate(['status' => ['required', 'in:pending,reviewing,completed']]);
        $deletionRequest = AccountDeletionRequest::query()->findOrFail($id);
        $deletionRequest->update(['status' => $validated['status']]);

        return response()->json(['request' => $this->serializeRequest($deletionRequest->fresh())]);
    }

    private function serializeRequest(AccountDeletionRequest $row): array
    {
        return [
            'id' => $row->id,
            'user_id' => $row->user_id,
            'name' => $row->user_name,
            'email' => $row->user_email,
            'role' => $row->user_role,
            'account_created_at' => $row->account_created_at?->toISOString(),
            'reason' => $row->reason,
            'details' => $row->details,
            'status' => $row->status,
            'created_at' => $row->created_at?->toISOString(),
        ];
    }
}
