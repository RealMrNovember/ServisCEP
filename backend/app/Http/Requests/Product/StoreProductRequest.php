<?php

declare(strict_types=1);

namespace App\Http\Requests\Product;

use Illuminate\Foundation\Http\FormRequest;

class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Mobil, çevrimdışı oluşturduğu kaydın UUID'sini korur.
            'id' => ['sometimes', 'uuid'],
            'barcode' => ['nullable', 'string', 'max:64'],
            'sku' => ['nullable', 'string', 'max:64'],
            'name' => ['required', 'string', 'max:255'],
            'brand' => ['nullable', 'string', 'max:255'],
            'model' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:32'],
            'purchase_price_minor' => ['nullable', 'integer', 'min:0'],
            'sale_price_minor' => ['nullable', 'integer', 'min:0'],
            // Açılış stoğu. Sonraki değişiklikler stok HAREKETİ olarak
            // gelir; current_stock update'te kabul edilmez (bkz.
            // UpdateProductRequest).
            'current_stock' => ['nullable', 'integer'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'source' => ['nullable', 'string', 'in:MANUAL,GLOBAL_LOOKUP'],
        ];
    }
}
