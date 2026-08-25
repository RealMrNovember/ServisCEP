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

        if ($status < 400 && $durationMs < self::SLOW_MS) {
            return;
        }

        try {
            // Sanctum ile gelen token, `auth:sanctum` uygulanmamis uclarda
            // varsayilan guard tarafindan cozulmez.
            $user = $request->user('sanctum') ?? $request->user();

            AppLog::create([
                'id' => (string) Str::uuid(),
                'level' => match (true) {
                    $status >= 500 => 'error',
                    $status >= 400 => 'warning',
                    default => 'info',
                },
                'source' => AppLog::SOURCE_REQUEST,
                'message' => $status >= 400
                    ? "Istek $status ile sonuclandi"
                    : 'Yavas istek',
                'context' => array_filter([
                    'query' => Str::limit((string) $request->getQueryString(), 200, '') ?: null,
                    'sunucu_mesaji' => $this->responseMessage($response),
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
}
