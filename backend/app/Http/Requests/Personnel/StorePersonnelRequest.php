<?php

declare(strict_types=1);

namespace App\Http\Requests\Personnel;

use App\Support\RolePermissions;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePersonnelRequest extends FormRequest
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'phone' => ['nullable', 'string', 'max:30'],
            // OWNER buradan atanamaz: ikinci bir sahip oluşturmak sahiplik
            // devri anlamına gelir ve ayrı, bilinçli bir akış olmalıdır.
            'role' => ['required', 'string', Rule::in(RolePermissions::ASSIGNABLE)],
            'password' => ['required', 'string', 'min:8'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'email.unique' => 'Bu e-posta adresi zaten kullanılıyor.',
            'password.min' => 'Parola en az 8 karakter olmalı.',
            'role.in' => 'Geçersiz rol.',
        ];
    }
}
