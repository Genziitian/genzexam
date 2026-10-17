<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class MembershipTransaction extends Model {
    protected $fillable = ['user_id', 'pro_subscription_id', 'provider', 'reference', 'status', 'amount_paise', 'currency', 'paid_at'];
    protected function casts(): array { return ['amount_paise' => 'integer', 'paid_at' => 'datetime']; }
}
