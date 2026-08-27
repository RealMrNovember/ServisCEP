<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Models\FieldChange;
use Illuminate\Database\Eloquent\Model;

/**
 * Optimistic concurrency sürüm sayacı — bkz. ROADMAP.md § B10. Model
 * seviyesinde uygulanır ki hangi yoldan güncellenirse güncellensin
 * (mobil API, web paneli/Filament, tinker...) `version` her zaman
 * artar; kontrolör bunu atlayamaz.
 *
 * Aynı sebeple DEĞİŞEN ALANLARIN izi de burada tutuluyor: çakışma
 * çözümünün "sunucu tarafında ne değişti" sorusunu cevaplayabilmesi için
 * (bkz. FieldChange). İz kontrolörde tutulsaydı web panelinden yapılan
 * değişiklikler kayda geçmez, mobil güncellemesi sunucudakini ezerdi.
 */
trait HasVersion
{
    /**
     * İzde yeri olmayan alanlar.
     *
     * `version` ve `updated_at` her güncellemede değişir; ize girseler
     * her çakışma "aynı alan iki tarafta da değişti" görünür ve hiçbir
     * şey otomatik çözülemezdi.
     */
    private const IZ_DISI = ['version', 'updated_at', 'created_at'];

    public static function bootHasVersion(): void
    {
        static::updating(function (Model $model) {
            $model->version = ((int) ($model->version ?? 1)) + 1;
        });

        // `updated`, `updating` değil: iz ancak değişiklik gerçekten
        // kaydedildikten sonra yazılmalı. `updating` sırasında yazılsaydı
        // geri alınan bir transaction'dan sonra olmayan bir sürümün izi
        // kalırdı.
        static::updated(function (Model $model) {
            $alanlar = array_values(array_diff(
                array_keys($model->getChanges()),
                self::IZ_DISI,
            ));

            // Alan listesi BOŞ olsa bile satır yazılır. Sürümü artıran ama
            // anlamlı hiçbir alanı değiştirmeyen bir güncelleme (ör.
            // `touch()` yalnızca updated_at'i değiştirir) izde boşluk
            // bırakırdı; boşluk gören birleştirme, kendini güvende
            // hissetmediği için ÇAKIŞMA kaydeder. Yani sonuç veri kaybı
            // değil ama gereksiz elle iş olurdu. Boş küme hiçbir şeyle
            // kesişmediği için birleştirmeyi engellemez.
            FieldChange::create([
                'subject_type' => $model->getTable(),
                'subject_id' => (string) $model->getKey(),
                'version' => (int) $model->version,
                'fields' => $alanlar,
            ]);
        });
    }
}
