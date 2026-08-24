<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use App\Models\Concerns\HasVersion;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Proforma extends Model
{
    use BelongsToCompany, HasFactory, HasUuids, HasVersion;

    public $timestamps = false;

    protected $fillable = ['id', 'company_id', 'code', 'customer_id', 'valid_until', 'notes', 'total_minor',
        'currency', 'vat_mode', 'vat_rate',
    ];

    protected function casts(): array
    {
        return [
            'valid_until' => 'datetime',
            'created_at' => 'datetime',
            'total_minor' => 'integer',
            'vat_rate' => 'integer',
            'version' => 'integer',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(ProformaItem::class);
    }
}
