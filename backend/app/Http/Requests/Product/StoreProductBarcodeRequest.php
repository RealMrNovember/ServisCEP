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
        $companyId = $this->user()->company_id;

        return [
            'id' => ['sometimes', 'uuid'],
            // Ürün AYNI ŞİRKETE ait olmalı.
            //
            // Kapsam CLOSURE ile veriliyor — depodaki diğer isteklerle
            // aynı biçim (bkz. StoreJobRequest). Doğrudan
            // `->where($sutun, $deger)` biçimi kural dizesine gömülüyor
            // ve UUID gibi değerlerde beklendiği gibi çalışmıyor.
            'product_id' => [
                'required',
                'uuid',
                Rule::exists((new Product)->getTable(), 'id')
                    ->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'barcode' => [
                'required',
                'string',
                'max:64',
                // Aynı kod iki ayrı ürüne bağlanamaz: tarama hangisini
                // açacağını bilemezdi.
                //
                // ignore(): aynı istemci UUID'siyle gelen YENİDEN GÖNDERİM
                // kendi yazdığı satıra takılmamalı. Mobil kuyruk ağ
                // kesintisinde aynı isteği tekrar gönderiyor; bu kural
                // olmadan ikinci deneme 422 alıyor ve satır kalıcı hataya
                // düşüyordu — yani çevrimdışı bağlanan barkod sunucuya
                // hiç ulaşmıyordu.
                Rule::unique((new ProductBarcode)->getTable(), 'barcode')
                    ->ignore($this->input('id'), 'id')
                    ->where(fn ($query) => $query->where('company_id', $companyId)),
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
