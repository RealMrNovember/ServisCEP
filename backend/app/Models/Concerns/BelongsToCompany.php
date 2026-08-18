<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Şirket bazlı veri izolasyonu — bkz. docs/07 § 5 Şirket Bazlı Veri Ayrımı
 * (Multi-Tenancy).
 *
 * ⚠️ Bu, sistemin temel güvenlik prensibidir: bir şirket asla başka bir
 * şirketin verisini görememelidir. Bu trait'i kullanan her model, kimliği
 * doğrulanmış kullanıcının `company_id`'sine otomatik olarak scope edilir —
 * hem sorgularda (global scope) hem de oluşturmada (varsayılan değer).
 * Bireysel controller'larda bu filtreyi atlayan bir sorgu yazmak kritik bir
 * güvenlik açığı sayılır (bkz. docs/07 § 7 API Authorization Katmanları).
 */
trait BelongsToCompany
{
    public static function bootBelongsToCompany(): void
    {
        static::addGlobalScope('company', function (Builder $builder) {
            if ($companyId = auth()->user()?->company_id) {
                $builder->where($builder->getModel()->getTable().'.company_id', $companyId);
            }
        });

        static::creating(function (Model $model) {
            if (! $model->company_id && $companyId = auth()->user()?->company_id) {
                $model->company_id = $companyId;
            }
        });
    }

    public function scopeWithoutCompanyScope(Builder $query): Builder
    {
        return $query->withoutGlobalScope('company');
    }
}
