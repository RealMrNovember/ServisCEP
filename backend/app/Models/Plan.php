<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Plan extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'name', 'slug', 'description', 'price_minor', 'price_yearly_minor', 'duration_days',
        'max_users', 'is_active', 'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'price_minor' => 'integer',
            'price_yearly_minor' => 'integer',
            'duration_days' => 'integer',
            'max_users' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function companies(): HasMany
    {
        return $this->hasMany(Company::class);
    }
}
