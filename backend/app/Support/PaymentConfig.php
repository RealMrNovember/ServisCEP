<?php

declare(strict_types=1);

namespace App\Support;

use App\Models\Setting;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Crypt;

/**
 * Kart ödemesi yapılandırması.
 *
 * Ödeme sağlayıcısının anahtarları girilene ve "etkin" işaretlenene kadar
 * sistem HAVALE kipinde kalır: mobil ekran IBAN'ı ve elle bildirim formunu
 * gösterir, admin onayıyla abonelik uzar. Anahtarlar girildiği anda kip
 * KART'a döner ve aynı ekran kartla ödeme akışını gösterir.
 *
 * Kip bir kod değişikliğiyle değil, bu yapılandırmayla değişir — sağlayıcı
 * hazır olmadan uygulamaya kart akışı göndermenin anlamı yok.
 *
 * Gizli anahtarlar veritabanında ŞİFRELİ durur. Merchant key/salt ile bir
 * saldırgan sizin adınıza ödeme isteği imzalayabilir; düz metin saklanamaz.
 */
final class PaymentConfig
{
    /** Yalnızca statik kullanım. */
    private function __construct() {}

    /** Sağlayıcı yok — havale kipi. */
    public const PROVIDER_NONE = 'none';

    public const PROVIDER_PAYTR = 'paytr';

    public const MODE_TRANSFER = 'transfer';

    public const MODE_CARD = 'card';

    public const KEY_PROVIDER = 'payment.provider';

    public const KEY_ENABLED = 'payment.enabled';

    public const KEY_TEST_MODE = 'payment.test_mode';

    /** Şifreli saklanan anahtarlar. */
    public const SECRET_KEYS = [
        'payment.paytr.merchant_id',
        'payment.paytr.merchant_key',
        'payment.paytr.merchant_salt',
    ];

    public static function provider(): string
    {
        return Setting::get(self::KEY_PROVIDER, self::PROVIDER_NONE)
            ?? self::PROVIDER_NONE;
    }

    public static function isEnabled(): bool
    {
        return Setting::get(self::KEY_ENABLED, '0') === '1';
    }

    public static function isTestMode(): bool
    {
        return Setting::get(self::KEY_TEST_MODE, '1') === '1';
    }

    /**
     * Kart ödemesi gerçekten kullanılabilir mi.
     *
     * "Etkin" işareti tek başına yetmez: anahtarlardan biri eksikse akış
     * yarıda kalır ve kullanıcı ödeme ekranında takılır. Eksik yapılandırma
     * sessizce kart kipine geçmemeli.
     */
    public static function isCardReady(): bool
    {
        if (! self::isEnabled() || self::provider() === self::PROVIDER_NONE) {
            return false;
        }

        foreach (self::SECRET_KEYS as $key) {
            if (self::secret($key) === null) {
                return false;
            }
        }

        return true;
    }

    /** Mobil ekranın hangi akışı göstereceği. */
    public static function mode(): string
    {
        return self::isCardReady() ? self::MODE_CARD : self::MODE_TRANSFER;
    }

    public static function secret(string $key): ?string
    {
        $ham = Setting::get($key);
        if ($ham === null || $ham === '') {
            return null;
        }

        try {
            return Crypt::decryptString($ham);
        } catch (DecryptException) {
            // Anahtar APP_KEY değiştikten sonra çözülemez hale gelmiş
            // olabilir. Bozuk bir anahtarla ödeme istemek, kullanıcıyı
            // çalışmayan bir ekrana göndermek demek — yok sayılır.
            return null;
        }
    }

    public static function setSecret(string $key, ?string $value): void
    {
        $temiz = $value === null ? '' : trim($value);
        Setting::set($key, $temiz === '' ? null : Crypt::encryptString($temiz));
    }

    /**
     * Panelde gösterilecek maskeli hâl.
     *
     * Anahtarın kendisi forma geri BASILMAZ; kayıtlı olup olmadığı
     * görünsün yeter. Ekran paylaşımıyla sızmanın en sık yolu budur.
     */
    public static function maskedSecret(string $key): ?string
    {
        $deger = self::secret($key);
        if ($deger === null) {
            return null;
        }

        $son = mb_substr($deger, -4);

        return str_repeat('•', max(4, mb_strlen($deger) - 4)).$son;
    }
}
