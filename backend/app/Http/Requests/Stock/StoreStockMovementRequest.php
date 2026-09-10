<?php

declare(strict_types=1);

namespace App\Http\Requests\Stock;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreStockMovementRequest extends FormRequest
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
            'id' => ['sometimes', 'uuid'],
            // Ürün AYNI ŞİRKETE ait olmalı: aksi hâlde başka bir şirketin
            // ürününe hareket yazılabilirdi.
            'product_id' => [
                'required',
                'uuid',
                Rule::exists((new Product)->getTable(), 'id')
                    ->where(fn ($query) => $query->where(
                        'company_id',
                        $this->user()->company_id,
                    )),
            ],
            'type' => ['required', 'string', 'in:IN,OUT'],
            'quantity' => ['required', 'integer', 'min:1'],
            'reference_type' => ['required', 'string', 'max:50'],
            'reference_id' => ['nullable', 'uuid'],
            'note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
