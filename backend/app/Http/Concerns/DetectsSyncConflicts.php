<?php

declare(strict_types=1);

namespace App\Http\Concerns;

use App\Models\SyncConflict;
use App\Models\User;
use App\Services\SyncConflictService;
use Illuminate\Database\Eloquent\Model;

/**
 * Optimistic concurrency uygulaması — bkz. ROADMAP.md § B10. İstemci
 * son gördüğü `base_version`'ı gönderir; sunucudaki `version` hâlâ
 * aynıysa güncelleme uygulanır (HasVersion trait'i version'ı otomatik
 * artırır). Aynı değilse (ör. telefon offline'ken ofis değiştirmişse)
 * güncelleme SESSİZCE EZİLMEZ — bir SyncConflict kaydına düşer ve
 * çağıran 409 döner.
 */
trait DetectsSyncConflicts
{
    /**
     * Yalnızca sürüm uyuşmazlığını denetler ve varsa kaydeder — modeli
     * GÜNCELLEMEZ (çağıran, null dönerse kendi `update()`'ini çağırır).
     * Bu ayrım, güncellemeyle aynı transaction içinde ek iş yapması
     * gereken çağıranlar (ör. JobController'ın cari borç mantığı) için
     * gereklidir.
     *
     * @param  array<string, mixed>  $data
     */
    private function detectVersionConflict(
        SyncConflictService $syncConflictService,
        User $user,
        Model $model,
        string $subjectType,
        array $data,
        int $baseVersion,
    ): ?SyncConflict {
        if ($baseVersion !== (int) $model->version) {
            return $syncConflictService->record(
                $user, $subjectType, $model->getKey(), $baseVersion, (int) $model->version, $data, $model->toArray()
            );
        }

        return null;
    }
}
