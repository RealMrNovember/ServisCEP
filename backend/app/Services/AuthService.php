<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Company;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialiteUser;

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

    /**
     * Google ID token'ını doğrular — aynı OAuth client (GOOGLE_CLIENT_ID),
     * hem web'in yönlendirme akışında hem mobilin native SDK'sında
     * kullanılır (bkz. mobile/lib/features/auth/data/google_auth_service.dart
     * serverClientId).
     *
     * Hata YUTULMAZ: asıl sebep loglanır. Kullanıcıya genel bir mesaj
     * döner (Google yanıtındaki ayrıntılar son kullanıcıyı ilgilendirmez)
     * ama destek tarafında "neden başarısız" sorusunun cevabı loglarda
     * durur. Bu, bir cihazda saatlerce teşhis edilemeyen bir arızadan
     * sonra eklendi.
     *
     * Token'ın KENDİSİ hiçbir zaman loglanmaz — o bir kimlik bilgisidir.
     *
     * @throws ValidationException Token geçersiz/süresi dolmuşsa.
     */
    private function verifyGoogleToken(string $idToken): SocialiteUser
    {
        try {
            return Socialite::driver('google')->userFromToken($idToken);
        } catch (\Throwable $e) {
            $context = [
                'exception' => $e::class,
                'reason' => $e->getMessage(),
                'token_length' => strlen($idToken),
            ];

            // Google HTTP ile reddettiyse durum kodu ve gövdesi asıl ipucu.
            if ($e instanceof \GuzzleHttp\Exception\RequestException && $e->hasResponse()) {
                $response = $e->getResponse();
                $context['google_status'] = $response->getStatusCode();
                $context['google_body'] = substr((string) $response->getBody(), 0, 500);
            }

            // `error` seviyesi bilinçli: production'da LOG_LEVEL=error
            // olduğu için `warning` ile yazılan hiçbir şey dosyaya
            // düşmüyor. Kimlik doğrulamanın sessizce başarısız olması
            // zaten gerçek bir hata — kullanıcı uygulamaya giremiyor.
            Log::error('Google id_token doğrulanamadı', $context);

            throw ValidationException::withMessages([
                'id_token' => ['Google kimlik doğrulaması başarısız.'],
            ]);
        }
    }

    /**
     * Web'deki GoogleAuthController::callback() ile AYNI eşleştirme
     * kuralı — google_id veya email ile bulunur, bulunursa google_id
     * eksikse geri doldurulur. İki katman (web session, mobil Sanctum)
     * bu tek kuralı paylaşır ki bir e-postanın davranışı platforma göre
     * farklılaşmasın.
     */
    public function findOrCreateGoogleUser(string $googleId, string $email, ?string $name): User
    {
        $user = User::where('google_id', $googleId)->orWhere('email', $email)->first();

        if ($user) {
            if (! $user->google_id) {
                $user->forceFill(['google_id' => $googleId])->save();
            }

            return $user;
        }

        return DB::transaction(function () use ($googleId, $email, $name) {
            $company = Company::startTrial($name ?: $email);

            return User::create([
                'company_id' => $company->id,
                'full_name' => $name ?: $email,
                'email' => $email,
                'password' => Str::password(32),
                'google_id' => $googleId,
                'role' => 'OWNER',
            ]);
        });
    }

    /**
     * Mobil "Google ile devam et" → hesap ZATEN var olmalı. Yoksa
     * kayıt ol akışına (registerWithGoogle) yönlendirilmesi gerektiğini
     * belirten net bir hata döner — sessizce yeni hesap oluşturmaz,
     * aksi halde kullanıcı hangi şirkete bağlandığını fark etmeden
     * farklı bir hesaba düşebilirdi.
     *
     * @return array{user: User, token: string}
     *
     * @throws ValidationException
     */
    public function loginWithGoogle(string $idToken): array
    {
        $googleUser = $this->verifyGoogleToken($idToken);

        $user = User::where('google_id', $googleUser->getId())
            ->orWhere('email', $googleUser->getEmail())
            ->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'id_token' => ['Bu Google hesabıyla eşleşen bir hesap yok. Önce kayıt olmalısın.'],
            ]);
        }

        if (! $user->google_id) {
            $user->forceFill(['google_id' => $googleUser->getId()])->save();
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return ['user' => $user->load('company'), 'token' => $token];
    }

    /**
     * Mobil onboarding'in Google akışı — kullanıcı işletme türü/şirket
     * adını girip gönderdiğinde çağrılır. Hesap zaten varsa (ör. iki kez
     * "kayıt ol" denenmesi) sessizce üzerine yazmak yerine net bir hata
     * döner.
     *
     * @param  array{id_token: string, company_name: string, business_types: ?string, phone: ?string}  $data
     * @return array{user: User, token: string}
     *
     * @throws ValidationException
     */
    public function registerWithGoogle(array $data): array
    {
        $googleUser = $this->verifyGoogleToken($data['id_token']);

        $existing = User::where('google_id', $googleUser->getId())
            ->orWhere('email', $googleUser->getEmail())
            ->first();

        if ($existing) {
            throw ValidationException::withMessages([
                'id_token' => ['Bu Google hesabıyla zaten bir hesap var. Giriş yapmayı dene.'],
            ]);
        }

        $user = DB::transaction(function () use ($googleUser, $data) {
            $company = Company::startTrial($data['company_name']);

            if (filled($data['business_types'] ?? null)) {
                $company->update(['business_types' => $data['business_types']]);
            }

            return User::create([
                'company_id' => $company->id,
                'full_name' => $googleUser->getName() ?: $googleUser->getEmail(),
                'email' => $googleUser->getEmail(),
                'phone' => $data['phone'] ?? null,
                'password' => Str::password(32),
                'google_id' => $googleUser->getId(),
                'role' => 'OWNER',
            ]);
        });

        $token = $user->createToken('mobile')->plainTextToken;

        return ['user' => $user->load('company'), 'token' => $token];
    }
}
