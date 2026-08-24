<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Company;
use App\Services\FcmService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Süresi yaklaşan aboneliklere push hatırlatması — bkz. docs/01
 * "rahatsız etmeden hatırlat" ilkesi.
 *
 * Yalnızca belirli eşik günlerinde (3 ve 1 gün kala) tek bir bildirim
 * gönderilir; her gün tekrar tekrar bildirim atılmaz. Mobildeki kademeli
 * banner (SubscriptionBanner) uygulama AÇIKKEN uyarır; bu komut ise
 * uygulama kapalıyken hatırlatmayı üstlenir — ikisi birbirini tamamlar.
 */
class NotifyExpiringSubscriptions extends Command
{
    protected $signature = 'subscriptions:notify-expiring';

    protected $description = 'Süresi 3 veya 1 gün sonra dolacak aboneliklere push hatırlatması gönderir';

    /** Yalnızca bu eşiklerde bildirim gider. */
    private const THRESHOLD_DAYS = [3, 1];

    public function handle(FcmService $fcm): int
    {
        if (! $fcm->isConfigured()) {
            $this->warn('FCM yapılandırılmamış — bildirim gönderilmedi.');

            return self::SUCCESS;
        }

        $totalSent = 0;

        foreach (self::THRESHOLD_DAYS as $days) {
            $target = Carbon::today()->addDays($days);

            $companies = Company::query()
                ->where('is_active', true)
                ->whereBetween('subscription_expires_at', [
                    $target->copy()->startOfDay(),
                    $target->copy()->endOfDay(),
                ])
                ->with('plan')
                ->get();

            foreach ($companies as $company) {
                $isTrial = $company->plan?->slug === 'deneme';
                $noun = $isTrial ? 'Deneme süren' : 'Aboneliğin';

                $sent = $fcm->sendToCompany(
                    $company,
                    $days === 1 ? "$noun yarın sona eriyor" : "$noun $days gün sonra sona eriyor",
                    'Kesintisiz devam etmek için uygulamadan bir paket seçebilirsin.',
                    ['type' => 'subscription_expiring', 'days_remaining' => $days],
                );

                $totalSent += $sent;
            }
        }

        $this->info("Gönderilen bildirim sayısı: {$totalSent}");

        return self::SUCCESS;
    }
}
