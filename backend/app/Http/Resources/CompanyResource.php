<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Company
 */
class CompanyResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'intro_text' => $this->intro_text,
            'payment_terms' => $this->payment_terms,
            'delivery_time' => $this->delivery_time,
            'warranty_terms' => $this->warranty_terms,
            'id' => $this->id,
            'name' => $this->name,
            'business_types' => $this->business_types,
            'iban' => $this->iban,
            'address' => $this->address,
            'phone' => $this->phone,
            'email' => $this->email,
            'tax_info' => $this->tax_info,
            'has_logo' => (bool) $this->logo_path,
            'is_active' => $this->is_active,
            'subscription_expires_at' => $this->subscription_expires_at,
        ];
    }
}
