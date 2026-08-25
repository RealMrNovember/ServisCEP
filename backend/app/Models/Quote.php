<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use App\Models\Concerns\HasVersion;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Quote extends Model
{
    use BelongsToCompany, HasFactory, HasUuids, HasVersion;

    public $timestamps = false;

    protected $fillable = ['id', 'company_id', 'code', 'customer_id', 'status', 'notes', 'total_minor',
        'currency', 'vat_mode', 'vat_rate', 'valid_until',
        'intro_text', 'payment_terms', 'delivery_time', 'warranty_terms',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'total_minor' => 'integer',
            'version' => 'integer',
            'vat_rate' => 'integer',
            'valid_until' => 'date',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(QuoteItem::class);
    }
}
