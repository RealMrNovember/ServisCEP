<?php

declare(strict_types=1);

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCompanyRequest extends FormRequest
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:255'],
            // Virgülle ayrılmış işletme türleri (Elektrik, Kamera, ...) —
            // mobil ve web aynı biçimi kullanır.
            'business_types' => ['sometimes', 'nullable', 'string', 'max:255'],
            'iban' => ['sometimes', 'nullable', 'string', 'max:34'],
            // Belge antedinde görünen iletişim/vergi bilgileri.
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'tax_info' => ['sometimes', 'nullable', 'string', 'max:255'],
        ];
    }
}
