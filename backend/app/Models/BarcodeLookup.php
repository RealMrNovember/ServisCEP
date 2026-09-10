<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Küresel barkod sorgusunun önbellek satırı — bkz. migration.
 *
 * BelongsToCompany YOK ve bu bilinçli: barkod evrensel bir kimlik,
 * şirkete ait bir veri değil.
 */
class BarcodeLookup extends Model
{
    public $timestamps = false;

    public $incrementing = false;

    protected $primaryKey = 'barcode';

    protected $keyType = 'string';

    protected $fillable = [
        'barcode', 'found', 'name', 'brand', 'category', 'source', 'checked_at',
    ];

    protected function casts(): array
    {
        return [
            'found' => 'boolean',
            'checked_at' => 'datetime',
        ];
    }
}
