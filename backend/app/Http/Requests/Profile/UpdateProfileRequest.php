<?php

declare(strict_types=1);

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        // E-posta ve rol BİLEREK yok: e-posta kimliktir (değişimi ayrı bir
        // doğrulama akışı ister, bkz. web panelindeki emailChangeVerification),
        // rol ise kullanıcının kendi kendine yükseltemeyeceği bir alandır.
        return [
            'full_name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
        ];
    }
}
