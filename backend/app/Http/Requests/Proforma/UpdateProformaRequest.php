<?php

declare(strict_types=1);

namespace App\Http\Requests\Proforma;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProformaRequest extends FormRequest
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
            'currency' => ['sometimes', 'string', 'in:TRY,USD,EUR'],
            'vat_mode' => ['sometimes', 'string', 'in:EXCLUDED,INCLUDED'],
            'vat_rate' => ['sometimes', 'integer', 'min:0', 'max:100'],
            'base_version' => ['required', 'integer', 'min:1'],
            'valid_until' => ['sometimes', 'nullable', 'date'],
            'notes' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
