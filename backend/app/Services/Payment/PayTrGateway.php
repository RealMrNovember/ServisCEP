<?php

declare(strict_types=1);

namespace App\Services\Payment;

use App\Models\SubscriptionPayment;
use App\Support\PaymentConfig;
use Illuminate\Support\Facades\Http;

/**
 * PayTR iFrame API entegrasyonu.
 *
 * Kaynak: https://dev.paytr.com/iframe-api (1. ve 2. adım).
 *
 * Akış iki adımlı: sunucu bir token alır, kullanıcıya PayTR'nin güvenli
 * ödeme sayfası gösterilir, sonuç bize CALLBACK ile bildirilir. Kart
 * bilgisi hiçbir zaman bizim sunucumuza uğramaz — PCI yükümlülüğünü
 * üstlenmemenin tek yolu bu.
 *
 * DİKKAT: imza dizilerinin sırası PayTR'nin resmî örneğiyle birebir
 * aynıdır. Tek bir alanın yeri değişirse token reddedilir ya da daha
 * kötüsü, callback doğrulaması sessizce hep başarısız olur ve ödemeler
 * "devam ediyor" durumunda asılı kalır.
 */
class PayTrGateway
{
    private const TOKEN_URL = 'https://www.paytr.com/odeme/api/get-token';

    private const IFRAME_URL = 'https://www.paytr.com/odeme/guvenli/';

    /**
     * Ödeme sayfası için token alır ve iframe adresini döner.
     *
     * @return array{ok: bool, url?: string, reason?: string}
     */
    public function startCheckout(SubscriptionPayment $payment, string $email, string $userIp): array
    {
        $merchantId = PaymentConfig::secret('payment.paytr.merchant_id');
        $merchantKey = PaymentConfig::secret('payment.paytr.merchant_key');
        $merchantSalt = PaymentConfig::secret('payment.paytr.merchant_salt');

        if ($merchantId === null || $merchantKey === null || $merchantSalt === null) {
            return ['ok' => false, 'reason' => 'Ödeme sağlayıcısı yapılandırılmamış.'];
        }

        $sepet = base64_encode(json_encode([
            [$payment->plan?->name ?? 'Abonelik', (string) $payment->amount_minor, 1],
        ], JSON_UNESCAPED_UNICODE) ?: '[]');

        $testMode = PaymentConfig::isTestMode() ? '1' : '0';
        $noInstallment = '0';
        $maxInstallment = '0';
        $currency = 'TL';

        // İmza dizisi — sıra PayTR dokümanındaki ile aynı olmak ZORUNDA.
        $imzaDizisi = $merchantId
            .$userIp
            .$payment->provider_ref
            .$email
            .$payment->amount_minor
            .$sepet
            .$noInstallment
            .$maxInstallment
            .$currency
            .$testMode;

        $token = base64_encode(
            hash_hmac('sha256', $imzaDizisi.$merchantSalt, $merchantKey, true)
        );

        $yanit = Http::asForm()->timeout(20)->post(self::TOKEN_URL, [
            'merchant_id' => $merchantId,
            'user_ip' => $userIp,
            'merchant_oid' => $payment->provider_ref,
            'email' => $email,
            'payment_amount' => $payment->amount_minor,
            'paytr_token' => $token,
            'user_basket' => $sepet,
            'debug_on' => app()->isProduction() ? 0 : 1,
            'no_installment' => $noInstallment,
            'max_installment' => $maxInstallment,
            'user_name' => mb_substr($payment->company?->name ?? '', 0, 60),
            'user_address' => mb_substr($payment->company?->address ?? '-', 0, 200),
            'user_phone' => mb_substr($payment->company?->phone ?? '-', 0, 20),
            'merchant_ok_url' => url('/odeme/sonuc/basarili'),
            'merchant_fail_url' => url('/odeme/sonuc/basarisiz'),
            'timeout_limit' => 30,
            'currency' => $currency,
            'test_mode' => $testMode,
            'lang' => 'tr',
        ]);

        if (! $yanit->successful()) {
            return ['ok' => false, 'reason' => 'Ödeme sağlayıcısına ulaşılamadı.'];
        }

        $govde = $yanit->json();
        if (($govde['status'] ?? null) !== 'success') {
            return [
                'ok' => false,
                'reason' => (string) ($govde['reason'] ?? 'Ödeme başlatılamadı.'),
            ];
        }

        return ['ok' => true, 'url' => self::IFRAME_URL.$govde['token']];
    }

    /**
     * Callback imzasını doğrular.
     *
     * Doğrulanmamış bir callback ile abonelik UZATILMAZ: aksi halde
     * herkes bize bir POST atarak kendine ücretsiz abonelik açabilirdi.
     *
     * @param  array<string, mixed>  $post
     */
    public function verifyCallback(array $post): bool
    {
        $merchantKey = PaymentConfig::secret('payment.paytr.merchant_key');
        $merchantSalt = PaymentConfig::secret('payment.paytr.merchant_salt');

        if ($merchantKey === null || $merchantSalt === null) {
            return false;
        }

        foreach (['merchant_oid', 'status', 'total_amount', 'hash'] as $alan) {
            if (! isset($post[$alan])) {
                return false;
            }
        }

        $beklenen = base64_encode(hash_hmac(
            'sha256',
            $post['merchant_oid'].$merchantSalt.$post['status'].$post['total_amount'],
            $merchantKey,
            true
        ));

        // hash_equals: zamanlama saldırısına kapalı karşılaştırma.
        return hash_equals($beklenen, (string) $post['hash']);
    }
}
