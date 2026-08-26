<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\FieldChange;
use Illuminate\Console\Command;

/**
 * Eski alan değişikliği izlerini siler.
 *
 * İz yalnızca ÇAKIŞMA ÇÖZÜMÜNDE işe yarıyor: telefon çevrimdışıyken
 * yapılan bir değişikliğin, sunucudakiyle aynı alana dokunup dokunmadığını
 * anlamak için. Kayıt senkronlandığı anda o sürümün izi ölü ağırlığa
 * dönüşüyor.
 *
 * 90 gün, bir cihazın çevrimdışı kalabileceği en uzun makul süreden kat
 * kat fazla. Daha kısa tutmanın bedeli var: iz eksikse birleştirme
 * REDDEDİLİR ve çakışma insana gider (bkz. FieldChange::hasCompleteTrail).
 * Yani dar bir pencere veri kaybettirmez, yalnızca otomatik çözülebilecek
 * çakışmaları elle çözülür hâle getirir.
 */
class PruneFieldChanges extends Command
{
    protected $signature = 'sync:prune-field-changes {--days=90 : izlerin saklanma süresi}';

    protected $description = 'Çakışma çözümü için tutulan eski alan izlerini siler';

    public function handle(): int
    {
        $gun = max(7, (int) $this->option('days'));

        $silinen = FieldChange::query()
            ->where('created_at', '<', now()->subDays($gun))
            ->delete();

        $this->info("Silinen iz kaydı: {$silinen}");

        return self::SUCCESS;
    }
}
