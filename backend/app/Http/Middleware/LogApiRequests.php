<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\AppLog;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * API isteklerinin sonucunu `app_logs` tablosuna yazar.
 *
 * Kayit `terminate()` icinde, yanit istemciye gonderildikten SONRA yapilir.
 * Sebebi hem dogruluk hem hiz:
 *
 *  - Dogruluk: `handle()` icinde `$next()`in donus degerine bakmak
 *    yetmiyor. Bir ara katman (or. `auth:sanctum`) istisna firlattiginda
 *    yaniti Laravel kendi ardisik duzeninde uretiyor ve bu deger aradaki
 *    ara katmanlara ulasmiyor; 401ler bu yuzden hic kaydedilmiyordu.
 *    `terminate()` her zaman NIHAI yaniti alir.
 *  - Hiz: gunluk yazimi kullanicinin bekledigi sureye eklenmez.
 *
 * Kapsam bilincli olarak DAR: yalnizca basarisiz istekler (4xx/5xx) ve
 * olagandisi yavas olanlar kaydedilir. Her 200u yazmak tabloyu gunde on
 * binlerce satirla doldurur ve asil aranan kaydi gorunmez kilardi.
 *
 * Istek govdesi ASLA kaydedilmez - parola, token ve musteri verisi tasir.
 */
class LogApiRequests
{
    /** Bu sureyi asan basarili istekler de kaydedilir (ms). */
    private const SLOW_MS = 3000;

    /** Istemci kunyesi basliklari - bkz. mobile/lib/core/network/client_headers.dart */
    private const HEADER_VERSION = 'X-App-Version';

    private const HEADER_BUILD = 'X-App-Build';

    private const HEADER_PLATFORM = 'X-Platform';

    private const HEADER_DEVICE = 'X-Device-Model';

    /** Kunye bu dakikadan eskiyse tazelenir. */
    private const SEEN_TTL_MIN = 15;

    private float $startedAt = 0.0;

    public function handle(Request $request, Closure $next): Response
    {
        $this->startedAt = microtime(true);

        return $next($request);
    }

    public function terminate(Request $request, Response $response): void
    {
        $durationMs = $this->startedAt > 0
            ? (int) round((microtime(true) - $this->startedAt) * 1000)
            : 0;

        $status = $response->getStatusCode();

        // Istemci kunyesi gunluk kosullarindan BAGIMSIZ kaydedilir:
        // basarili bir istek gunluge yazilmiyor ama kullanicinin hangi
        // surumde oldugu tam da o istekten ogreniliyor.
        $this->recordClientInfo($request);

        if ($status < 400 && $durationMs < self::SLOW_MS) {
            return;
        }

        try {
            // Sanctum ile gelen token, `auth:sanctum` uygulanmamis uclarda
            // varsayilan guard tarafindan cozulmez.
            $user = $request->user('sanctum') ?? $request->user();
            $denenenEposta = $this->attemptedEmail($request);
            $kim = $user?->email ?? $denenenEposta;

            AppLog::create([
                'id' => (string) Str::uuid(),
                'level' => match (true) {
                    $status >= 500 => 'error',
                    $status >= 400 => 'warning',
                    default => 'info',
                },
                'source' => AppLog::SOURCE_REQUEST,
                'message' => $this->summary($kim, $status, $durationMs),
                'context' => array_filter([
                    'query' => Str::limit((string) $request->getQueryString(), 200, '') ?: null,
                    'sunucu_mesaji' => $this->responseMessage($response),
                    // Kimliği doğrulanamamış bir istekte "kim" sorusunun tek
                    // cevabı denenen e-posta oluyor.
                    'denenen_eposta' => $denenenEposta,
                ]),
                'user_id' => $user?->getKey() ? (string) $user->getKey() : null,
                'company_id' => $user?->company_id ? (string) $user->company_id : null,
                'method' => $request->method(),
                'path' => Str::limit('/'.ltrim($request->path(), '/'), 250, ''),
                'status' => $status,
                'duration_ms' => $durationMs,
                'ip' => $request->ip(),
                'platform' => $this->clientPlatform($request),
                'app_version' => Str::limit((string) $request->header('X-App-Version'), 30, '') ?: null,
                'device' => Str::limit((string) $request->header('X-Device-Model'), 120, '') ?: null,
                'created_at' => now(),
            ]);
        } catch (Throwable $e) {
            // Canlida sessiz: gunluk yazamamak istegin kendisini bozmamali.
            // Testlerde gurultulu: sessiz kalmak, bozuk bir gunluklecinin
            // yesil testlerin arkasina saklanmasi demek olurdu.
            if (app()->runningUnitTests()) {
                throw $e;
            }
        }
    }

    /**
     * Olay satırının özeti: KİM ve NE OLDU.
     *
     * "İstek 401 ile sonuçlandı" teknik olarak doğru ama panele bakan
     * kişiye hiçbir şey anlatmıyor; asıl soru "kimin isteği". Kimlik
     * bilinmiyorsa (401'de çoğu zaman böyle) en azından denenen e-posta
     * yazılır.
     */
    private function summary(?string $kim, int $status, int $durationMs): string
    {
        $ne = match (true) {
            $status === 401 => 'yetkisiz istek',
            $status === 403 => 'erişim reddedildi',
            $status === 404 => 'bulunamadı',
            $status === 422 => 'doğrulama hatası',
            $status === 429 => 'hız sınırı aşıldı',
            $status >= 500 => 'sunucu hatası',
            $status >= 400 => "istek reddedildi ($status)",
            default => "yavaş yanıt ({$durationMs} ms)",
        };

        return $kim === null ? ucfirst($ne) : "$kim - $ne";
    }

    /**
     * Kimlik uçlarında denenen e-posta.
     *
     * Yalnızca kimlik uçlarından ve yalnızca `email` alanı okunur: başka
     * uçlarda gövde müşteri verisi taşıyor ve günlüğe girmemeli. Parola
     * hiçbir koşulda okunmaz.
     */
    private function attemptedEmail(Request $request): ?string
    {
        if (! str_contains($request->path(), 'auth/')) {
            return null;
        }

        $email = $request->input('email');

        return is_string($email) && $email !== ''
            ? Str::limit($email, 120, '')
            : null;
    }

    /**
     * Yanit govdesindeki `message` alani - "neden basarisiz oldu"
     * sorusunun cevabi cogu zaman tek satirda orada duruyor.
     */
    private function responseMessage(Response $response): ?string
    {
        $content = $response->getContent();
        if ($content === false || blank($content)) {
            return null;
        }

        $decoded = json_decode($content, true);
        if (! is_array($decoded) || ! isset($decoded['message'])) {
            return null;
        }

        return Str::limit((string) $decoded['message'], 250, '');
    }

    /**
     * Istemci turu - uygulama kendi basligini gonderirse o, yoksa
     * user-agenttan kaba bir tahmin.
     */
    private function clientPlatform(Request $request): ?string
    {
        $declared = $request->header('X-Platform');
        if (filled($declared)) {
            return Str::limit((string) $declared, 20, '');
        }

        $agent = (string) $request->userAgent();

        return match (true) {
            str_contains($agent, 'Dart/') => 'mobile',
            $agent === '' => null,
            default => 'web',
        };
    }

    /**
     * Kullanicinin en son hangi istemciyle baglandigini kaydeder.
     *
     * Destek tarafi "hangi surumu kullaniyorsunuz" sorusunu sormadan
     * cevaplayabilsin diye. app_logs tablosuna da yaziliyor ama oraya
     * guvenilemez: gunlukler duzenli budaniyor ve bir sure sessiz kalan
     * kullanicinin surumu kayboluyor.
     *
     * Yazma KISILIR: yalnizca surum degistiyse ya da kayit bayatladiysa.
     * Aksi halde her istek bir UPDATE uretirdi.
     */
    private function recordClientInfo(Request $request): void
    {
        try {
            $user = $request->user('sanctum') ?? $request->user();
            if ($user === null) {
                return;
            }

            $surum = Str::limit((string) $request->header(self::HEADER_VERSION), 30, '') ?: null;
            if ($surum === null) {
                return;
            }

            $build = (int) $request->header(self::HEADER_BUILD);
            $bayat = $user->last_seen_at === null
                || $user->last_seen_at->lt(now()->subMinutes(self::SEEN_TTL_MIN));

            if (! $bayat && $user->app_version === $surum && (int) $user->app_build === $build) {
                return;
            }

            $user->forceFill([
                'app_version' => $surum,
                'app_build' => $build > 0 ? $build : null,
                'client_platform' => Str::limit((string) $request->header(self::HEADER_PLATFORM), 20, '') ?: null,
                'device_info' => Str::limit((string) $request->header(self::HEADER_DEVICE), 120, '') ?: null,
                'last_seen_at' => now(),
            ])->saveQuietly();
        } catch (Throwable $e) {
            // Kunye kaydedilememesi istegi bozmamali.
            if (app()->runningUnitTests()) {
                throw $e;
            }
        }
    }
}
