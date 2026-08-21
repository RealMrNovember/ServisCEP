<?php

declare(strict_types=1);

namespace App\Http\Requests\ServiceRequest;

use Illuminate\Foundation\Http\FormRequest;

class UpdateServiceRequestRequest extends FormRequest
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
            'base_version' => ['required', 'integer', 'min:1'],
            'description' => ['sometimes', 'string'],
            'priority' => ['sometimes', 'string', 'in:YUKSEK,NORMAL,DUSUK'],
            'address' => ['sometimes', 'nullable', 'string'],
            // ISE_DONUSTU yalnızca /convert endpoint'i üzerinden, sunucu
            // tarafında set edilir — bkz. docs/02 § Talep → İş Dönüşümü.
            'status' => ['sometimes', 'string', 'in:BEKLIYOR,ISLEME_ALINDI,REDDEDILDI'],
        ];
    }
}
