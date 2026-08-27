<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class ResetPasswordRequest extends FormRequest
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
            'email' => ['required', 'email'],
            // Altı hane, yalnızca rakam — e-postadaki kodun birebir aynısı.
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
            // Kayıttaki kuralla AYNI olmak zorunda: sıfırlamada daha gevşek
            // bir kural, parola politikasını sıfırlama üzerinden aşmanın
            // yolu olurdu.
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'code.regex' => 'Kod 6 haneli olmalı.',
        ];
    }
}
