<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Job extends Model
{
    use BelongsToCompany, HasUuids, SoftDeletes;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'code', 'customer_id', 'job_type_id', 'title', 'description',
        'address', 'appointment_date', 'start_time', 'end_time', 'priority', 'status',
        'technician_user_id', 'estimated_price_minor', 'actual_price_minor', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'appointment_date' => 'datetime',
            'created_at' => 'datetime',
            'deleted_at' => 'datetime',
            'estimated_price_minor' => 'integer',
            'actual_price_minor' => 'integer',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function jobNotes(): HasMany
    {
        return $this->hasMany(JobNote::class, 'job_id');
    }

    public function photos(): HasMany
    {
        return $this->hasMany(JobPhoto::class, 'job_id');
    }

    public function signatures(): HasMany
    {
        return $this->hasMany(JobSignature::class, 'job_id');
    }
}
