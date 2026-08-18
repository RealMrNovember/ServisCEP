<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ExpenseEntry extends Model
{
    use BelongsToCompany, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'date', 'description', 'category', 'amount_minor',
        'vendor_name', 'receipt_photo_path', 'method', 'note',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'datetime',
            'amount_minor' => 'integer',
        ];
    }
}
