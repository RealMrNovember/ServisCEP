<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Proforma extends Model
{
    use BelongsToCompany, HasUuids;

    public $timestamps = false;

    protected $fillable = ['company_id', 'code', 'customer_id', 'valid_until', 'notes', 'total_minor'];

    protected function casts(): array
    {
        return [
            'valid_until' => 'datetime',
            'created_at' => 'datetime',
            'total_minor' => 'integer',
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
