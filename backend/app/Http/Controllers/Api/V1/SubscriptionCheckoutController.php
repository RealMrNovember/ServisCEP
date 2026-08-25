<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppLog;
use App\Models\Plan;
use App\Models\SubscriptionPayment;
use App\Services\Payment\PayTrGateway;
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
 *  - `callback` kimlik İSTEMEZ (sağlayıcının sunucusundan gelir) ama
 *    imzayla doğrulanır. Doğrulanmamış bir istek hiçbir şeyi değiştirmez.
 */
class SubscriptionCheckoutController extends Controller
{
    public function __construct(
        private readonly PayTrGateway $gateway,
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
            'provider' => PaymentConfig::PROVIDER_PAYTR,
            // Sağlayıcı sipariş numarasında yalnızca harf-rakam kabul ediyor.
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
     * Sağlayıcı bildirimi.
     *
     * Gövde olarak SADECE "OK" dönülmeli; aksi halde sağlayıcı bildirimi
     * başarısız sayıp tekrar tekrar gönderiyor ve ödeme panelinde "devam
     * ediyor" olarak asılı kalıyor.
     */
    public function callback(Request $request): Response
    {
        $post = $request->all();

        if (! $this->gateway->verifyCallback($post)) {
            AppLog::event(
                'Ödeme bildirimi imzası doğrulanamadı',
                ['merchant_oid' => $post['merchant_oid'] ?? null],
                level: 'warning',
            );

            return response('BAD HASH', 400);
        }

        $payment = SubscriptionPayment::where('provider_ref', $post['merchant_oid'])->first();

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
                'amount_minor' => (int) ($post['total_amount'] ?? 0),
                'currency' => 'TRY',
                'duration' => null,
                'provider' => PaymentConfig::PROVIDER_PAYTR,
                'provider_ref' => (string) $post['merchant_oid'],
                'status' => SubscriptionPayment::STATUS_ORPHAN,
                'provider_payload' => $post,
                'paid_at' => ($post['status'] ?? '') === 'success' ? now() : null,
            ]);

            AppLog::event('Karşılığı olmayan ödeme bildirimi kaydedildi', [
                'siparis_no' => $post['merchant_oid'] ?? null,
                'tutar_minor' => (int) ($post['total_amount'] ?? 0),
                'sonuc' => $post['status'] ?? null,
            ], level: 'warning');

            // Sağlayıcıya yine OK dönülür; aksi halde bildirimi sonsuza
            // kadar tekrar dener.
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

        if (($post['status'] ?? '') !== 'success') {
            $payment->update([
                'status' => SubscriptionPayment::STATUS_FAILED,
                'provider_payload' => $post,
            ]);

            AppLog::event('Kart ödemesi başarısız', [
                'odeme_id' => $payment->id,
                'siparis_no' => $payment->provider_ref,
                'sirket_id' => $payment->company_id,
                'hata_kodu' => $post['failed_reason_code'] ?? null,
                'hata_mesaji' => $post['failed_reason_msg'] ?? null,
            ], level: 'error');

            return response('OK');
        }

        $company = $payment->company;
        $oncekiBitis = $company?->subscription_expires_at;

        DB::transaction(function () use ($payment, $post): void {
            $payment->update([
                'status' => SubscriptionPayment::STATUS_PAID,
                'provider_payload' => $post,
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
            'cekilen_minor' => (int) ($post['total_amount'] ?? 0),
            'sure' => $payment->duration,
            'yeni_bitis' => $company?->subscription_expires_at?->toDateString(),
        ]);

        return response('OK');
    }
}
