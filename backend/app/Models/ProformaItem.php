<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProformaItem extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'proforma_id', 'description', 'quantity', 'unit',
        'unit_price_minor', 'tax_rate', 'discount_minor',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_price_minor' => 'integer',
            'tax_rate' => 'integer',
            'discount_minor' => 'integer',
        ];
    }

    public function proforma(): BelongsTo
    {
        return $this->belongsTo(Proforma::class);
    }
}
