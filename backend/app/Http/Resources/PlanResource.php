<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Plan
 */
class PlanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $description = $this->splitDescription();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'audience' => $description['audience'],
            'features' => $description['features'],
            'price_monthly_minor' => $this->price_minor,
            'price_yearly_minor' => $this->price_yearly_minor,
            'yearly_savings_percent' => $this->yearlySavingsPercent(),
            'max_users' => $this->max_users,
            'sort_order' => $this->sort_order,
        ];
    }
}
