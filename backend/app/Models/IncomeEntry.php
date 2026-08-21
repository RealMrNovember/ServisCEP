<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IncomeEntry extends Model
{
    use BelongsToCompany, HasFactory, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'date', 'description', 'customer_id', 'job_id',
        'category', 'amount_minor', 'method', 'note',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'datetime',
            'amount_minor' => 'integer',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }
}
