<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class JobType extends Model
{
    use BelongsToCompany, HasUuids;

    public $timestamps = false;

    protected $fillable = ['company_id', 'category', 'name', 'is_custom'];

    protected function casts(): array
    {
        return ['is_custom' => 'boolean'];
    }
}
