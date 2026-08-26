<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Company;
use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging (HTTP v1) gönderici — bkz. docs/06 § Push
 * Notification.
 *
 * Kimlik doğrulama, servis hesabı anahtarıyla imzalanan bir JWT'nin
 * erişim jetonuna takas edilmesiyle yapılır (Google'ın standart
 * "service account" akışı). Ek bir SDK/paket bağımlılığı YOKTUR —
 * imzalama openssl ile yapılır.
 *
 * Anahtar dosyası repoda DEĞİLDİR; yalnızca sunucuda
 * `storage/app/firebase/service-account.json` altında, 600 izinle durur
 * (bkz. .env `FIREBASE_CREDENTIALS`).
 *
 * Tasarım kararı: gönderim hataları ASLA çağıranın işlemini bozmaz —
 * bildirim gidememesi, tahsilat onayı gibi asıl işlemin başarısız
 * sayılmasına yol açmamalıdır. Hatalar loglanır, sessizce yutulmaz.
 */
class FcmService
{
    private const TOKEN_CACHE_KEY = 'fcm:access_token';

    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function isConfigured(): bool
    {
        $path = $this->credentialsPath();

        return $path !== null && is_readable($path);
    }

    /**
     * Bir şirketin tüm kayıtlı cihazlarına bildirim gönderir.
     *
     * @param  array<string, string>  $data  Uygulamanın yönlendirme için
     *                                       kullanacağı ek veriler.
     * @return int Başarıyla gönderilen cihaz sayısı.
     */
    public function sendToCompany(Company $company, string $title, string $body, array $data = []): int
    {
        $tokens = DeviceToken::where('company_id', $company->id)->pluck('token')->all();

        return $this->sendToTokens($tokens, $title, $body, $data);
    }

    public function sendToUser(User $user, string $title, string $body, array $data = []): int
    {
        $tokens = DeviceToken::where('user_id', $user->id)->pluck('token')->all();

        return $this->sendToTokens($tokens, $title, $body, $data);
    }

    /**
     * @param  array<int, string>  $tokens
     * @param  array<string, string>  $data
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): int
    {
        if ($tokens === [] || ! $this->isConfigured()) {
            return 0;
        }

        $accessToken = $this->accessToken();
        if ($accessToken === null) {
            return 0;
        }

        $projectId = $this->projectId();
        $sent = 0;

        foreach ($tokens as $token) {
            $response = Http::withToken($accessToken)
                ->acceptJson()
                ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                    'message' => [
                        'token' => $token,
                        'notification' => ['title' => $title, 'body' => $body],
                        // Tüm değerler string olmalı — FCM v1 data payload'ı
                        // yalnızca string kabul eder.
                        'data' => array_map(static fn ($v) => (string) $v, $data),
                        'android' => [
                            'priority' => 'high',
                            'notification' => ['channel_id' => 'job_reminders'],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                $sent++;

                continue;
            }

            if ($this->isDeadToken($response->status(), (string) $response->json('error.message'))) {
                DeviceToken::where('token', $token)->delete();

                continue;
            }

            Log::warning('FCM gönderimi başarısız', [
                'status' => $response->status(),
                'body' => $response->json('error.message'),
            ]);
        }

        return $sent;
    }

    /**
     * Token bir daha ASLA çalışmayacak mı? Öyleyse kayıt silinir, aksi
     * halde geçici bir hata olabilir ve kayıt korunur.
     *
     * - 404 (UNREGISTERED): uygulama silinmiş / token geçersizleşmiş
     * - 403 (SENDER_ID_MISMATCH): token başka bir projeye ait
     * - 400 (INVALID_ARGUMENT): YALNIZCA hata mesajı token'ı işaret
     *   ediyorsa. 400, bizim gönderdiğimiz mesajın bozuk olmasından da
     *   kaynaklanabilir — o durumda kullanıcının cihaz kaydını silmek
     *   yanlış olurdu, bu yüzden ayrım mesaj metnine göre yapılır.
     */
    private function isDeadToken(int $status, string $message): bool
    {
        if (in_array($status, [403, 404], true)) {
            return true;
        }

        return $status === 400 && str_contains(strtolower($message), 'registration token');
    }

    private function accessToken(): ?string
    {
        return Cache::remember(self::TOKEN_CACHE_KEY, now()->addMinutes(50), function (): ?string {
            $credentials = $this->credentials();
            if ($credentials === null) {
                return null;
            }

            $now = time();
            $header = $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $this->base64Url(json_encode([
                'iss' => $credentials['client_email'],
                'scope' => self::SCOPE,
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));

            $signature = '';
            if (! openssl_sign("{$header}.{$claims}", $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
                Log::error('FCM: JWT imzalanamadı.');

                return null;
            }

            $jwt = "{$header}.{$claims}.".$this->base64Url($signature);

            $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if (! $response->successful()) {
                Log::error('FCM: erişim jetonu alınamadı', ['body' => $response->body()]);

                return null;
            }

            return $response->json('access_token');
        });
    }

    /**
     * @return array{client_email: string, private_key: string, project_id: string}|null
     */
    private function credentials(): ?array
    {
        $path = $this->credentialsPath();
        if ($path === null || ! is_readable($path)) {
            return null;
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        return is_array($decoded) ? $decoded : null;
    }

    private function credentialsPath(): ?string
    {
        $configured = config('services.fcm.credentials');

        return is_string($configured) && $configured !== '' ? $configured : null;
    }

    private function projectId(): string
    {
        return (string) (config('services.fcm.project_id') ?: ($this->credentials()['project_id'] ?? ''));
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
