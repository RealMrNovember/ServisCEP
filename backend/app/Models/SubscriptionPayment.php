<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * TeknikCEP'e yapılan, sağlayıcı tarafından doğrulanmış abonelik ödemesi.
 *
 * [Payment] ile KARIŞTIRILMAMALI: o model kullanıcının kendi müşterisinden
 * aldığı tahsilattır ve cari hesaba işler. Bu model bizim tahsilatımızdır.
 *
 * [PaymentRequest] ile de farklıdır: orası "havale yaptım" beyanı ve admin
 * onayı, burası gerçekten tahsil edilmiş para.
 */
class SubscriptionPayment extends Model
{
    use HasUuids;

    public const STATUS_PENDING = 'PENDING';

    public const STATUS_PAID = 'PAID';

    public const STATUS_FAILED = 'FAILED';

    public const DURATION_MONTHLY = 'MONTHLY';

    public const DURATION_YEARLY = 'YEARLY';

    protected $fillable = [
        'company_id', 'plan_id', 'requested_by_user_id',
        'amount_minor', 'currency', 'duration',
        'provider', 'provider_ref', 'status', 'provider_payload', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount_minor' => 'integer',
            'provider_payload' => 'array',
            'paid_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }
}
