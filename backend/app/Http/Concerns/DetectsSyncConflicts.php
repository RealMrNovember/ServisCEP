<?php

declare(strict_types=1);

namespace App\Http\Concerns;

use App\Models\FieldChange;
use App\Models\User;
use App\Services\SyncConflictService;
use App\Support\SyncOutcome;
use Illuminate\Database\Eloquent\Model;

/**
 * Optimistic concurrency uygulaması — bkz. ROADMAP.md § B10. İstemci
 * son gördüğü `base_version`'ı gönderir; sunucudaki `version` hâlâ
 * aynıysa güncelleme uygulanır (HasVersion trait'i version'ı otomatik
 * artırır).
 *
 * Sürümler uyuşmuyorsa güncelleme SESSİZCE EZİLMEZ. Ama otomatik olarak
 * çakışma da sayılmaz: sürüm uyuşmazlığı "aynı anda düzenlendi" demektir,
 * "aynı şey düzenlendi" demek değildir. Ofis müşterinin telefonunu, saha
 * görevlisi notunu değiştirmişse kimse kimsenin işini ezmiyor — ikisi de
 * uygulanabilir ve kimsenin karar vermesi gerekmiyor.
 *
 * Bu ayrımı yapabilmek için iki bilgi gerekiyor:
 *
 *   1. İstemci hangi alanları değiştirdi → `changed_fields` ile gelir.
 *      Gelen yük TÜM alanları içeriyor (istemci kaydın tamamını
 *      gönderiyor), dolayısıyla yüke bakarak anlaşılamaz.
 *   2. Sunucu hangi alanları değiştirdi → FieldChange izinden okunur.
 *
 * İkisinden biri eksikse çakışma kaydedilir. Eksik bilgiyle birleştirmek,
 * görünmeyen bir değişikliği sessizce ezmek olurdu — bu mekanizmanın
 * engellemek için var olduğu şeyin ta kendisi.
 */
trait DetectsSyncConflicts
{
    /**
     * Güncellemenin uygulanıp uygulanamayacağına karar verir — modeli
     * GÜNCELLEMEZ. Çağıran, sonuçtaki `data`'yı kendi `update()`'ine verir.
     *
     * Bu ayrım, güncellemeyle aynı transaction içinde ek iş yapması
     * gereken çağıranlar (ör. JobController'ın cari borç mantığı) için
     * gereklidir.
     *
     * @param  array<string, mixed>  $data
     * @param  list<string>  $changedFields  istemcinin değiştirdiğini bildirdiği alanlar
     */
    private function resolveVersionConflict(
        SyncConflictService $syncConflictService,
        User $user,
        Model $model,
        string $subjectType,
        array $data,
        int $baseVersion,
        array $changedFields = [],
    ): SyncOutcome {
        $sunucuSurumu = (int) $model->version;

        if ($baseVersion === $sunucuSurumu) {
            return SyncOutcome::clean($data);
        }

        $birlestirilmis = $this->tryFieldMerge($model, $data, $baseVersion, $sunucuSurumu, $changedFields);

        if ($birlestirilmis !== null) {
            return SyncOutcome::merged($birlestirilmis, array_keys($birlestirilmis));
        }

        return SyncOutcome::conflicted($syncConflictService->record(
            $user, $subjectType, $model->getKey(), $baseVersion, $sunucuSurumu, $data, $model->toArray()
        ));
    }

    /**
     * İki taraf farklı alanlara dokunduysa uygulanacak alt kümeyi döner;
     * aksi halde null.
     *
     * @param  array<string, mixed>  $data
     * @param  list<string>  $changedFields
     * @return array<string, mixed>|null
     */
    private function tryFieldMerge(
        Model $model,
        array $data,
        int $baseVersion,
        int $sunucuSurumu,
        array $changedFields,
    ): ?array {
        // Eski istemciler `changed_fields` göndermiyor. Onlar için
        // davranış bugünkiyle aynı kalmalı — hangi alanları
        // değiştirdiklerini bilmeden birleştirmek tahmin yürütmek olurdu.
        if ($changedFields === []) {
            return null;
        }

        // İstemci sunucudan İLERİ bir sürüm bildiriyorsa elimizdeki tablo
        // yanlış: sayaç sıfırlanmış ya da kayıt geri yüklenmiş olabilir.
        // Böyle bir durumda birleştirme kararı verilemez.
        if ($baseVersion > $sunucuSurumu) {
            return null;
        }

        $tablo = $model->getTable();
        $anahtar = (string) $model->getKey();

        // Budama eski izleri siliyor. İz eksikse "sunucu bir şey
        // değiştirmedi" sonucuna varmak, gerçek bir değişikliği sessizce
        // ezmek olurdu.
        if (! FieldChange::hasCompleteTrail($tablo, $anahtar, $baseVersion, $sunucuSurumu)) {
            return null;
        }

        $sunucununDegistirdikleri = FieldChange::betweenVersions($tablo, $anahtar, $baseVersion, $sunucuSurumu);

        if (array_intersect($changedFields, $sunucununDegistirdikleri) !== []) {
            return null;
        }

        // Yalnızca istemcinin değiştirdiği alanlar uygulanır. Yükün geri
        // kalanı istemcinin ESKİ görüşü — uygulanırsa sunucudaki yeni
        // değerlerin üzerine yazar ve birleştirmenin anlamı kalmaz.
        $uygulanacak = array_intersect_key($data, array_flip($changedFields));

        return $uygulanacak === [] ? null : $uygulanacak;
    }
}
