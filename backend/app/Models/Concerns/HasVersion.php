<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Model;

/**
 * Optimistic concurrency sürüm sayacı — bkz. ROADMAP.md § B10. Model
 * seviyesinde uygulanır ki hangi yoldan güncellenirse güncellensin
 * (mobil API, web paneli/Filament, tinker...) `version` her zaman
 * artar; kontrolör bunu atlayamaz.
 */
trait HasVersion
{
    public static function bootHasVersion(): void
    {
        static::updating(function (Model $model) {
            $model->version = ((int) ($model->version ?? 1)) + 1;
        });
    }
}
