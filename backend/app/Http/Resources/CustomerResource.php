<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Customer
 */
class CustomerResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'contact_name' => $this->contact_name,
            'company_name' => $this->company_name,
            'display_name' => $this->display_name,
            'type' => $this->type,
            'phone' => $this->phone,
            'email' => $this->email,
            'iban' => $this->iban,
            'address' => $this->address,
            'il' => $this->il,
            'ilce' => $this->ilce,
            'tax_info' => $this->tax_info,
            'notes' => $this->notes,
            'tags' => $this->tags,
            'created_at' => $this->created_at,
        ];
    }
}
