<?php
namespace App\Http\Controllers;
use App\Models\ProSubscription;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
class MembershipHistoryController extends Controller {
    public function show(Request $request): JsonResponse { return $this->history($request, (int) $request->user()->id, false); }
    public function manager(Request $request): JsonResponse {
        abort_unless($request->user()->isManager(), 403, 'Manager access required.');
        $request->validate(['user_id' => ['nullable','integer','exists:users,id'], 'search' => ['nullable','string','max:150']]);
        return $this->history($request, $request->filled('user_id') ? (int) $request->input('user_id') : null, true);
    }
    private function history(Request $request, ?int $userId, bool $manager): JsonResponse {
        $request->validate(['page' => ['nullable','integer','min:1'], 'per_page' => ['nullable','integer','min:1','max:100']]);
        $available = Schema::hasTable('membership_transactions');
        $paper = DB::table('quiz_storefront_orders')->selectRaw("id, user_id, 'paper' as type, 'razorpay' as provider, razorpay_payment_id as reference, status, amount_paise, currency, paid_at, created_at, 'Paper purchase' as title");
        $ledger = $available ? DB::table('membership_transactions')->selectRaw("id, user_id, 'membership' as type, provider, reference, status, amount_paise, currency, paid_at, created_at, 'Pro membership' as title") : null;
        if ($userId) { $paper->where('user_id', $userId); $ledger?->where('user_id', $userId); }
        $combined = $ledger ? $paper->unionAll($ledger) : $paper;
        $query = DB::query()->fromSub($combined, 'payments')->join('users', 'users.id', '=', 'payments.user_id')
            ->select('payments.*', 'users.name as user_name', 'users.email as user_email');
        if ($manager && $request->filled('search')) {
            $term = '%'.$request->string('search')->toString().'%';
            $query->where(fn ($q) => $q->where('users.email', 'like', $term)->orWhere('users.name', 'like', $term)->orWhere('payments.reference', 'like', $term));
        }
        $payments = $query->orderByDesc('payments.created_at')->orderByDesc('payments.id')->paginate((int) $request->input('per_page', 20));
        $payments->through(function ($row) {
            $row->id = $row->type.'-'.$row->id;
            $row->amount_paise = (int) $row->amount_paise;
            $row->user = ['id' => $row->user_id, 'name' => $row->user_name, 'email' => $row->user_email];
            unset($row->user_name, $row->user_email);
            return $row;
        });
        $subscriptions = ProSubscription::query()->with('user:id,name,email');
        if ($userId) $subscriptions->where('user_id', $userId);
        if ($manager && $request->filled('search')) {
            $term = '%'.$request->string('search')->toString().'%';
            $subscriptions->whereHas('user', fn ($q) => $q->where('name', 'like', $term)->orWhere('email', 'like', $term));
        }
        return response()->json([
            'user' => $userId ? User::query()->find($userId, ['id','name','email']) : null,
            // Explicit allowlist excludes purchase tokens, hashes, checkout URLs and private provider metadata.
            'subscriptions' => $subscriptions->latest('id')->limit(100)->get()->map(fn ($sub) => [
                'id' => $sub->id, 'provider' => $sub->provider, 'product_id' => $sub->product_id, 'status' => $sub->status,
                'amount_paise' => $sub->amount_paise, 'currency' => $sub->currency, 'started_at' => $sub->started_at,
                'paid_at' => $sub->paid_at, 'trial_ends_at' => $sub->trial_ends_at, 'current_period_ends_at' => $sub->current_period_ends_at,
                'cancel_at_period_end' => $sub->cancel_at_period_end, 'cancelled_at' => $sub->cancelled_at,
                'cancellation_source' => $sub->cancellation_source, 'created_at' => $sub->created_at, 'user' => $sub->user,
            ]),
            'transactions' => $payments, 'ledger_available' => $available,
            'history_note' => $available ? 'Paper orders and verified subscription receipts are shown. Membership records are not receipts. Earlier subscription renewals are not automatically reconstructed; Google receipts synchronize on purchase verification or membership refresh. Amounts are in the original currency.' : 'Subscription payment history requires the membership_transactions migration. Paper orders and membership records remain available.',
        ]);
    }
}
