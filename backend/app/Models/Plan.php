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
        'name', 'slug', 'description', 'price_minor', 'price_yearly_minor', 'duration_days', 'duration_days_yearly',
        'max_users', 'is_active', 'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'price_minor' => 'integer',
            'price_yearly_minor' => 'integer',
            'duration_days' => 'integer',
            'duration_days_yearly' => 'integer',
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

    /**
     * Plan açıklaması "{hedef kitle}. {özellik, özellik, ...}." biçiminde
     * saklanır — hem web abonelik sayfası hem mobil API aynı ayrıştırmayı
     * kullanır (tek kaynak burası).
     *
     * @return array{audience: string, features: array<int, string>}
     */
    public function splitDescription(): array
    {
        $sentences = array_values(array_filter(array_map('trim', explode('.', (string) $this->description))));

        $audience = $sentences[0] ?? '';
        $features = isset($sentences[1])
            ? array_values(array_filter(array_map('trim', explode(',', $sentences[1]))))
            : [];

        return ['audience' => $audience, 'features' => $features];
    }

    public function yearlySavingsPercent(): int
    {
        $monthlyTotal = $this->price_minor * 12;

        if ($monthlyTotal <= 0 || (int) $this->price_yearly_minor <= 0) {
            return 0;
        }

        return (int) round((1 - ($this->price_yearly_minor / $monthlyTotal)) * 100);
    }

    /**
     * Bir satın almanın kaç gün süre kazandırdığı.
     *
     * Panelde ne yazıyorsa o uygulanır. Alan boşsa makul varsayılana
     * düşülür — sürenin hiç tanımsız kalması, aboneliğin sessizce
     * uzamaması demek olurdu.
     */
    public function durationDaysFor(string $duration): int
    {
        if ($duration === 'YEARLY') {
            return (int) ($this->duration_days_yearly ?: 365);
        }

        return (int) ($this->duration_days ?: 30);
    }
}
