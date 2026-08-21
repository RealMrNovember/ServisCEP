<?php

declare(strict_types=1);

namespace App\Http\Requests\Finance;

use Illuminate\Foundation\Http\FormRequest;

class StoreExpenseEntryRequest extends FormRequest
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
            'date' => ['nullable', 'date'],
            'description' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'in:Malzeme,Yakıt,Araç,Kargo,Telefon,İnternet,Ekipman,Ofis,Personel,Diğer'],
            'amount_minor' => ['required', 'integer', 'min:1'],
            'vendor_name' => ['nullable', 'string', 'max:255'],
            'method' => ['required', 'string', 'max:50'],
            'note' => ['nullable', 'string'],
        ];
    }
}
