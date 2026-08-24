<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Quote
 */
class QuoteResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'customer_id' => $this->customer_id,
            'status' => $this->status,
            'notes' => $this->notes,
            'total_minor' => $this->total_minor,
            'currency' => $this->currency,
            'vat_mode' => $this->vat_mode,
            'vat_rate' => $this->vat_rate,
            'valid_until' => $this->valid_until,
            'items' => QuoteItemResource::collection($this->whenLoaded('items')),
            'version' => $this->version,
            'created_at' => $this->created_at,
        ];
    }
}
