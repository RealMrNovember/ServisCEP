<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\ProductBarcode;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ProductBarcode
 */
class ProductBarcodeResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'barcode' => $this->barcode,
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
