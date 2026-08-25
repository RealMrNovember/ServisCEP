<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Proforma
 */
class ProformaResource extends JsonResource
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
            'code' => $this->code,
            'customer_id' => $this->customer_id,
            'valid_until' => $this->valid_until,
            'notes' => $this->notes,
            'total_minor' => $this->total_minor,
            'currency' => $this->currency,
            'vat_mode' => $this->vat_mode,
            'vat_rate' => $this->vat_rate,
            'items' => ProformaItemResource::collection($this->whenLoaded('items')),
            'version' => $this->version,
            'created_at' => $this->created_at,
        ];
    }
}
