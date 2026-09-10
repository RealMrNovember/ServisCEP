<?php

declare(strict_types=1);

namespace App\Http\Requests\Product;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProductRequest extends FormRequest
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
            'barcode' => ['nullable', 'string', 'max:64'],
            'sku' => ['nullable', 'string', 'max:64'],
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'brand' => ['nullable', 'string', 'max:255'],
            'model' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:32'],
            'purchase_price_minor' => ['nullable', 'integer', 'min:0'],
            'sale_price_minor' => ['nullable', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
        ];
        // current_stock BİLEREK YOK.
        //
        // Stok adedi, hareket defterinden (stock_movements) türetilir —
        // cari hesapla aynı felsefe. İki cihaz çevrimdışı stok
        // düşerse, satırı doğrudan yazmak son yazanın diğerini ezmesi
        // demek olurdu; hareket olarak gelince ikisi de sayılır.
    }
}
