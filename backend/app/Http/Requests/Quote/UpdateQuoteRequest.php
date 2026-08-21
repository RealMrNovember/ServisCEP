<?php

declare(strict_types=1);

namespace App\Http\Requests\Quote;

use Illuminate\Foundation\Http\FormRequest;

class UpdateQuoteRequest extends FormRequest
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
            'status' => ['sometimes', 'string', 'in:TASLAK,GONDERILDI,BEKLEMEDE,KABUL_EDILDI,REDDEDILDI,SURESI_DOLDU'],
            'notes' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
