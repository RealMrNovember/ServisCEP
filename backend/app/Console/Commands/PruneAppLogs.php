<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\AppLog;
use Illuminate\Console\Command;

/**
 * Eski günlük kayıtlarını siler.
 *
 * Saklama süresi seviyeye göre farklı: sıradan bilgi kayıtları hızla
 * değerini yitirir ama bir `error` kaydı, haftalar sonra "bu ne zaman
 * başladı" sorusunu cevaplayabilir. Tek bir süre uygulamak ya tabloyu
 * şişirir ya da teşhis için gereken geçmişi yok eder.
 *
 * Süreler bilinçli olarak GENİŞ ve budama HAFTALIK çalışır. Sebebi
 * yaşanmış: seyrek görülen, yalnızca belirli bir cihazda ortaya çıkan bir
 * arıza günlerce fark edilmedi. Dar bir saklama penceresi, o arıza fark
 * edildiğinde kanıtın çoktan silinmiş olması demekti. Disk, kaybedilen
 * teşhis süresinden ucuz.
 */
class PruneAppLogs extends Command
{
    protected $signature = 'logs:prune
        {--info-days=30 : info/debug kayıtlarının saklanma süresi}
        {--days=180 : uyarı ve hataların saklanma süresi}';

    protected $description = 'Eski uygulama günlüğü kayıtlarını siler';

    public function handle(): int
    {
        $infoDays = max(1, (int) $this->option('info-days'));
        $days = max($infoDays, (int) $this->option('days'));

        $lowValue = AppLog::query()
            ->whereIn('level', ['debug', 'info', 'notice'])
            ->where('created_at', '<', now()->subDays($infoDays))
            ->delete();

        $rest = AppLog::query()
            ->where('created_at', '<', now()->subDays($days))
            ->delete();

        $this->info("Silinen kayıt: bilgi $lowValue, diğer $rest");

        return self::SUCCESS;
    }
}
