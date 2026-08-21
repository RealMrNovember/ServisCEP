<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerLedgerEntry extends Model
{
    use BelongsToCompany, HasFactory, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'customer_id', 'entry_date', 'type',
        'amount_minor', 'reference_type', 'reference_id', 'description',
    ];

    protected function casts(): array
    {
        return [
            'entry_date' => 'datetime',
            'created_at' => 'datetime',
            'amount_minor' => 'integer',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
