<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\SyncConflict;

/**
 * Bir güncelleme denemesinin sonucu: uygulanabilir mi, yoksa insana mı
 * gitmeli.
 *
 * Üç durum var ve üçü de farklı davranış gerektiriyor, bu yüzden tek bir
 * `?SyncConflict` dönüşü yetmiyordu:
 *
 * - TEMİZ: sürümler uyuşuyor, gelen veri olduğu gibi uygulanır.
 * - BİRLEŞTİRİLDİ: sürümler uyuşmuyor ama iki taraf FARKLI alanlara
 *   dokunmuş — yalnızca istemcinin değiştirdiği alanlar uygulanır,
 *   sunucunun değiştirdikleri korunur.
 * - ÇAKIŞMA: aynı alan iki tarafta da değişmiş, ya da karar verecek
 *   bilgi yok. İnsana gider.
 */
final class SyncOutcome
{
    /**
     * @param  array<string, mixed>  $data
     * @param  list<string>  $mergedFields
     */
    private function __construct(
        public readonly ?SyncConflict $conflict,
        public readonly array $data,
        public readonly bool $wasMerged,
        public readonly array $mergedFields = [],
    ) {}

    /** @param array<string, mixed> $data */
    public static function clean(array $data): self
    {
        return new self(null, $data, false);
    }

    /**
     * @param  array<string, mixed>  $data  yalnızca istemcinin değiştirdiği alanlar
     * @param  list<string>  $mergedFields
     */
    public static function merged(array $data, array $mergedFields): self
    {
        return new self(null, $data, true, $mergedFields);
    }

    public static function conflicted(SyncConflict $conflict): self
    {
        return new self($conflict, [], false);
    }

    public function isConflict(): bool
    {
        return $this->conflict !== null;
    }
}
