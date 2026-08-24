<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Abonelik yaptırımı (mobil API) — bkz. docs/10 § SaaS Vizyonu.
 *
 * Süresi dolmuş (veya admin tarafından askıya alınmış) şirketin veri
 * uçlarına erişimi 402 ile kesilir. Kimlik (me/logout) ve abonelik
 * yenileme uçları (plans/subscription/payment-requests) bilinçli olarak
 * bu middleware'in DIŞINDA tutulur — kullanıcı süresi dolduktan sonra da
 * durumunu görebilmeli ve ödeme bildirimi yapabilmelidir (bkz.
 * routes/api.php gruplandırması).
 *
 * Mobil taraf 402 + SUBSCRIPTION_EXPIRED kodunu tanır: senkron kuyruğu
 * PENDING kalır (veri kaybolmaz, yenileme sonrası akar) ve kullanıcıya
 * abonelik ekranı gösterilir.
 */
class EnsureSubscriptionIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $company = $request->user()?->company;

        if ($company !== null && ! $company->hasActiveSubscription()) {
            return response()->json([
                'message' => 'Aboneliğinin süresi dolmuş. Devam etmek için bir paket seçip ödeme bildirimi yapmalısın.',
                'code' => 'SUBSCRIPTION_EXPIRED',
            ], 402);
        }

        return $next($request);
    }
}
