<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class GoogleRegisterRequest extends FormRequest
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
            'id_token' => ['required', 'string'],
            'company_name' => ['required', 'string', 'max:255'],
            'business_types' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
        ];
    }
}
