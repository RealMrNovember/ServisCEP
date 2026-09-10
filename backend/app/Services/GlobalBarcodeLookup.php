<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\BarcodeLookup;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Barkodu açık ürün veritabanlarında arar.
 *
 * NEDEN SUNUCUDA: sorgu uygulamadan doğrudan yapılabilirdi ama o zaman
 * her cihaz ayrı ayrı dışarı çıkar, sağlayıcı sınırları cihaz başına
 * yenilenmez, önbellek paylaşılamaz ve sağlayıcı değiştirmek uygulama
 * sürümü gerektirirdi. Buradan yapılınca sonuç bir kez bulunur, herkese
 * hizmet eder ve sağlayıcı listesi sürüm çıkmadan değiştirilebilir.
 *
 * DÜRÜST SINIR: bu veritabanları ağırlıklı olarak market ürünlerini
 * kapsıyor. Elektrik malzemesi, güvenlik kamerası gibi ürünler çoğu
 * zaman BULUNAMAZ; kutularında perakende barkodu yerine üretici seri
 * numarası olur ve seri numaraları hiçbir ürün veritabanında yer almaz.
 * Bulunamaması bir arıza değil, kapsamın sınırı — çağıran taraf bunu
 * kullanıcıya böyle söylemeli.
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
     * çıkmak da sağlayıcı sınırını yakar.
     */
    private const BULUNAMAYAN_GUN = 14;

    private const ZAMAN_ASIMI = 4;

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
        // SIRA ÖNEMLİ.
        //
        // Bu uygulamanın kullanıcıları elektronik ve teknik malzeme
        // stokluyor: güvenlik kamerası, switch, kablo, konnektör.
        // Open*Facts ailesi GIDA ve kozmetik kapsıyor — o ürünler orada
        // hiçbir zaman bulunmaz. Bu yüzden genel ticari ürün kapsayan
        // kaynaklar ÖNCE deneniyor; gıda veritabanları geride, çünkü
        // market ürünü de stoklayan olabilir ve orada kapsamları daha
        // iyi.
        $saglayicilar = [
            'barcodelookup' => fn () => $this->barcodeLookupSorgula($barkod),
            'upcitemdb' => fn () => $this->upcItemDbSorgula($barkod),
            'openfoodfacts' => fn () => $this->openFactsSorgula(
                'https://world.openfoodfacts.org/api/v2/product/'.rawurlencode($barkod).'.json'
            ),
            'openproductsfacts' => fn () => $this->openFactsSorgula(
                'https://world.openproductsfacts.org/api/v2/product/'.rawurlencode($barkod).'.json'
            ),
            'openbeautyfacts' => fn () => $this->openFactsSorgula(
                'https://world.openbeautyfacts.org/api/v2/product/'.rawurlencode($barkod).'.json'
            ),
        ];

        foreach ($saglayicilar as $ad => $sorgula) {
            $urun = $sorgula();

            if ($urun !== null) {
                return $urun + ['found' => true, 'source' => $ad];
            }
        }

        return [
            'found' => false,
            'name' => null,
            'brand' => null,
            'category' => null,
            'source' => null,
        ];
    }

    /**
     * UPCitemdb — genel ticari ürün (elektronik dâhil).
     *
     * Anahtarsız "trial" ucu günde 100 sorgu (IP başına) veriyor.
     * Önbellek sayesinde her BENZERSİZ barkod bir kez sayılıyor.
     *
     * @return array{name: string, brand: ?string, category: ?string}|null
     */
    private function upcItemDbSorgula(string $barkod): ?array
    {
        $anahtar = (string) config('services.barcode.upcitemdb_key');

        $url = $anahtar === ''
            ? 'https://api.upcitemdb.com/prod/trial/lookup'
            : 'https://api.upcitemdb.com/prod/v1/lookup';

        try {
            $istek = Http::timeout(self::ZAMAN_ASIMI);
            if ($anahtar !== '') {
                $istek = $istek->withHeaders([
                    'user_key' => $anahtar,
                    'key_type' => '3scale',
                ]);
            }

            $yanit = $istek->get($url, ['upc' => $barkod]);
        } catch (\Throwable $e) {
            Log::warning('upcitemdb sorgusu düştü', ['hata' => $e->getMessage()]);

            return null;
        }

        // 429 = günlük sınır doldu. Hata değil; sıradaki sağlayıcı denenir.
        if (! $yanit->successful()) {
            return null;
        }

        $kalem = $yanit->json('items.0');
        if (! is_array($kalem)) {
            return null;
        }

        $ad = trim((string) ($kalem['title'] ?? ''));
        if ($ad === '') {
            return null;
        }

        return [
            'name' => $ad,
            'brand' => $this->bosDegilse($kalem['brand'] ?? null),
            'category' => $this->ilkDeger($kalem['category'] ?? null),
        ];
    }

    /**
     * Barcode Lookup — elektronikte kapsamı belirgin biçimde daha iyi.
     *
     * ÜCRETLİ: anahtar tanımlı değilse HİÇ denenmez, boşuna istek
     * gönderilmez.
     *
     * @return array{name: string, brand: ?string, category: ?string}|null
     */
    private function barcodeLookupSorgula(string $barkod): ?array
    {
        $anahtar = (string) config('services.barcode.barcodelookup_key');
        if ($anahtar === '') {
            return null;
        }

        try {
            $yanit = Http::timeout(self::ZAMAN_ASIMI)
                ->get('https://api.barcodelookup.com/v3/products', [
                    'barcode' => $barkod,
                    'formatted' => 'y',
                    'key' => $anahtar,
                ]);
        } catch (\Throwable $e) {
            Log::warning('barcodelookup sorgusu düştü', ['hata' => $e->getMessage()]);

            return null;
        }

        if (! $yanit->successful()) {
            return null;
        }

        $urun = $yanit->json('products.0');
        if (! is_array($urun)) {
            return null;
        }

        $ad = trim((string) ($urun['title'] ?? ''));
        if ($ad === '') {
            return null;
        }

        return [
            'name' => $ad,
            'brand' => $this->bosDegilse($urun['brand'] ?? null),
            'category' => $this->ilkDeger($urun['category'] ?? null),
        ];
    }

    private function bosDegilse(?string $ham): ?string
    {
        $temiz = trim((string) $ham);

        return $temiz === '' ? null : $temiz;
    }

    /**
     * @return array{name: string, brand: ?string, category: ?string}|null
     */
    private function openFactsSorgula(string $url): ?array
    {
        try {
            $yanit = Http::timeout(self::ZAMAN_ASIMI)
                // Open*Facts kimliği olmayan istemcileri kısıtlıyor;
                // kim olduğumuzu söylemek nezaket değil, şart.
                ->withHeaders(['User-Agent' => 'TeknikCEP/1.1 (info@cicibyte.com)'])
                ->get($url, ['fields' => 'product_name,brands,categories']);
        } catch (\Throwable $e) {
            // Ağ hatası bir sonraki sağlayıcıyı denemeyi engellemesin;
            // sorgunun tamamı da kullanıcıya hata olarak dönmesin.
            Log::warning('Barkod sorgusu düştü', ['url' => $url, 'hata' => $e->getMessage()]);

            return null;
        }

        if (! $yanit->successful()) {
            return null;
        }

        $govde = $yanit->json();
        // status 1 = bulundu. Bazı sürümler 200 dönüp status 0 veriyor.
        if (($govde['status'] ?? 0) !== 1) {
            return null;
        }

        $urun = $govde['product'] ?? [];
        $ad = trim((string) ($urun['product_name'] ?? ''));

        // Adı olmayan kayıt işe yaramaz: forma yazacak bir şey yok.
        if ($ad === '') {
            return null;
        }

        return [
            'name' => $ad,
            'brand' => $this->ilkDeger($urun['brands'] ?? null),
            'category' => $this->ilkDeger($urun['categories'] ?? null),
        ];
    }

    /** "Marka1,Marka2" biçimindeki alandan ilkini alır. */
    private function ilkDeger(?string $ham): ?string
    {
        if ($ham === null) {
            return null;
        }

        $ilk = trim(explode(',', $ham)[0]);

        return $ilk === '' ? null : $ilk;
    }
}
