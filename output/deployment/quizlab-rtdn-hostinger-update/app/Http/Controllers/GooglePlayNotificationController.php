<?php

namespace App\Http\Controllers;

use App\Models\ProSubscription;
use App\Services\GooglePlayMembershipSync;
use App\Services\GooglePlayPushAuthentication;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class GooglePlayNotificationController extends Controller
{
    public function __invoke(Request $request, GooglePlayPushAuthentication $auth, GooglePlayMembershipSync $sync): Response
    {
        $auth->verify($request);
        $subscriptionName = (string) config('services.google_play.rtdn_subscription');
        $package = (string) config('services.google_play.package_name');
        $product = (string) config('services.google_play.subscription_product_id');
        abort_if($subscriptionName === '' || $package === '' || $product === '', 503, 'Play notifications are not configured.');
        abort_if(strlen($request->getContent()) > 65536, 413, 'Notification too large.');
        $body = $request->validate([
            'subscription' => ['required', 'string', 'max:500'],
            'message.messageId' => ['required', 'string', 'max:200'],
            'message.data' => ['required', 'string', 'max:48000'],
        ]);
        abort_unless(hash_equals($subscriptionName, $body['subscription']), 403, 'Unexpected Pub/Sub subscription.');
        $decoded = base64_decode($body['message']['data'], true);
        $event = $decoded === false ? null : json_decode($decoded, true);
        abort_unless(is_array($event), 400, 'Invalid notification data.');
        abort_unless(($event['packageName'] ?? null) === $package, 403, 'Unexpected app package.');

        $isTest = isset($event['testNotification']) && is_array($event['testNotification']);
        $notification = $event['subscriptionNotification'] ?? null;
        $voided = $event['voidedPurchaseNotification'] ?? null;
        $kind = $isTest ? 'test' : (is_array($notification) ? 'subscription' : (is_array($voided) ? 'voided' : 'unsupported'));
        $payload = is_array($notification) ? $notification : (is_array($voided) ? $voided : []);
        $token = $payload['purchaseToken'] ?? '';
        // Current Google messages omit subscriptionId. The linked ledger row
        // and the subsequent Developer API read determine the actual product.
        $relevant = ($kind === 'subscription' && (! isset($payload['subscriptionId']) || $payload['subscriptionId'] === $product))
            || ($kind === 'voided' && ($payload['productType'] ?? null) === 1);
        abort_if($relevant && (! is_string($token) || $token === '' || strlen($token) > 4096), 400, 'Invalid purchase token.');
        $messageId = $body['message']['messageId'];

        try {
            DB::table('google_play_notifications')->insertOrIgnore([
                'message_id' => $messageId,
                'kind' => $kind,
                'notification_type' => is_int($payload['notificationType'] ?? null) && $payload['notificationType'] >= 0 && $payload['notificationType'] <= 65535 ? $payload['notificationType'] : null,
                'purchase_token_hash' => $relevant ? hash('sha256', $token) : null,
                'status' => 'pending', 'attempts' => 0, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $done = DB::transaction(function () use ($messageId, $relevant, $token, $sync, $isTest, $product) {
                $receipt = DB::table('google_play_notifications')->where('message_id', $messageId)->lockForUpdate()->first();
                if (in_array($receipt->status, ['processed', 'ignored'], true)) return true;
                DB::table('google_play_notifications')->where('id', $receipt->id)->increment('attempts');
                if ($relevant) {
                    $subscription = ProSubscription::query()->where('provider', 'google_play')
                        ->where('product_id', $product)
                        ->where('provider_reference_hash', hash('sha256', $token))->first();
                    if (! $subscription) {
                        // RTDN may arrive before the app verifies its first
                        // purchase. Retry; never guess which student owns it.
                        DB::table('google_play_notifications')->where('id', $receipt->id)
                            ->update(['status' => 'unlinked', 'last_error' => 'purchase_not_linked', 'updated_at' => now()]);
                        return false;
                    }
                    $sync->refresh($subscription);
                }
                DB::table('google_play_notifications')->where('id', $receipt->id)->update([
                    'status' => $relevant || $isTest ? 'processed' : 'ignored',
                    'last_error' => null, 'processed_at' => now(), 'updated_at' => now(),
                ]);
                return true;
            }, 3);
        } catch (Throwable) {
            // No purchase tokens, credentials, or provider exception URLs in logs.
            Log::warning('Play notification processing failed; Pub/Sub should retry.', ['message_id' => $messageId]);
            return response()->json(['message' => 'Notification processing temporarily unavailable.'], 503);
        }
        if (! $done) return response()->json(['message' => 'Waiting for purchase account verification.'], 503);

        // Only acknowledge after state and receipt are durably committed.
        return response()->noContent();
    }
}
