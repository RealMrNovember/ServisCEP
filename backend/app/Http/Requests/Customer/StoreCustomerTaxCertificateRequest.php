<?php

declare(strict_types=1);

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

class StoreCustomerTaxCertificateRequest extends FormRequest
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        // Web panelindeki FileUpload ile aynı kabul kuralları
        // (bkz. Filament\App\Resources\Customers\Schemas\CustomerForm).
        return [
            'file' => ['required', 'file', 'mimes:pdf,jpeg,jpg,png', 'max:10240'],
        ];
    }
}
