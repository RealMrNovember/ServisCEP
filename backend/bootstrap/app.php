<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

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
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
