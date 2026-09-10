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
        // Open*Facts ailesi: ücretsiz, anahtar istemiyor, açık veri.
        // Sıra kapsam genişliğine göre — gıda en büyük veri kümesi.
        $kaynaklar = [
            'openfoodfacts' => 'https://world.openfoodfacts.org/api/v2/product/',
            'openproductsfacts' => 'https://world.openproductsfacts.org/api/v2/product/',
            'openbeautyfacts' => 'https://world.openbeautyfacts.org/api/v2/product/',
        ];

        foreach ($kaynaklar as $ad => $taban) {
            $urun = $this->openFactsSorgula($taban.rawurlencode($barkod).'.json');

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
