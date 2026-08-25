<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PlanResource;
use App\Models\Setting;
use App\Support\PaymentConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class SubscriptionController extends Controller
{
    /**
     * Şirketin abonelik durumu — mobil "Abonelik" ekranının tek çağrıda
     * ihtiyaç duyduğu her şey: aktif paket, deneme mi, kalan gün ve
     * havale/EFT bilgileri. Ödeme/onay akışının web'deki karşılığı için
     * bkz. Filament\App\Pages\Subscription.
     */
    public function show(Request $request): JsonResponse
    {
        $company = $request->user()->company()->with('plan')->first();

        $expiresAt = $company->subscription_expires_at;
        $daysRemaining = null;

        if ($expiresAt !== null) {
            $daysRemaining = max(0, (int) floor(Carbon::now()->diffInDays($expiresAt, false)));
        }

        return response()->json([
            'data' => [
                'plan' => $company->plan ? new PlanResource($company->plan) : null,
                'is_trial' => $company->plan?->slug === 'deneme',
                'is_active' => $company->is_active,
                'has_active_subscription' => $company->hasActiveSubscription(),
                'subscription_expires_at' => $expiresAt?->toISOString(),
                'days_remaining' => $daysRemaining,
                // Mobil ekranın hangi akışı göstereceği.
                //
                // 'transfer': IBAN + elle bildirim (admin onayı gerekir).
                // 'card': sağlayıcı üzerinden kartla ödeme.
                //
                // Karar SUNUCUDA verilir. Uygulama sürümü ne olursa olsun,
                // sağlayıcı hazır değilken kart akışı gösterilmemeli;
                // kullanıcı çalışmayan bir ekranda takılırdı.
                'payment_mode' => PaymentConfig::mode(),
                // Havale bilgisi kart kipinde de gönderilir: sağlayıcı
                // geçici olarak düşerse kullanıcı yine de ödeyebilmeli.
                'payment_info' => [
                    'iban' => Setting::get('payment_iban'),
                    'account_holder' => Setting::get('payment_account_holder'),
                    'bank_name' => Setting::get('payment_bank_name'),
                    'note' => Setting::get('payment_note'),
                ],
            ],
        ]);
    }
}
