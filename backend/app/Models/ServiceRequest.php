<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use App\Models\Concerns\HasVersion;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServiceRequest extends Model
{
    use BelongsToCompany, HasFactory, HasUuids, HasVersion;

    public $timestamps = false;

    protected $table = 'service_requests';

    protected $fillable = [
        'id', 'company_id', 'code', 'customer_id', 'description', 'priority',
        'address', 'status', 'converted_job_id',
    ];

    protected function casts(): array
    {
        return ['created_at' => 'datetime', 'version' => 'integer'];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
