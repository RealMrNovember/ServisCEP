<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;

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
}
