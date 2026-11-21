<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppLog;
use App\Models\Plan;
use App\Models\SubscriptionPayment;
use App\Services\Payment\StripeGateway;
use App\Services\SubscriptionService;
use App\Support\PaymentConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Kartla abonelik ödemesi.
 *
 * [PaymentController] ile karıştırılmamalı: o, kullanıcının kendi
 * müşterisinden aldığı tahsilatı yönetir. Bu, TeknikCEP'e yapılan
 * abonelik ödemesidir.
 *
 * İki uç var ve güvenlik açısından çok farklılar:
 *
 *  - `checkout` kimlik ister. Tutarı SUNUCU hesaplar; istemciden gelen
 *    tutara asla bakılmaz, aksi halde kullanıcı 1 kuruşa yıllık abonelik
 *    alabilirdi.
 *  - `webhook` kimlik İSTEMEZ (Stripe'ın sunucusundan gelir) ama
 *    `Stripe-Signature` başlığıyla doğrulanır. Doğrulanmamış bir istek
 *    hiçbir şeyi değiştirmez.
 */
class SubscriptionCheckoutController extends Controller
{
    public function __construct(
        private readonly StripeGateway $gateway,
        private readonly SubscriptionService $subscriptions,
    ) {}

    public function checkout(Request $request): JsonResponse
    {
        if (! PaymentConfig::isCardReady()) {
            return response()->json([
                'message' => 'Kart ödemesi şu anda kullanılamıyor.',
            ], 503);
        }

        $data = $request->validate([
            'plan_id' => ['required', 'uuid', 'exists:plans,id'],
            'duration' => ['required', 'in:MONTHLY,YEARLY'],
        ]);

        $user = $request->user();
        $company = $user->company;
        $plan = Plan::findOrFail($data['plan_id']);

        // Tutar SUNUCUDA belirlenir.
        $tutar = $data['duration'] === SubscriptionPayment::DURATION_YEARLY
            ? (int) $plan->price_yearly_minor
            : (int) $plan->price_minor;

        if ($tutar <= 0) {
            return response()->json([
                'message' => 'Bu paket için kartla ödeme tanımlı değil.',
            ], 422);
        }

        $payment = SubscriptionPayment::create([
            'company_id' => $company->id,
            'plan_id' => $plan->id,
            'requested_by_user_id' => $user->id,
            'amount_minor' => $tutar,
            'currency' => 'TRY',
            'duration' => $data['duration'],
            'provider' => PaymentConfig::PROVIDER_STRIPE,
            // client_reference_id / metadata üzerinden webhook'ta geri
            // bulunur — yalnızca harf-rakam.
            'provider_ref' => 'TC'.Str::upper(Str::random(20)),
            'status' => SubscriptionPayment::STATUS_PENDING,
        ]);

        AppLog::event('Kart ödemesi başlatıldı', [
            'odeme_id' => $payment->id,
            'siparis_no' => $payment->provider_ref,
            'sirket_id' => $company->id,
            'paket' => $plan->name,
            'sure' => $data['duration'],
            'tutar_minor' => $tutar,
        ], user: $user);

        $sonuc = $this->gateway->startCheckout(
            $payment->load(['plan', 'company']),
            (string) $user->email,
            (string) $request->ip(),
        );

        if (! ($sonuc['ok'] ?? false)) {
            $payment->update(['status' => SubscriptionPayment::STATUS_FAILED]);

            AppLog::event('Kart ödemesi başlatılamadı', [
                'odeme_id' => $payment->id,
                'siparis_no' => $payment->provider_ref,
                'sebep' => $sonuc['reason'] ?? null,
            ], user: $user, level: 'error');

            return response()->json([
                'message' => $sonuc['reason'] ?? 'Ödeme başlatılamadı.',
            ], 502);
        }

        return response()->json([
            'data' => [
                'payment_id' => $payment->id,
                'payment_url' => $sonuc['url'],
            ],
        ]);
    }

    /**
     * Stripe webhook bildirimi.
     *
     * Gövde olarak SADECE "OK" dönülmeli; aksi halde Stripe bildirimi
     * başarısız sayıp tekrar tekrar gönderiyor ve ödeme panelinde "devam
     * ediyor" olarak asılı kalıyor.
     */
    public function webhook(Request $request): Response
    {
        $sonuc = $this->gateway->verifyAndParse($request);

        if ($sonuc === null) {
            AppLog::event(
                'Ödeme bildirimi imzası doğrulanamadı',
                [],
                level: 'warning',
            );

            return response('BAD SIGNATURE', 400);
        }

        // İmza geçerli ama dinlemediğimiz bir olay türü (örn.
        // payment_intent.created) — işlem yok, yine de 200 dönülür.
        if ($sonuc['status'] === 'ignored') {
            return response('OK');
        }

        $payment = SubscriptionPayment::where('provider_ref', $sonuc['provider_ref'])->first();

        if ($payment === null) {
            // Karşılığı olmayan ama İMZASI GEÇERLİ bir bildirim: gerçekten
            // para hareketi olmuş demektir. Yalnızca günlüğe yazmak yetmez,
            // günlükler budanıyor; para hareketi budanmamalı.
            //
            // Kayıt ORPHAN olarak tutulur, hangi şirkete ait olduğu
            // sonradan belirlenip elle bağlanabilir. Sağlayıcı panelinden
            // elle üretilmiş bir ödeme bağlantısı ya da uygulamada kart
            // akışı henüz yokken yapılmış bir ödeme böyle düşer.
            SubscriptionPayment::create([
                'company_id' => null,
                'amount_minor' => $sonuc['total_amount'],
                'currency' => 'TRY',
                'duration' => null,
                'provider' => PaymentConfig::PROVIDER_STRIPE,
                'provider_ref' => $sonuc['provider_ref'],
                'status' => SubscriptionPayment::STATUS_ORPHAN,
                'provider_payload' => $sonuc,
                'paid_at' => $sonuc['status'] === 'success' ? now() : null,
            ]);

            AppLog::event('Karşılığı olmayan ödeme bildirimi kaydedildi', [
                'siparis_no' => $sonuc['provider_ref'],
                'tutar_minor' => $sonuc['total_amount'],
                'sonuc' => $sonuc['status'],
            ], level: 'warning');

            // Stripe'a yine OK dönülür; aksi halde bildirimi sonsuza kadar
            // tekrar dener.
            return response('OK');
        }

        // Aynı bildirim birden fazla kez gelebilir. Zaten işlenmişse
        // abonelik İKİNCİ KEZ uzatılmaz.
        if ($payment->status === SubscriptionPayment::STATUS_PAID) {
            // Mükerrer bildirim. Abonelik ikinci kez UZATILMADI; kayıt
            // yine de tutulur ki "çift ödeme mi oldu" sorusu sonradan
            // cevaplanabilsin.
            AppLog::event('Mükerrer ödeme bildirimi yok sayıldı', [
                'odeme_id' => $payment->id,
                'siparis_no' => $payment->provider_ref,
                'sirket_id' => $payment->company_id,
            ], level: 'warning');

            return response('OK');
        }

        if ($sonuc['status'] !== 'success') {
            $payment->update([
                'status' => SubscriptionPayment::STATUS_FAILED,
                'provider_payload' => $sonuc,
            ]);

            AppLog::event('Kart ödemesi başarısız', [
                'odeme_id' => $payment->id,
                'siparis_no' => $payment->provider_ref,
                'sirket_id' => $payment->company_id,
            ], level: 'error');

            return response('OK');
        }

        $company = $payment->company;
        $oncekiBitis = $company?->subscription_expires_at;

        DB::transaction(function () use ($payment, $sonuc): void {
            $payment->update([
                'status' => SubscriptionPayment::STATUS_PAID,
                'provider_payload' => $sonuc,
                'paid_at' => now(),
            ]);
        });

        if ($company !== null) {
            // Süre hesabı TEK kaynaktan gelir. Bu mantık daha önce iki
            // yerde ayrı yazıldığı için birbirinden sapmıştı; üçüncü bir
            // kopya çıkarmak aynı hatayı tekrarlamak olurdu.
            //
            // Servis ayrıca eşzamanlı uzatmalara karşı kilit alıyor ve
            // "erken yenileyen gün kaybetmez" kuralını uyguluyor.
            $this->subscriptions->applyForPlan(
                $company,
                $payment->plan,
                $payment->duration,
            );

            // Ödeme yapan kişi aboneliğinin uzadığını öğrenmeli.
            $this->subscriptions->notifyChanged($company->refresh(), $oncekiBitis);
        }

        AppLog::event('Kartla abonelik ödemesi alındı', [
            'odeme_id' => $payment->id,
            'siparis_no' => $payment->provider_ref,
            'sirket_id' => $payment->company_id,
            'tutar_minor' => $payment->amount_minor,
            'cekilen_minor' => $sonuc['total_amount'],
            'sure' => $payment->duration,
            'yeni_bitis' => $company?->subscription_expires_at?->toDateString(),
        ]);

        return response('OK');
    }
}
