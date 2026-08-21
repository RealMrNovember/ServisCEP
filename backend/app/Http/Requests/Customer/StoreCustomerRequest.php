<?php

declare(strict_types=1);

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StoreCustomerRequest extends FormRequest
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
            'code' => ['required', 'string', 'max:50'],
            'contact_name' => ['nullable', 'string', 'max:255'],
            'company_name' => ['nullable', 'string', 'max:255'],
            'type' => ['required', 'string', 'in:BIREYSEL,FIRMA,APARTMAN,SITE,KAMU,DIGER'],
            'iban' => ['nullable', 'string', 'max:34'],
            'phone' => ['nullable', 'string', 'max:30'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string'],
            'il' => ['nullable', 'string', 'max:100'],
            'ilce' => ['nullable', 'string', 'max:100'],
            'tax_info' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string'],
            'tags' => ['nullable', 'string', 'max:255'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (blank($this->input('contact_name')) && blank($this->input('company_name'))) {
                $validator->errors()->add(
                    'contact_name',
                    'Yetkili adı veya firma adından en az biri girilmelidir.'
                );
            }
        });
    }
}
