<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Customer;
use Illuminate\Console\Command;

/**
 * Geri dönüşüm kutusu temizliği — bkz. ROADMAP.md § B10. 3 günden eski
 * ve hiçbir iş/tahsilat/belge geçmişi olmayan müşteriler gerçekten
 * silinir. Gerçek geçmişi olan bir müşteri veritabanı seviyesinde zaten
 * silinemez (ilişkili tablolar restrictOnDelete) — bu komut yalnızca
 * "yanlışlıkla oluşturulup hemen silinmiş, hiç kullanılmamış" kayıtları
 * temizler; asıl veri güvenliği FK kısıtlamalarından gelir.
 */
class PurgeDeletedCustomers extends Command
{
    protected $signature = 'customers:purge-trash {--days=3}';

    protected $description = '3+ gündür silinmiş ve hiç iş geçmişi olmayan müşterileri kalıcı olarak siler';

    public function handle(): int
    {
        $days = (int) $this->option('days');

        $candidates = Customer::onlyTrashed()
            ->where('deleted_at', '<=', now()->subDays($days))
            ->get();

        $purged = 0;
        $skipped = 0;

        foreach ($candidates as $customer) {
            $hasHistory = $customer->jobs()->withTrashed()->exists()
                || $customer->quotes()->exists()
                || $customer->proformas()->exists()
                || $customer->payments()->exists()
                || $customer->ledgerEntries()->exists();

            if ($hasHistory) {
                $skipped++;

                continue;
            }

            $customer->forceDelete();
            $purged++;
        }

        $this->info("Kalıcı silinen: {$purged}, geçmişi olduğu için atlanan: {$skipped}");

        return self::SUCCESS;
    }
}
