<?php

declare(strict_types=1);

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCustomerRequest extends FormRequest
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
            // İstemcinin son gördüğü sürüm — optimistic concurrency için
            // zorunlu. Bkz. ROADMAP.md § B10, DetectsSyncConflicts.
            'base_version' => ['required', 'integer', 'min:1'],

            // İstemcinin GERÇEKTEN değiştirdiği alanlar. Yük kaydın
            // tamamını taşıdığı için bu bilgi yükten çıkarılamıyor; onsuz
            // her sürüm uyuşmazlığı elle çözülmesi gereken bir çakışma
            // sayılırdı (bkz. DetectsSyncConflicts).
            //
            // `sometimes`: eski uygulama sürümleri bunu göndermiyor ve
            // göndermedikleri sürece eski davranışı görüyorlar.
            'changed_fields' => ['sometimes', 'array'],
            'changed_fields.*' => ['string', 'max:64'],
            'code' => ['sometimes', 'string', 'max:50'],
            'contact_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'company_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'type' => ['sometimes', 'string', 'in:BIREYSEL,FIRMA,APARTMAN,SITE,KAMU,DIGER'],
            'iban' => ['sometimes', 'nullable', 'string', 'max:34'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'address' => ['sometimes', 'nullable', 'string'],
            'il' => ['sometimes', 'nullable', 'string', 'max:100'],
            'ilce' => ['sometimes', 'nullable', 'string', 'max:100'],
            'tax_info' => ['sometimes', 'nullable', 'string', 'max:100'],
            'notes' => ['sometimes', 'nullable', 'string'],
            'tags' => ['sometimes', 'nullable', 'string', 'max:255'],
        ];
    }
}
