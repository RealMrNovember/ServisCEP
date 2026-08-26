<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Bir kaydın hangi sürümünde hangi alanların değiştiği.
 *
 * Yalnızca alan ADLARI tutulur, değerler değil — birleştirme kararı için
 * ad yeterli, değer saklamak bu tabloyu kaydın ikinci bir kopyasına
 * çevirirdi.
 */
class FieldChange extends Model
{
    public $timestamps = false;

    protected $fillable = ['subject_type', 'subject_id', 'version', 'fields'];

    protected function casts(): array
    {
        return [
            'version' => 'integer',
            'fields' => 'array',
            'created_at' => 'datetime',
        ];
    }

    /**
     * `$sonrasi` sürümünden sonra `$mevcut` sürümüne kadar değişen alanlar.
     *
     * Aralık AÇIK/KAPALI: base_version'ın kendisi istemcinin gördüğü hâl,
     * yani onu üreten değişiklik istemcide zaten var. Dahil edilseydi
     * istemcinin kendi bildiği bir değişiklik "sunucu değiştirdi" sayılır
     * ve her güncelleme çakışma olurdu.
     *
     * @return list<string>
     */
    public static function betweenVersions(string $subjectType, string $subjectId, int $sonrasi, int $mevcut): array
    {
        $satirlar = static::query()
            ->where('subject_type', $subjectType)
            ->where('subject_id', $subjectId)
            ->where('version', '>', $sonrasi)
            ->where('version', '<=', $mevcut)
            ->pluck('fields');

        return array_values(array_unique($satirlar->flatten()->all()));
    }

    /**
     * Aralıktaki HER sürümün izi elimizde mi?
     *
     * Budama eski satırları siliyor. İz eksikse "sunucu hiçbir şey
     * değiştirmedi" sonucuna varmak, gerçek bir değişikliği sessizce
     * ezmek olurdu — eksik iz, birleştirmeyi reddetmek için yeterli sebep.
     */
    public static function hasCompleteTrail(string $subjectType, string $subjectId, int $sonrasi, int $mevcut): bool
    {
        $beklenen = $mevcut - $sonrasi;

        if ($beklenen <= 0) {
            return false;
        }

        $bulunan = static::query()
            ->where('subject_type', $subjectType)
            ->where('subject_id', $subjectId)
            ->where('version', '>', $sonrasi)
            ->where('version', '<=', $mevcut)
            ->distinct()
            ->count('version');

        return $bulunan === $beklenen;
    }
}
