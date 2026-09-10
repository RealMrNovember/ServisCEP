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
        // Sunucu Cloudflare arkasında. Şema/host/port başlıklarına
        // güvenilmesi ŞART: eksik olduğunda signed URL doğrulaması şemayı
        // (http/https) yanlış çözüyor ve her zaman 403 dönüyordu
        // (bkz. docs/09 § Dosya Güvenliği).
        //
        // X-Forwarded-For BİLEREK DIŞARIDA — bu bir güvenlik düzeltmesi:
        //
        // Burada eskiden HEADER_X_FORWARDED_FOR da vardı. `at: '*'` ile
        // birlikte Symfony, XFF zincirindeki bütün adresleri güvenilir
        // sayıp eliyor ve geriye EN SOLDAKİ, yani İSTEMCİNİN KENDİ
        // yazdığı değer kalıyordu (Request::getClientIps). Cloudflare
        // gelen XFF'i silmiyor, sonuna ekliyor. Sonuç: her istekte farklı
        // bir `X-Forwarded-For` göndererek TÜM hız sınırları
        // atlatılabiliyordu — giriş (throttle:10,1), parola sıfırlama
        // (throttle:5,10) ve veri uçları dahil. AppLog.ip ve ödeme
        // sağlayıcısına giden user_ip de sahteydi.
        //
        // Buna hiç gerek yok: nginx'te `real_ip_header CF-Connecting-IP`
        // Cloudflare aralıklarıyla birlikte zaten kurulu
        // (conf/cloudflare-realip.conf, nginx.conf'tan include ediliyor)
        // ve `fastcgi_param REMOTE_ADDR $remote_addr` ile PHP'ye GERÇEK
        // istemci IP'si geliyor. CF-Connecting-IP yalnızca Cloudflare'in
        // kendi IP'lerinden kabul edildiği için taklit edilemiyor.
        // Dolayısıyla XFF'e güvenmek, zaten doğru olan bir değerin
        // istemci tarafından ezilmesine izin vermekten başka bir işe
        // yaramıyordu.
        $middleware->trustProxies(at: '*', headers: Request::HEADER_X_FORWARDED_HOST
            | Request::HEADER_X_FORWARDED_PORT
            | Request::HEADER_X_FORWARDED_PROTO);

        $middleware->alias([
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
