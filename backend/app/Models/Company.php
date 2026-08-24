<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Company extends Model
{
    use HasFactory, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'name', 'business_types', 'iban', 'logo_path',
        'address', 'phone', 'email', 'tax_info',
        'plan_id', 'subscription_expires_at', 'is_active', 'admin_note',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    /**
     * Yeni kayıt olan her şirket 14 günlük deneme süresiyle başlar —
     * süresiz erişim yalnızca admin onaylı bir ödeme talebiyle kazanılır
     * (bkz. PaymentRequest::approve()).
     */
    public static function startTrial(string $name): self
    {
        $trialPlan = Plan::where('slug', 'deneme')->first();

        return static::create([
            'name' => $name,
            'plan_id' => $trialPlan?->id,
            'subscription_expires_at' => now()->addDays($trialPlan?->duration_days ?? 14),
            'is_active' => true,
        ]);
    }

    /**
     * Süresi dolmamış VE manuel olarak askıya alınmamış olmalı — admin
     * panelden erişim kontrolü bu tek metoda dayanır.
     */
    public function hasActiveSubscription(): bool
    {
        if (! $this->is_active) {
            return false;
        }

        if ($this->subscription_expires_at === null) {
            return true;
        }

        return $this->subscription_expires_at->isFuture();
    }
}
