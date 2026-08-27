<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\AppLog;
use App\Models\Company;
use App\Models\User;
use App\Notifications\PasswordResetCode;
use Carbon\Carbon;
use GuzzleHttp\Exception\RequestException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialiteUser;

class AuthService
{
    /** Parola sıfırlama kodunun geçerlilik süresi (dakika). */
    private const PAROLA_KODU_DAKIKA = 15;

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

            AppLog::event('Yeni kayıt', ['sirket' => $company->name], $user);

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
            // Başarısız denemeler `warning`: tek tük olması normal, ama üst
            // üste gelmesi ya kullanıcının sıkıştığını ya da deneme-yanılma
            // saldırısını gösterir. İkisi de görülmeli.
            AppLog::event(
                'Giriş başarısız',
                ['email' => $credentials['email'], 'sebep' => $user ? 'parola' : 'kullanıcı yok'],
                $user,
                'warning',
            );

            throw ValidationException::withMessages([
                'email' => ['Geçersiz e-posta veya parola.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        AppLog::event('Giriş yapıldı', ['yontem' => 'parola'], $user);

        return ['user' => $user->load('company'), 'token' => $token];
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();

        AppLog::event('Çıkış yapıldı', [], $user);
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
            if ($e instanceof RequestException && $e->hasResponse()) {
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

        AppLog::event('Giriş yapıldı', ['yontem' => 'google'], $user);

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

        AppLog::event('Yeni kayıt', ['yontem' => 'google'], $user);

        return ['user' => $user->load('company'), 'token' => $token];
    }

    /**
     * Parola sıfırlama kodunu üretir ve e-postayla gönderir.
     *
     * Hesap YOKSA da sessizce başarılı dönülür (çağıran taraf zaten aynı
     * mesajı gösterir): aksi halde bu uç, bir e-postanın sistemde kayıtlı
     * olup olmadığını sorgulamanın ücretsiz yoluna dönüşür.
     *
     * Kod veritabanında AÇIK DEĞİL hash'li tutuluyor. Sıfırlama kodu, o
     * dakikalar boyunca parolaya eşdeğer bir sırdır; veritabanı kopyası
     * sızarsa açık kod, doğrudan hesap devri demektir.
     */
    public function sendPasswordResetCode(string $email): void
    {
        $user = User::where('email', $email)->first();

        if (! $user) {
            AppLog::event(
                'Parola sıfırlama istendi',
                ['email' => $email, 'sonuc' => 'kullanıcı yok'],
                null,
                'warning',
            );

            return;
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            ['token' => Hash::make($code), 'created_at' => now()],
        );

        $user->notify(new PasswordResetCode($code, self::PAROLA_KODU_DAKIKA));

        AppLog::event('Parola sıfırlama kodu gönderildi', [], $user);
    }

    /**
     * Kodu doğrular ve parolayı değiştirir.
     *
     * @param  array{email: string, code: string, password: string}  $data
     */
    public function resetPassword(array $data): void
    {
        $satir = DB::table('password_reset_tokens')
            ->where('email', $data['email'])
            ->first();

        // Süre kontrolü FARK ALARAK yapılmıyor.
        //
        // Carbon 3'te diffInMinutes işaretli dönüyor: geçmiş bir tarih
        // için negatif. `now()->diffInMinutes($gecmis) >= 15` bu yüzden
        // hiçbir zaman doğru olmuyor ve süresi dolmuş kod kabul ediliyordu
        // (testle yakalandı). Son geçerlilik anını hesaplayıp geçip
        // geçmediğine bakmak yön hatasına kapalı.
        $suresiDoldu = $satir !== null
            && Carbon::parse($satir->created_at)
                ->addMinutes(self::PAROLA_KODU_DAKIKA)
                ->isPast();

        if ($satir === null || $suresiDoldu || ! Hash::check($data['code'], $satir->token)) {
            AppLog::event(
                'Parola sıfırlama başarısız',
                ['email' => $data['email'], 'sebep' => $satir === null ? 'kod yok' : ($suresiDoldu ? 'süre doldu' : 'kod hatalı')],
                null,
                'warning',
            );

            throw ValidationException::withMessages([
                'code' => ['Kod geçersiz ya da süresi dolmuş. Yeniden kod iste.'],
            ]);
        }

        $user = User::where('email', $data['email'])->firstOrFail();

        DB::transaction(function () use ($user, $data): void {
            // Parola AÇIK veriliyor: User modelinde 'password' cast'i
            // 'hashed' ve hash'lemeyi o yapıyor (bkz. register).
            $user->update(['password' => $data['password']]);

            // Kod tek kullanımlık.
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();

            // TÜM oturumlar kapatılıyor — mevcut cihaz dahil.
            //
            // Parola sıfırlamanın sebebi çoğu zaman "hesabıma başkası
            // erişmiş olabilir"dir. Açık kalan bir jeton bırakmak, o
            // ihtimalde sıfırlamayı anlamsız kılar. Kullanıcı yeni
            // parolasıyla yeniden giriş yapar.
            $user->tokens()->delete();
        });

        AppLog::event('Parola sıfırlandı', [], $user);
    }
}
