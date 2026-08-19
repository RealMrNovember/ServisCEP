<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockMovement extends Model
{
    use BelongsToCompany, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'product_id', 'type', 'vendor_name', 'quantity',
        'reference_type', 'reference_id', 'note',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'quantity' => 'integer',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
