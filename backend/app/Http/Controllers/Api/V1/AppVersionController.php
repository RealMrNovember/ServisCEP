<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppLog;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Yayındaki uygulama sürümü.
 *
 * Neden Play'in kendi kontrolü yerine buradan bakılıyor: Play'in In-App
 * Update API'si cihazdaki Google Play Services'e soruyor ve sürüm o cihaza
 * YAYILANA kadar hiçbir şey döndürmüyor. Bu yayılma saatler sürebiliyor;
 * kullanıcı güncelleme çıktığından haberdar olmuyor, biz de "uygulama
 * güncel mi" sorusunu cevaplayamıyoruz. Sunucudan bakmak, sürümü kendi
 * kontrolümüzde tutar ve notu da bizim yazdığımız metinden gösterir.
 *
 * Kurulumun kendisi yine Play üzerinden yapılır — Android'de bir
 * uygulamanın kendini güncellemesinin başka yolu yok. Bu uç yalnızca
 * "yeni sürüm var mı" sorusunu cevaplar.
 *
 * KİMLİK DOĞRULAMASI YOK: sürüm bilgisi gizli değil ve kullanıcı giriş
 * yapamıyorken de (belki de tam o yüzden) güncellemesi gerekebilir.
 */
class AppVersionController extends Controller
{
    /** Ayar anahtarları — panelden düzenlenir (bkz. AppVersionSettings). */
    public const KEY_VERSION = 'app.latest_version';

    public const KEY_BUILD = 'app.latest_build';

    public const KEY_MIN_BUILD = 'app.min_build';

    public const KEY_NOTES = 'app.release_notes';

    public const KEY_STORE_URL = 'app.store_url';

    public const DEFAULT_STORE_URL =
        'https://play.google.com/store/apps/details?id=com.cicibyte.serviscep';

    public function show(): JsonResponse
    {
        $build = (int) Setting::get(self::KEY_BUILD, '0');

        return response()->json([
            'data' => [
                'latest_version' => Setting::get(self::KEY_VERSION),
                'latest_build' => $build,
                // Bu sürümün altındaki kurulumlar için güncelleme ZORUNLU
                // sayılır. Sunucu sözleşmesi kırıldığında (ör. bir alan
                // artık gönderilmiyor) eski istemcileri dışarıda bırakmanın
                // tek yolu bu.
                'min_build' => (int) Setting::get(self::KEY_MIN_BUILD, '0'),
                'notes' => Setting::get(self::KEY_NOTES),
                'store_url' => Setting::get(self::KEY_STORE_URL, self::DEFAULT_STORE_URL),
            ],
        ]);
    }

    /** Yayındaki sürüm adı — panelde "güncel mi" karşılaştırması için. */
    public static function currentVersion(): ?string
    {
        return Setting::get(self::KEY_VERSION);
    }

    /** Yayındaki yapı numarası. Bilinmiyorsa 0. */
    public static function currentBuild(): int
    {
        return (int) Setting::get(self::KEY_BUILD, '0');
    }

    /**
     * Yayındaki sürümü kaydeder — SÜRÜM HATTI tarafından çağrılır.
     *
     * Bu uç, elle yapılan bir adımı ortadan kaldırmak için var. Sürüm
     * bilgisi panelden elle giriliyordu ve bir kez unutuldu: 0.7.5 Play'e
     * çıktı ama sunucu hâlâ "sürüm yok" diyordu, dolayısıyla hiçbir
     * kullanıcıya güncelleme bildirimi gitmedi. Elle kalan her adım
     * er ya da geç unutulur.
     *
     * Kimlik doğrulaması paylaşılan bir jetonla yapılır: çağıran bir
     * kullanıcı değil, CI. Jeton tanımlı değilse uç KAPALIDIR — boş
     * parolayla açık kalmasındansa hiç çalışmaması yeğdir.
     */
    public function publish(Request $request): JsonResponse
    {
        $beklenen = (string) config('services.app_version.publish_token');

        if ($beklenen === '') {
            return response()->json(['message' => 'Uç yapılandırılmamış.'], 503);
        }

        $gelen = (string) $request->bearerToken();

        // hash_equals: zamanlama saldırısına kapalı karşılaştırma.
        if (! hash_equals($beklenen, $gelen)) {
            AppLog::event('Sürüm bildirimi reddedildi', [
                'ip' => $request->ip(),
            ], level: 'warning');

            return response()->json(['message' => 'Yetkisiz.'], 401);
        }

        $data = $request->validate([
            'version' => ['required', 'string', 'max:30'],
            'build' => ['required', 'integer', 'min:1'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        Setting::set(self::KEY_VERSION, $data['version']);
        Setting::set(self::KEY_BUILD, (string) $data['build']);
        if (($data['notes'] ?? null) !== null) {
            Setting::set(self::KEY_NOTES, $data['notes']);
        }

        AppLog::event('Yayındaki sürüm güncellendi', [
            'surum' => $data['version'],
            'yapi' => $data['build'],
        ]);

        return response()->json([
            'data' => [
                'latest_version' => $data['version'],
                'latest_build' => $data['build'],
            ],
        ]);
    }
}
