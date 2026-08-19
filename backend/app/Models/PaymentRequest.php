<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class PaymentRequest extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'requested_by_user_id', 'plan_id',
        'claimed_amount_minor', 'customer_note', 'status',
        'approved_duration', 'admin_note', 'reviewed_by_admin_id', 'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'claimed_amount_minor' => 'integer',
            'created_at' => 'datetime',
            'reviewed_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function requestedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by_user_id');
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }

    /**
     * Ödeme talebini onaylar ve şirketin aboneliğini seçilen süre kadar
     * uzatır. Mevcut süre henüz dolmamışsa üzerine eklenir (erken yenileme
     * hak kaybına yol açmaz) — bkz. docs/10 § SaaS Vizyonu.
     */
    public function approve(string $duration, AdminUser $admin, ?string $note = null): void
    {
        DB::transaction(function () use ($duration, $admin, $note) {
            $company = $this->company()->lockForUpdate()->first();
            $base = $company->subscription_expires_at?->isFuture()
                ? $company->subscription_expires_at
                : Carbon::now();

            $company->subscription_expires_at = $duration === 'YEARLY'
                ? $base->copy()->addYear()
                : $base->copy()->addMonth();
            $company->is_active = true;
            if ($this->plan_id) {
                $company->plan_id = $this->plan_id;
            }
            $company->save();

            $this->update([
                'status' => 'APPROVED',
                'approved_duration' => $duration,
                'admin_note' => $note,
                'reviewed_by_admin_id' => $admin->id,
                'reviewed_at' => Carbon::now(),
            ]);
        });
    }

    public function reject(AdminUser $admin, ?string $note = null): void
    {
        $this->update([
            'status' => 'REJECTED',
            'admin_note' => $note,
            'reviewed_by_admin_id' => $admin->id,
            'reviewed_at' => Carbon::now(),
        ]);
    }
}
