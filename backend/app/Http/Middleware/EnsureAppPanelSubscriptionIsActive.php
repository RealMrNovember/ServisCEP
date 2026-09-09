<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Abonelik yaptırımı (web/Filament App paneli) — API tarafındaki
 * Web panelinin abonelik kapısı.
 *
 * Mobil API'deki karşılığı 2026-09-10'da KALDIRILDI: veri uçlarını
 * kesmek, ödemesi gecikmiş müşterinin yedeklemesini de durduruyordu.
 * Panelde durum farklı — burada veri girişi doğrudan sunucuya yazılıyor,
 * yani kapı "yedeklemeyi engellemek" değil "yeni kayıt girişini
 * engellemek" anlamına geliyor ve amaç tam olarak bu.
 *
 * Süresi dolmuş şirketin kullanıcısı panelde yalnızca "Abonelik"
 * sayfasını görebilir; diğer sayfalara GET istekleri oraya yönlendirilir.
 * Yalnızca GET'lere bakılır: Livewire etkileşimleri (Abonelik sayfasındaki
 * ödeme bildirimi formu dahil) POST üzerinden akar ve engellenmemelidir.
 * Çıkış (logout) da POST olduğu için her zaman çalışır.
 */
class EnsureAppPanelSubscriptionIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->isMethod('GET')) {
            return $next($request);
        }

        $company = $request->user()?->company;

        if ($company === null || $company->hasActiveSubscription()) {
            return $next($request);
        }

        if ($request->routeIs('filament.app.pages.subscription')) {
            return $next($request);
        }

        return redirect()->route('filament.app.pages.subscription');
    }
}
