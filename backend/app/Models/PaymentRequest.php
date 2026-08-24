<?php

namespace App\Models;

use App\Notifications\NewPaymentRequestReceived;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;

class PaymentRequest extends Model
{
    use HasUuids;

    protected static function booted(): void
    {
        // Hem web (Filament App panel) hem mobil API'den oluşturulan her
        // yeni talep adminlere e-postayla bildirilir — onay akışı tamamen
        // manuel olduğu için talebin beklediğinin fark edilmesi buna bağlı.
        // Mail hatası talebin kendisini asla düşürmemeli (talep DB'de,
        // panelde her durumda görünür).
        static::created(function (PaymentRequest $paymentRequest): void {
            if ($paymentRequest->status !== 'PENDING') {
                return;
            }

            try {
                Notification::send(AdminUser::all(), new NewPaymentRequestReceived($paymentRequest));
            } catch (\Throwable $e) {
                Log::error('Ödeme talebi admin bildirimi gönderilemedi', [
                    'payment_request_id' => $paymentRequest->id,
                    'error' => $e->getMessage(),
                ]);
            }
        });
    }

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'requested_by_user_id', 'plan_id', 'approved_plan_id',
        'claimed_amount_minor', 'requested_duration', 'customer_note', 'status',
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

    public function approvedPlan(): BelongsTo
    {
        return $this->belongsTo(Plan::class, 'approved_plan_id');
    }

    public function reviewedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }

    /**
     * Ödeme talebini onaylar ve şirketin aboneliğini seçilen süre kadar
     * uzatır. Mevcut süre henüz dolmamışsa üzerine eklenir (erken yenileme
     * hak kaybına yol açmaz) — bkz. docs/10 § SaaS Vizyonu.
     *
     * $approvedPlanId admin'in fiilen onayladığı pakettir — müşterinin
     * talep ettiği plan_id ile aynı olmak zorunda değildir (örn. müşteri
     * yüksek paket seçip düşük paket bedeli göndermiş olabilir). Bu ayrım
     * kasıtlıdır: plan_id "talep edilen", approved_plan_id "onaylanan"
     * paketi temsil eder, ikisi de audit amaçlı korunur.
     */
    public function approve(string $duration, AdminUser $admin, ?string $note = null, ?string $approvedPlanId = null): void
    {
        $service = app(\App\Services\SubscriptionService::class);
        $planId = $approvedPlanId ?: $this->plan_id;

        // Süre hesabı TEK kaynaktan gelir (SubscriptionService) — admin
        // panelindeki "Süre Uzat" aksiyonu da aynı kuralı kullanır, ikisi
        // ayrı yazıldığı sürece birbirinden sapma riski vardı.
        $previousExpiry = $this->company->subscription_expires_at;

        $company = $service->apply(
            $this->company,
            months: $duration === 'YEARLY' ? 12 : 1,
            planId: $planId ?: null,
        );

        $this->update([
            'status' => 'APPROVED',
            'approved_plan_id' => $planId,
            'approved_duration' => $duration,
            'admin_note' => $note,
            'reviewed_by_admin_id' => $admin->id,
            'reviewed_at' => Carbon::now(),
        ]);

        // Bildirim, abonelik yazıldıktan SONRA gönderilir: gönderim hatası
        // onayı geri almamalı (bkz. FcmService).
        $service->notifyChanged($company, $previousExpiry);
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
