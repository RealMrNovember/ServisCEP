<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Warranty extends Model
{
    use BelongsToCompany, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'customer_id', 'product_id', 'job_id',
        'item_description', 'serial_number', 'install_date',
        'warranty_months', 'warranty_expires_at', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'install_date' => 'date',
            'warranty_expires_at' => 'date',
            'warranty_months' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function isExpired(): bool
    {
        return $this->warranty_expires_at->isPast();
    }
}
