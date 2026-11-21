<?php

declare(strict_types=1);

namespace App\Services\Payment;

use App\Models\SubscriptionPayment;
use App\Support\PaymentConfig;
use Illuminate\Http\Request;
use Stripe\Exception\ApiErrorException;
use Stripe\Exception\SignatureVerificationException;
use Stripe\StripeClient;
use Stripe\Webhook;
use UnexpectedValueException;

/**
 * Stripe Checkout entegrasyonu.
 *
 * Akış: sunucu bir Checkout Session oluşturur, kullanıcıya Stripe'ın
 * barındırdığı güvenli ödeme sayfası (mobilde WebView içinde) gösterilir,
 * sonuç bize WEBHOOK ile bildirilir. Kart bilgisi hiçbir zaman bizim
 * sunucumuza uğramaz — PCI yükümlülüğünü üstlenmemenin tek yolu bu
 * (PayTR entegrasyonundan devralınan ilke).
 *
 * DİKKAT: webhook imzası `Stripe-Signature` başlığından, HAM istek
 * gövdesiyle doğrulanır. Gövde `$request->all()` ile yeniden kodlanıp
 * doğrulanırsa imza her zaman reddedilir — bu yüzden `getContent()`
 * kullanılıyor, asla parse edilmiş gövde değil.
 */
class StripeGateway
{
    /**
     * Ödeme sayfası için bir Checkout Session oluşturur ve adresini döner.
     *
     * @return array{ok: bool, url?: string, reason?: string}
     */
    public function startCheckout(SubscriptionPayment $payment, string $email, string $userIp): array
    {
        $secretKey = PaymentConfig::secret('payment.stripe.secret_key');

        if ($secretKey === null) {
            return ['ok' => false, 'reason' => 'Ödeme sağlayıcısı yapılandırılmamış.'];
        }

        $stripe = new StripeClient($secretKey);

        try {
            $session = $stripe->checkout->sessions->create([
                'mode' => 'payment',
                'payment_method_types' => ['card'],
                // Webhook geldiğinde ödemeyi SubscriptionPayment kaydına
                // geri bağlamanın tek yolu — PayTR'deki merchant_oid'in
                // karşılığı.
                'client_reference_id' => $payment->provider_ref,
                'customer_email' => $email,
                'line_items' => [[
                    'quantity' => 1,
                    'price_data' => [
                        'currency' => 'try',
                        // Zaten kuruş (minor unit) cinsinden — dönüşüm yok.
                        'unit_amount' => $payment->amount_minor,
                        'product_data' => [
                            'name' => $payment->plan?->name ?? 'Abonelik',
                        ],
                    ],
                ]],
                'success_url' => url('/odeme/sonuc/basarili').'?session_id={CHECKOUT_SESSION_ID}',
                'cancel_url' => url('/odeme/sonuc/basarisiz'),
                'metadata' => [
                    'provider_ref' => $payment->provider_ref,
                ],
            ]);
        } catch (ApiErrorException) {
            return ['ok' => false, 'reason' => 'Ödeme sağlayıcısına ulaşılamadı.'];
        }

        return ['ok' => true, 'url' => (string) $session->url];
    }

    /**
     * Webhook imzasını doğrular ve ilgileniğimiz bir olaysa normalize
     * edilmiş alanları döner.
     *
     * Doğrulanmamış bir bildirimle abonelik UZATILMAZ: aksi halde herkes
     * bize bir POST atarak kendine ücretsiz abonelik açabilirdi.
     *
     * @return array{provider_ref: string, status: string, total_amount: int}|null
     *               null: imza geçersiz (çağıran 400 dönmeli).
     *               provider_ref==='': imza geçerli ama ilgilenmediğimiz
     *               bir olay türü (çağıran 200 OK dönmeli, işlem yok).
     */
    public function verifyAndParse(Request $request): ?array
    {
        $webhookSecret = PaymentConfig::secret('payment.stripe.webhook_secret');
        $sigHeader = $request->header('Stripe-Signature');

        if ($webhookSecret === null || $sigHeader === null) {
            return null;
        }

        try {
            $event = Webhook::constructEvent(
                $request->getContent(),
                $sigHeader,
                $webhookSecret,
            );
        } catch (SignatureVerificationException|UnexpectedValueException) {
            return null;
        }

        if ($event->type !== 'checkout.session.completed') {
            return ['provider_ref' => '', 'status' => 'ignored', 'total_amount' => 0];
        }

        $session = $event->data->object;
        $ref = $session->client_reference_id ?? ($session->metadata['provider_ref'] ?? null);

        if ($ref === null || $ref === '') {
            return null;
        }

        return [
            'provider_ref' => (string) $ref,
            'status' => $session->payment_status === 'paid' ? 'success' : 'failed',
            'total_amount' => (int) ($session->amount_total ?? 0),
        ];
    }
}
