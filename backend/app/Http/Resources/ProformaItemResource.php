<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\ProformaItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ProformaItem
 */
class ProformaItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'description' => $this->description,
            'quantity' => $this->quantity,
            'unit' => $this->unit,
            'unit_price_minor' => $this->unit_price_minor,
            'tax_rate' => $this->tax_rate,
            'discount_minor' => $this->discount_minor,
            // null: tutar olarak girildi. Dolu: yuzde olarak girildi
            // ve discount_minor ondan turetildi.
            'discount_rate' => $this->discount_rate,
        ];
    }
}
