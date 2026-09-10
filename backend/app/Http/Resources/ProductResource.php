<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Product
 */
class ProductResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'barcode' => $this->barcode,
            'sku' => $this->sku,
            'name' => $this->name,
            'brand' => $this->brand,
            'model' => $this->model,
            'category' => $this->category,
            'unit' => $this->unit,
            'purchase_price_minor' => (int) $this->purchase_price_minor,
            'sale_price_minor' => (int) $this->sale_price_minor,
            // Hareket defterinden türetilir (bkz. StockMovementController).
            'current_stock' => (int) $this->current_stock,
            'min_stock' => (int) $this->min_stock,
            'source' => $this->source,
            'created_at' => $this->created_at?->toISOString(),
            // Mezar taşı: silinen ürün de listede döner, yoksa cihaz
            // silindiğini asla öğrenemez.
            'deleted_at' => $this->deleted_at?->toISOString(),
        ];
    }
}
