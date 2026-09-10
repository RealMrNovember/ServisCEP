<?php

declare(strict_types=1);

namespace App\Http\Requests\Product;

use App\Models\Product;
use App\Models\ProductBarcode;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductBarcodeRequest extends FormRequest
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
        $companyId = $this->user()?->company_id;

        return [
            'id' => ['sometimes', 'uuid'],
            // Ürün AYNI ŞİRKETE ait olmalı.
            'product_id' => [
                'required',
                'uuid',
                Rule::exists((new Product)->getTable(), 'id')->where('company_id', $companyId),
            ],
            'barcode' => [
                'required',
                'string',
                'max:64',
                // Aynı kod iki ayrı ürüne bağlanamaz: tarama hangisini
                // açacağını bilemezdi.
                Rule::unique((new ProductBarcode)->getTable(), 'barcode')
                    ->where('company_id', $companyId),
            ],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'barcode.unique' => 'Bu barkod zaten başka bir ürüne bağlı.',
        ];
    }
}
