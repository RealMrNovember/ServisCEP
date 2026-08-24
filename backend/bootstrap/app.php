<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Sunucu Cloudflare arkasında (nginx, PHP-FPM'e unix socket ile
        // bağlanıyor) — gerçek istemci IP'si her zaman Cloudflare'in edge
        // IP'si olarak görünür ve bu aralıklar değişken olduğu için tek
        // tek IP güvenmek yerine tüm proxy'lere güvenip yalnızca
        // X-Forwarded-* başlıklarını kabul ediyoruz (Laravel'in resmi
        // önerisi). Bunun eksik olması, signed URL doğrulamasının şemayı
        // (http/https) yanlış çözmesine ve her zaman 403 dönmesine yol
        // açıyordu (bkz. docs/09 § Dosya Güvenliği).
        $middleware->trustProxies(at: '*', headers: Request::HEADER_X_FORWARDED_FOR
            | Request::HEADER_X_FORWARDED_HOST
            | Request::HEADER_X_FORWARDED_PORT
            | Request::HEADER_X_FORWARDED_PROTO);

        $middleware->alias([
            'subscription.active' => \App\Http\Middleware\EnsureSubscriptionIsActive::class,
        ]);

        // Laravel'in varsayılanı `redirectGuestsTo(fn () => route('login'))`
        // — bu uygulamada `login` adında bir route YOK (girişler Filament
        // panellerinin kendi route'ları). Sonuç: `Accept: application/json`
        // göndermeyen her kimliksiz istek 401 yerine 500 "Server Error"
        // alıyordu; hata middleware'in İÇİNDE (route() çağrısında) oluştuğu
        // için exception handler'a hiç ulaşmıyordu. Production smoke
        // testinde yakalandı, TÜM korumalı uçları etkiliyordu.
        $middleware->redirectGuestsTo(function (Request $request): ?string {
            // API asla yönlendirilmez — temiz 401 JSON döner.
            if ($request->is('api/*')) {
                return null;
            }

            return Route::has('filament.app.auth.login')
                ? route('filament.app.auth.login')
                : '/';
        });
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Kimliksiz API isteği temiz bir 401 almalı. Laravel'in varsayılan
        // davranışı `route('login')`'a yönlendirmeye çalışmaktır; bu uygulamada
        // öyle bir route yok (panel girişleri Filament'in kendi route'ları) —
        // sonuç: `Accept: application/json` göndermeyen her yetkisiz istek
        // 401 yerine 500 "Server Error" alıyordu. Production smoke testinde
        // yakalandı; TÜM API uçlarını etkiliyordu, yalnızca yenilerini değil.
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Unauthenticated.'], 401);
            }

            return null;
        });
    })->create();
