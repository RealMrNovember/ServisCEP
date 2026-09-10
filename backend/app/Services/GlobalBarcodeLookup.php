<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\BarcodeLookup;
use Illuminate\Http\Client\Pool;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Barkodu açık ve ticari ürün veritabanlarında arar.
 *
 * NEDEN SUNUCUDA: sorgu uygulamadan doğrudan yapılabilirdi ama o zaman
 * her cihaz ayrı ayrı dışarı çıkar, sağlayıcı kotaları cihaz başına
 * yenilenmez, önbellek paylaşılamaz ve sağlayıcı eklemek/değiştirmek
 * uygulama sürümü gerektirirdi. Buradan yapılınca sonuç bir kez bulunur,
 * herkese hizmet eder ve sağlayıcı listesi sürüm çıkmadan değişir.
 *
 * NEDEN PARALEL: sağlayıcı sayısı arttıkça sıralı sorgu kabul edilemez
 * hâle geliyor — on kaynak × beş saniye, en kötü durumda elli saniye
 * eder ve kullanıcı barkodu okutmuş, ekrana bakıyor. İstekler aynı anda
 * gönderiliyor; toplam süre EN YAVAŞ kaynak kadar, toplamları kadar
 * değil. Yanıtlar sonra ÖNCELİK SIRASINA göre okunuyor: kazanan, ilk
 * cevap veren değil, listede önce olan.
 *
 * DÜRÜST SINIR: hiçbir veritabanı her ürünü içermez. Ucuz OEM
 * ürünlerinin kutusunda çoğu zaman perakende barkodu (GTIN) yerine
 * üretici SERİ NUMARASI olur; seriler hiçbir ürün veritabanında yer
 * almaz, çünkü ürünü değil tek bir parçayı tanımlarlar. Bulunamamak bir
 * arıza değil — çağıran taraf bunu kullanıcıya böyle söylemeli.
 */
class GlobalBarcodeLookup
{
    /** Bulunan kayıt bu süre boyunca yeniden sorulmaz. */
    private const BULUNAN_GUN = 180;

    /**
     * Bulunamayan kayıt bu süre boyunca yeniden sorulmaz.
     *
     * Bulunanlardan kısa: veritabanlarına sürekli yeni ürün ekleniyor,
     * bugün olmayan yarın olabilir. Ama her taramada yeniden dışarı
     * çıkmak da sağlayıcı kotalarını yakar.
     */
    private const BULUNAMAYAN_GUN = 14;

    private const ZAMAN_ASIMI = 5;

    private const KIMLIK = 'TeknikCEP/1.2 (info@cicibyte.com)';

    /**
     * @return array{found: bool, name: ?string, brand: ?string, category: ?string, source: ?string}
     */
    public function ara(string $barkod): array
    {
        $barkod = trim($barkod);

        if ($onbellek = $this->onbellekten($barkod)) {
            return $onbellek;
        }

        $sonuc = $this->saglayicilardanAra($barkod);

        BarcodeLookup::updateOrCreate(
            ['barcode' => $barkod],
            $sonuc + ['checked_at' => Carbon::now()],
        );

        return $sonuc;
    }

    /**
     * @return array{found: bool, name: ?string, brand: ?string, category: ?string, source: ?string}|null
     */
    private function onbellekten(string $barkod): ?array
    {
        $satir = BarcodeLookup::find($barkod);
        if (! $satir) {
            return null;
        }

        $gun = $satir->found ? self::BULUNAN_GUN : self::BULUNAMAYAN_GUN;
        if ($satir->checked_at?->addDays($gun)->isPast()) {
            return null;
        }

        return [
            'found' => $satir->found,
            'name' => $satir->name,
            'brand' => $satir->brand,
            'category' => $satir->category,
            'source' => $satir->source,
        ];
    }

    /**
     * @return array{found: bool, name: ?string, brand: ?string, category: ?string, source: ?string}
     */
    private function saglayicilardanAra(string $barkod): array
    {
        $saglayicilar = $this->saglayicilar($barkod);

        if ($saglayicilar === []) {
            return $this->bulunamadi();
        }

        try {
            $yanitlar = Http::pool(function (Pool $havuz) use ($saglayicilar) {
                foreach ($saglayicilar as $ad => $s) {
                    $havuz->as($ad)
                        ->timeout(self::ZAMAN_ASIMI)
                        ->withHeaders($s['headers'] ?? [])
                        ->get($s['url'], $s['query'] ?? []);
                }
            });
        } catch (\Throwable $e) {
            Log::warning('Barkod sorgu havuzu düştü', ['hata' => $e->getMessage()]);

            return $this->bulunamadi();
        }

        // Öncelik sırası: ilk CEVAP VEREN değil, listede ÖNCE olan kazanır.
        foreach ($saglayicilar as $ad => $s) {
            $yanit = $yanitlar[$ad] ?? null;

            // Havuzda düşen istek Response yerine istisna döndürüyor;
            // bir kaynağın erişilemez olması diğerlerini etkilemesin.
            if (! $yanit instanceof Response || ! $yanit->successful()) {
                continue;
            }

            try {
                $urun = ($s['ayikla'])($yanit);
            } catch (\Throwable $e) {
                // Bir sağlayıcının yanıt biçimi değişmiş olabilir;
                // tüm sorgu onun yüzünden düşmesin.
                Log::warning('Barkod yanıtı ayıklanamadı', [
                    'saglayici' => $ad,
                    'hata' => $e->getMessage(),
                ]);

                continue;
            }

            if ($urun !== null) {
                return $urun + ['found' => true, 'source' => $ad];
            }
        }

        return $this->bulunamadi();
    }

    /**
     * Sorgulanacak kaynaklar — ÖNCELİK SIRASIYLA.
     *
     * Sıra kapsam kalitesine göre: bu uygulamanın kullanıcıları
     * elektronik ve teknik malzeme stokluyor (güvenlik kamerası, switch,
     * kablo, konnektör), dolayısıyla genel ticari ürün kaynakları önde.
     * Gıda/kozmetik veritabanları geride ama duruyor — market ürünü de
     * stoklayan olabilir ve orada kapsamları çok daha iyi.
     *
     * Anahtar isteyen kaynaklar, anahtar tanımlı DEĞİLSE listeye hiç
     * girmez: boşuna istek göndermek herkesi bekletmekten başka işe
     * yaramaz.
     *
     * @return array<string, array<string, mixed>>
     */
    private function saglayicilar(string $barkod): array
    {
        $anahtar = fn (string $ad): string => trim((string) config("services.barcode.{$ad}", ''));
        $liste = [];

        // ── Anahtarlı: kapsamı en iyi olanlar önce ────────────────────
        if (($k = $anahtar('barcodelookup_key')) !== '') {
            $liste['barcodelookup'] = [
                'url' => 'https://api.barcodelookup.com/v3/products',
                'query' => ['barcode' => $barkod, 'formatted' => 'y', 'key' => $k],
                'ayikla' => fn (Response $y) => $this->kalemden(
                    $y->json('products.0'), 'title', 'brand', 'category'
                ),
            ];
        }

        if (($k = $anahtar('goupc_key')) !== '') {
            $liste['goupc'] = [
                'url' => 'https://go-upc.com/api/v1/code/'.rawurlencode($barkod),
                'headers' => ['Authorization' => 'Bearer '.$k],
                'ayikla' => fn (Response $y) => $this->kalemden(
                    $y->json('product'), 'name', 'brand', 'category'
                ),
            ];
        }

        // Icecat: BT/elektronik kataloğu — bu iş kolu için en isabetli
        // kaynak. Open Icecat hesabı ÜCRETSİZ, yalnızca kayıt istiyor.
        if (($k = $anahtar('icecat_user')) !== '') {
            $liste['icecat'] = [
                'url' => 'https://live.icecat.biz/api',
                'query' => [
                    'UserName' => $k,
                    'Language' => 'tr',
                    'GTIN' => $barkod,
                    'Content' => 'GeneralInfo',
                ],
                'ayikla' => function (Response $y): ?array {
                    $genel = $y->json('data.GeneralInfo');
                    if (! is_array($genel)) {
                        return null;
                    }

                    $ad = $this->metin($genel['Title'] ?? $genel['ProductName'] ?? null);
                    if ($ad === null) {
                        return null;
                    }

                    return [
                        'name' => $ad,
                        'brand' => $this->metin($genel['Brand'] ?? null),
                        'category' => $this->metin($genel['Category']['Name']['Value'] ?? null),
                    ];
                },
            ];
        }

        if (($k = $anahtar('eansearch_key')) !== '') {
            $liste['eansearch'] = [
                'url' => 'https://api.ean-search.org/api',
                'query' => [
                    'token' => $k,
                    'op' => 'barcode-lookup',
                    'format' => 'json',
                    'ean' => $barkod,
                ],
                'ayikla' => fn (Response $y) => $this->kalemden(
                    $y->json('0'), 'name', null, 'categoryName'
                ),
            ];
        }

        if (($k = $anahtar('upcdatabase_key')) !== '') {
            $liste['upcdatabase'] = [
                'url' => 'https://api.upcdatabase.org/product/'.rawurlencode($barkod),
                'query' => ['apikey' => $k],
                'ayikla' => fn (Response $y) => $y->json('success') === true
                    ? $this->kalemden($y->json(), 'title', 'brand', 'category')
                    : null,
            ];
        }

        // ── Anahtarsız ────────────────────────────────────────────────

        // UPCitemdb: genel ticari ürün, elektronik dâhil. Anahtarsız
        // "trial" ucu günde 100 sorgu (IP başına); anahtar tanımlanırsa
        // ücretli uca geçilir ve sınır kalkar.
        $upc = $anahtar('upcitemdb_key');
        $liste['upcitemdb'] = [
            'url' => $upc === ''
                ? 'https://api.upcitemdb.com/prod/trial/lookup'
                : 'https://api.upcitemdb.com/prod/v1/lookup',
            'query' => ['upc' => $barkod],
            'headers' => $upc === '' ? [] : ['user_key' => $upc, 'key_type' => '3scale'],
            'ayikla' => fn (Response $y) => $this->kalemden(
                $y->json('items.0'), 'title', 'brand', 'category'
            ),
        ];

        // Open*Facts ailesi: açık veri, anahtar istemiyor. Genel ürün
        // kataloğu (openproductsfacts) önce; gıda/kozmetik/pet arkada.
        foreach ([
            'openproductsfacts' => 'world.openproductsfacts.org',
            'openfoodfacts' => 'world.openfoodfacts.org',
            'openbeautyfacts' => 'world.openbeautyfacts.org',
            'openpetfoodfacts' => 'world.openpetfoodfacts.org',
        ] as $ad => $alan) {
            $liste[$ad] = [
                'url' => "https://{$alan}/api/v2/product/".rawurlencode($barkod).'.json',
                'query' => ['fields' => 'product_name,brands,categories'],
                // Open*Facts kimliği olmayan istemcileri kısıtlıyor;
                // kim olduğumuzu söylemek nezaket değil, şart.
                'headers' => ['User-Agent' => self::KIMLIK],
                'ayikla' => function (Response $y): ?array {
                    if ($y->json('status') !== 1) {
                        return null;
                    }

                    return $this->kalemden(
                        $y->json('product'), 'product_name', 'brands', 'categories'
                    );
                },
            ];
        }

        // ── Kitaplar: YALNIZCA ISBN görünümlü kodlarda ────────────────
        //
        // 978/979 ön eki ISBN demek. Diğer kodlarda bu iki kaynağı
        // sorgulamak, sonucu baştan belli bir istek daha eklemek olurdu.
        if (str_starts_with($barkod, '978') || str_starts_with($barkod, '979')) {
            $liste['googlebooks'] = [
                'url' => 'https://www.googleapis.com/books/v1/volumes',
                'query' => ['q' => 'isbn:'.$barkod],
                'ayikla' => function (Response $y): ?array {
                    $bilgi = $y->json('items.0.volumeInfo');
                    if (! is_array($bilgi)) {
                        return null;
                    }

                    $ad = $this->metin($bilgi['title'] ?? null);
                    if ($ad === null) {
                        return null;
                    }

                    return [
                        'name' => $ad,
                        // Kitapta "marka"nın karşılığı yazar.
                        'brand' => $this->metin($bilgi['authors'][0] ?? null),
                        'category' => $this->metin($bilgi['categories'][0] ?? null),
                    ];
                },
            ];

            $liste['openlibrary'] = [
                'url' => 'https://openlibrary.org/api/books',
                'query' => [
                    'bibkeys' => 'ISBN:'.$barkod,
                    'format' => 'json',
                    'jscmd' => 'data',
                ],
                'ayikla' => function (Response $y) use ($barkod): ?array {
                    $kitap = $y->json('ISBN:'.$barkod);
                    if (! is_array($kitap)) {
                        return null;
                    }

                    $ad = $this->metin($kitap['title'] ?? null);
                    if ($ad === null) {
                        return null;
                    }

                    return [
                        'name' => $ad,
                        'brand' => $this->metin($kitap['authors'][0]['name'] ?? null),
                        'category' => $this->metin($kitap['subjects'][0]['name'] ?? null),
                    ];
                },
            ];
        }

        return $liste;
    }

    /**
     * Yanıttaki tek bir kalemden ad/marka/kategori çıkarır.
     *
     * Adı olmayan kayıt işe yaramaz: forma yazacak bir şey yok ve
     * "bulundu" demek kullanıcıyı boş formla baş başa bırakmak olur.
     *
     * @return array{name: string, brand: ?string, category: ?string}|null
     */
    private function kalemden(
        mixed $kalem,
        string $adAnahtari,
        ?string $markaAnahtari,
        ?string $kategoriAnahtari,
    ): ?array {
        if (! is_array($kalem)) {
            return null;
        }

        $ad = $this->metin($kalem[$adAnahtari] ?? null);
        if ($ad === null) {
            return null;
        }

        return [
            'name' => $ad,
            'brand' => $markaAnahtari === null
                ? null
                : $this->ilkDeger($kalem[$markaAnahtari] ?? null),
            'category' => $kategoriAnahtari === null
                ? null
                : $this->ilkDeger($kalem[$kategoriAnahtari] ?? null),
        ];
    }

    /** "Marka1,Marka2" biçimindeki alandan ilkini alır. */
    private function ilkDeger(mixed $ham): ?string
    {
        $metin = $this->metin($ham);

        return $metin === null ? null : $this->metin(explode(',', $metin)[0]);
    }

    private function metin(mixed $ham): ?string
    {
        if (! is_string($ham) && ! is_numeric($ham)) {
            return null;
        }

        $temiz = trim((string) $ham);

        return $temiz === '' ? null : $temiz;
    }

    /**
     * @return array{found: bool, name: null, brand: null, category: null, source: null}
     */
    private function bulunamadi(): array
    {
        return [
            'found' => false,
            'name' => null,
            'brand' => null,
            'category' => null,
            'source' => null,
        ];
    }
}
