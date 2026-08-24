<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use App\Models\Concerns\HasVersion;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToCompany, HasFactory, HasUuids, HasVersion, SoftDeletes;

    public $timestamps = false;

    protected $fillable = [
        'id', 'company_id', 'code', 'contact_name', 'company_name', 'iban', 'type', 'phone', 'email',
        'address', 'il', 'ilce', 'tax_info', 'tax_certificate_path', 'logo_path', 'notes', 'tags',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'deleted_at' => 'datetime',
            'version' => 'integer',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Firma adı varsa firma adı, yoksa yetkili adı soyadı gösterilir —
     * bkz. mobile/lib/core/utils/customer_display.dart ile tutarlı olmalı.
     */
    protected function displayName(): Attribute
    {
        return Attribute::get(
            fn () => filled($this->company_name) ? $this->company_name : ($this->contact_name ?? '')
        );
    }

    public function jobs(): HasMany
    {
        return $this->hasMany(Job::class);
    }

    public function ledgerEntries(): HasMany
    {
        return $this->hasMany(CustomerLedgerEntry::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function quotes(): HasMany
    {
        return $this->hasMany(Quote::class);
    }

    public function proformas(): HasMany
    {
        return $this->hasMany(Proforma::class);
    }
}
