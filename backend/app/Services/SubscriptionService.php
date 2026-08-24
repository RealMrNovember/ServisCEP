<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\AdminUser;
use App\Models\AuditLog;
use App\Models\Company;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Abonelik süresi hesaplama ve uzatma — TEK kaynak.
 *
 * Bu mantık daha önce iki yerde ayrı ayrı yazılıydı: ödeme talebi onayı
 * (PaymentRequest::approve) ve admin panelindeki "Süre Uzat" aksiyonu.
 * İkisi aynı kuralı uygulamak zorunda ("mevcut süre gelecekteyse üzerine
 * ekle, değilse bugünden başlat") — ayrı durdukları sürece biri
 * değiştiğinde diğerinin unutulması an meselesiydi.
 */
class SubscriptionService
{
    public function __construct(private readonly FcmService $fcm)
    {
    }

    /**
     * Uzatmanın başlangıç noktası: süre henüz dolmadıysa üzerine eklenir
     * (erken yenileme hak kaybettirmez), dolduysa bugünden başlar.
     */
    public function extensionBase(Company $company): Carbon
    {
        return $company->subscription_expires_at?->isFuture()
            ? $company->subscription_expires_at->copy()
            : Carbon::now();
    }

    /**
     * Verilen süre kadar uzatıldığında oluşacak bitiş tarihi — kaydetmez.
     * Arayüzde "önizleme" göstermek için de kullanılır.
     */
    public function previewExtension(Company $company, int $months, int $days): Carbon
    {
        return $this->extensionBase($company)->addMonths($months)->addDays($days);
    }

    /**
     * Aboneliği uzatır/ayarlar ve şirketi aktif eder.
     *
     * @param  Carbon|null  $exactDate  Verilirse süre EKLENMEZ, bitiş
     *                                  doğrudan bu tarihe ayarlanır.
     */
    public function apply(
        Company $company,
        int $months = 0,
        int $days = 0,
        ?string $planId = null,
        ?Carbon $exactDate = null,
        ?string $note = null,
    ): Company {
        return DB::transaction(function () use ($company, $months, $days, $planId, $exactDate, $note) {
            // Eşzamanlı iki uzatmanın birbirini ezmemesi için kilit.
            $locked = Company::whereKey($company->id)->lockForUpdate()->first();

            $locked->subscription_expires_at = $exactDate
                ?? $this->previewExtension($locked, $months, $days);
            $locked->is_active = true;

            if ($planId !== null) {
                $locked->plan_id = $planId;
            }
            if ($note !== null && $note !== '') {
                $locked->admin_note = $note;
            }

            $locked->save();

            return $locked->refresh();
        });
    }

    /**
     * Süper-admin işlemi için denetim kaydı.
     *
     * `user_id` bilerek null: işlemi yapan bir tenant kullanıcısı değil,
     * süper-admin'dir (ayrı tablo). Kim olduğu `meta` içinde saklanır.
     */
    public function recordAdminAudit(Company $company, AdminUser $admin, string $action, string $description, array $meta = []): void
    {
        AuditLog::create([
            'company_id' => $company->id,
            'user_id' => null,
            'action' => $action,
            'subject_type' => 'company',
            'subject_id' => $company->id,
            'description' => $description,
            'meta' => $meta + ['admin_email' => $admin->email],
        ]);
    }

    /**
     * Müşteriyi bilgilendirir — abonelik uzatıldığında kullanıcının bunu
     * uygulamayı açmadan öğrenmesi gerekir.
     */
    public function notifyExtended(Company $company): void
    {
        $company->loadMissing('plan');

        $this->fcm->sendToCompany(
            $company,
            'Aboneliğin uzatıldı',
            sprintf(
                '%s paketi %s tarihine kadar geçerli.',
                $company->plan?->name ?? 'Paketin',
                $company->subscription_expires_at?->translatedFormat('d F Y') ?? '-'
            ),
            ['type' => 'subscription_extended'],
        );
    }
}
