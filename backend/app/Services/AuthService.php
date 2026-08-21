<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Company;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    /**
     * Yeni şirketi ve şirketin ilk (OWNER) kullanıcısını birlikte oluşturur —
     * bkz. ROADMAP.md M2, mobil onboarding akışıyla (şirket bilgileri +
     * işletme türü + sahip bilgileri + parola) tutarlı. Şirket, web
     * tarafındaki kayıt akışıyla (RegisterCompany::handleRegistration)
     * aynı kurala uyarak 14 günlük deneme süresiyle başlar — bkz.
     * Company::startTrial().
     *
     * @param  array{company_name: string, business_types: ?string, full_name: string, email: string, phone: ?string, password: string}  $data
     * @return array{user: User, token: string}
     */
    public function register(array $data): array
    {
        return DB::transaction(function () use ($data) {
            $company = Company::startTrial($data['company_name']);

            if (filled($data['business_types'] ?? null)) {
                $company->update(['business_types' => $data['business_types']]);
            }

            $user = User::create([
                'company_id' => $company->id,
                'full_name' => $data['full_name'],
                'email' => $data['email'],
                'phone' => $data['phone'] ?? null,
                // 'password' cast'i 'hashed' olduğu için burada tekrar
                // Hash::make() çağırmak parolayı ÇİFT hashler — cast'e
                // ham parolayı bırakmak gerekir (bkz. RegisterCompany ile
                // aynı kural).
                'password' => $data['password'],
                'role' => 'OWNER',
            ]);

            $token = $user->createToken('mobile')->plainTextToken;

            return ['user' => $user->load('company'), 'token' => $token];
        });
    }

    /**
     * @param  array{email: string, password: string}  $credentials
     * @return array{user: User, token: string}
     *
     * @throws ValidationException
     */
    public function login(array $credentials): array
    {
        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Geçersiz e-posta veya parola.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return ['user' => $user->load('company'), 'token' => $token];
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }
}
