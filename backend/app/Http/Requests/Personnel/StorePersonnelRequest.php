<?php

declare(strict_types=1);

namespace App\Http\Requests\Personnel;

use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StorePersonnelRequest extends FormRequest
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            // Benzersizlik burada DEĞİL, withValidator() içinde kontrol
            // edilir: `unique` kuralı genel bir mesaj üretip devreye ilk
            // giriyor ve kullanıcıya ne yapacağını söyleyen bağlamsal
            // mesajın önüne geçiyordu. Son savunma DB'deki unique index.
            'email' => ['required', 'email', 'max:255'],
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
            'password.min' => 'Parola en az 8 karakter olmalı.',
            'role.in' => 'Geçersiz rol.',
        ];
    }

    /**
     * E-posta global olarak benzersizdir. Çakışma iki farklı durumdan
     * gelebilir ve kullanıcıya ne yapacağını söylemek için ayırt edilmeli:
     *
     *  1. Kişi ZATEN bu ekipte — sahip yanlışlıkla tekrar ekliyor.
     *  2. Kişi kendi başına kayıt olmuş (kendi şirketini açmış) ya da
     *     başka bir firmanın ekibinde. Bu durumda hesabın taşınması
     *     gerekir; bunu yalnızca destek (süper-admin) yapabilir.
     *     Bkz. UserTransferService.
     *
     * Genel "bu e-posta kullanılıyor" mesajı, sahibi çıkmaz sokakta
     * bırakıyordu.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            // Biçim hatası varsa (geçersiz e-posta) benzersizliğe bakmaya
            // gerek yok — kullanıcıya tek ve net bir hata gösterilir.
            if ($validator->errors()->has('email')) {
                return;
            }

            $existing = User::where('email', $this->input('email'))->first();
            if ($existing === null) {
                return;
            }

            $validator->errors()->add(
                'email',
                $existing->company_id === $this->user()->company_id
                    ? 'Bu kişi zaten ekibinde.'
                    : 'Bu e-posta başka bir hesapta kayıtlı. Kişi daha önce kendi başına üye olmuş olabilir; hesabının ekibine taşınması için destekle iletişime geç.',
            );
        });
    }
}
