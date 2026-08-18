<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use BelongsToCompany, HasUuids, SoftDeletes;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'barcode', 'sku', 'name', 'brand', 'model', 'category', 'unit',
        'purchase_price_minor', 'sale_price_minor', 'current_stock', 'min_stock', 'source',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'deleted_at' => 'datetime',
            'purchase_price_minor' => 'integer',
            'sale_price_minor' => 'integer',
            'current_stock' => 'integer',
            'min_stock' => 'integer',
        ];
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }
}
