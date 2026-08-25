<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Diagnostics\StoreDiagnosticRequest;
use App\Models\AppLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

/**
 * Mobil uygulamanın yakaladığı hataları toplar.
 *
 * **Kimlik doğrulaması İSTEMEZ.** Sebebi somut: bir cihazda kimlik
 * doğrulama tamamen çalışmaz hâle geldi ve kullanıcı günlerce giriş
 * yapamadı; hatayı bize gönderebilecek tek an tam da giriş yapamadığı
 * andı. Yalnızca oturum açmış kullanıcıların hata bildirebildiği bir
 * sistem, en çok ihtiyaç duyulan hataları asla göremez.
 *
 * Kötüye kullanıma karşı koruma kimlik doğrulama değil, hız sınırı ve
 * alan sınırlarıdır (bkz. routes/api.php `throttle` ve FormRequest).
 */
class DiagnosticsController extends Controller
{
    public function store(StoreDiagnosticRequest $request): JsonResponse
    {
        $data = $request->validated();
        // Uçta `auth:sanctum` YOK (bilinçli, bkz. sınıf notu) — bu yüzden
        // token varsa guard elle çözülür. Oturum açmış kullanıcıdan gelen
        // bir hatayı kime ait olduğunu bilmeden kaydetmek, kaydın yarısını
        // kaybetmek demek.
        $user = $request->user('sanctum');

        AppLog::create([
            'id' => (string) Str::uuid(),
            'level' => $data['level'] ?? 'error',
            'source' => AppLog::SOURCE_MOBILE,
            'message' => Str::limit($data['message'], 250, ''),
            'context' => [
                'screen' => $data['screen'] ?? null,
                'detail' => isset($data['detail'])
                    ? Str::limit($data['detail'], 4000, '…')
                    : null,
                'os_version' => $data['os_version'] ?? null,
                'connectivity' => $data['connectivity'] ?? null,
                // İstemcinin ürettiği zaman: cihaz çevrimdışıyken oluşan
                // kayıtlar sonradan gönderiliyor, sunucu saati o anı
                // yansıtmaz.
                'occurred_at' => $data['occurred_at'] ?? null,
            ],
            'user_id' => $user?->getKey() ? (string) $user->getKey() : null,
            'company_id' => $user?->company_id ? (string) $user->company_id : null,
            'ip' => $request->ip(),
            'platform' => $data['platform'] ?? 'mobile',
            'app_version' => $data['app_version'] ?? null,
            'device' => isset($data['device'])
                ? Str::limit($data['device'], 120, '')
                : null,
            'created_at' => now(),
        ]);

        // Gövde bilinçli olarak boş: uygulama cevabı beklemeden yoluna
        // devam edebilmeli, tanılama göndermek kullanıcı akışını
        // yavaşlatmamalı.
        return response()->json(null, 202);
    }
}
