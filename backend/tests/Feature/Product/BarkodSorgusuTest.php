<?php

declare(strict_types=1);

namespace Tests\Feature\Product;

use App\Models\BarcodeLookup;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Taranan barkodun açık ürün veritabanlarında aranması.
 *
 * NEDEN VAR: bu sorgu daha önce HİÇ YAZILMAMIŞTI — fonksiyonun gövdesi
 * tek satır `return null;` idi. Yani kendi kataloğunda kayıtlı olmayan
 * hiçbir kod bilgi getirmiyor, form boş açılıyordu ve kullanıcıya sebebi
 * söylenmiyordu.
 *
 * DÜRÜST SINIR — testlerde de kayıtlı: bu veritabanları ağırlıklı olarak
 * market ürünlerini kapsıyor. Güvenlik kamerası gibi ürünlerin kutusunda
 * çoğu zaman perakende barkodu yerine üretici SERİ NUMARASI oluyor ve
 * seriler hiçbir ürün veritabanında yer almıyor. Bulunamamak bir arıza
 * değil; önemli olan bunun sessizce değil açıkça olması.
 */
class BarkodSorgusuTest extends TestCase
{
    use RefreshDatabase;

    private function kullanici(): User
    {
        $user = User::factory()->create();
        User::whereKey($user->id)->update(['role' => RolePermissions::OWNER]);

        return $user->refresh();
    }

    private function girisYap(): void
    {
        $this->withToken($this->kullanici()->createToken('test')->plainTextToken);
    }

    /** @param array<string, mixed> $urun */
    private function bulundu(array $urun): array
    {
        return ['status' => 1, 'product' => $urun];
    }

    public function test_bulunan_urun_bilgisi_doner(): void
    {
        Http::fake([
            'world.openfoodfacts.org/*' => Http::response($this->bulundu([
                'product_name' => 'Çay 1kg',
                'brands' => 'Marka A,Marka B',
                'categories' => 'İçecek,Çay',
            ])),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000001')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.name', 'Çay 1kg')
            // Çoklu alandan yalnızca ilki alınır.
            ->assertJsonPath('data.brand', 'Marka A')
            ->assertJsonPath('data.category', 'İçecek');
    }

    public function test_bulunamayan_kod_hata_degil_bos_sonuc_doner(): void
    {
        // Seri numarası senaryosu: hiçbir veritabanında yok.
        Http::fake(['*' => Http::response(['status' => 0])]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=UNW0101024101227')
            ->assertOk()
            ->assertJsonPath('data.found', false)
            ->assertJsonPath('data.name', null);
    }

    public function test_sonuc_onbelleklenir_ikinci_sorgu_disari_cikmaz(): void
    {
        Http::fake([
            'world.openfoodfacts.org/*' => Http::response($this->bulundu([
                'product_name' => 'Çay 1kg',
            ])),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000001')->assertOk();
        $ilkTur = count(Http::recorded());

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000001')
            ->assertOk()
            ->assertJsonPath('data.name', 'Çay 1kg');

        $this->assertSame(
            $ilkTur,
            count(Http::recorded()),
            'İkinci sorgu yeniden dışarı çıkmış; önbellek çalışmıyor.'
        );
    }

    public function test_bulunamayan_kod_da_onbelleklenir(): void
    {
        // Sahadaki taramaların çoğu bulunamayan kodlar. Önbelleklenmezse
        // her tarama yeniden dışarı çıkar ve ücretsiz servislerin günlük
        // kotası yanar.
        Http::fake(['*' => Http::response(['status' => 0])]);

        $this->girisYap();
        $this->getJson('/api/v1/barcode-lookup?barcode=YOK-123')->assertOk();

        $this->assertDatabaseHas('barcode_lookups', [
            'barcode' => 'YOK-123',
            'found' => false,
        ]);
    }

    public function test_eskimis_onbellek_yeniden_sorulur(): void
    {
        BarcodeLookup::create([
            'barcode' => 'ESKI-1',
            'found' => false,
            'checked_at' => Carbon::now()->subDays(30),
        ]);

        Http::fake([
            'world.openfoodfacts.org/*' => Http::response($this->bulundu([
                'product_name' => 'Sonradan eklenmiş ürün',
            ])),
        ]);

        $this->girisYap();

        // Veritabanlarına sürekli yeni ürün ekleniyor; bugün olmayan
        // yarın olabilir.
        $this->getJson('/api/v1/barcode-lookup?barcode=ESKI-1')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.name', 'Sonradan eklenmiş ürün');
    }

    public function test_saglayici_dustugunde_sorgu_hata_vermez(): void
    {
        // Sorgu bir KOLAYLIK; dış servis düştü diye tarama akışı
        // durmamalı, kullanıcı formu elle doldurabilmeli.
        Http::fake(['*' => fn () => throw new \RuntimeException('ag hatasi')]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000002')
            ->assertOk()
            ->assertJsonPath('data.found', false);
    }

    public function test_adi_olmayan_kayit_bulundu_sayilmaz(): void
    {
        // Adı yoksa forma yazacak bir şey yok; "bulundu" demek
        // kullanıcıyı boş bir formla baş başa bırakmak olurdu.
        Http::fake(['*' => Http::response($this->bulundu(['brands' => 'Marka']))]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000003')
            ->assertOk()
            ->assertJsonPath('data.found', false);
    }

    public function test_elektronik_urun_genel_kaynaktan_bulunur(): void
    {
        // ASIL KULLANIM: bu uygulamanın kullanıcıları elektronik ve
        // teknik malzeme stokluyor (güvenlik kamerası, switch, kablo).
        // Open*Facts GIDA kapsıyor; o ürünler orada hiçbir zaman
        // bulunmaz, bu yüzden genel ticari kaynak ÖNCE denenmeli.
        Http::fake([
            'api.upcitemdb.com/*' => Http::response([
                'items' => [[
                    'title' => 'TP-Link TL-SG108 8 Port Gigabit Switch',
                    'brand' => 'TP-Link',
                    'category' => 'Electronics > Networking > Switches',
                ]],
            ]),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=6935364052669')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.name', 'TP-Link TL-SG108 8 Port Gigabit Switch')
            ->assertJsonPath('data.brand', 'TP-Link')
            ->assertJsonPath('data.source', 'upcitemdb');
    }

    public function test_ucretli_saglayici_anahtarsiz_hic_denenmez(): void
    {
        // Anahtar yokken istek gondermek bosuna gecikme demek.
        config(['services.barcode.barcodelookup_key' => '']);

        Http::fake(['*' => Http::response(['status' => 0])]);

        $this->girisYap();
        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000009')->assertOk();

        foreach (Http::recorded() as [$istek]) {
            $this->assertStringNotContainsString('barcodelookup.com', $istek->url());
        }
    }

    public function test_icecat_elektronikte_once_gelir(): void
    {
        // Bu is kolu icin en isabetli kaynak; anahtar varsa listede
        // UPCitemdb'den ONCE oldugu icin onun cevabi kazanmali.
        config(['services.barcode.icecat_user' => 'test-kullanici']);

        Http::fake([
            'live.icecat.biz/*' => Http::response([
                'data' => ['GeneralInfo' => [
                    'Title' => 'TP-Link TL-SG108 8-Port Gigabit Switch',
                    'Brand' => 'TP-Link',
                    'Category' => ['Name' => ['Value' => 'Ag Anahtari']],
                ]],
            ]),
            'api.upcitemdb.com/*' => Http::response([
                'items' => [['title' => 'Daha kotu bir kayit']],
            ]),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=6935364052669')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.name', 'TP-Link TL-SG108 8-Port Gigabit Switch')
            ->assertJsonPath('data.brand', 'TP-Link')
            ->assertJsonPath('data.source', 'icecat');
    }

    public function test_isbn_disinda_kitap_kaynaklari_sorgulanmaz(): void
    {
        // Sonucu bastan belli bir istek daha eklemek, herkesi bekletir.
        Http::fake(['*' => Http::response(['status' => 0])]);

        $this->girisYap();
        $this->getJson('/api/v1/barcode-lookup?barcode=6935364052669')->assertOk();

        foreach (Http::recorded() as [$istek]) {
            $this->assertStringNotContainsString('googleapis.com/books', $istek->url());
            $this->assertStringNotContainsString('openlibrary.org', $istek->url());
        }
    }

    public function test_isbn_kodunda_kitap_kaynagi_sorgulanir(): void
    {
        Http::fake([
            'googleapis.com/*' => Http::response([
                'items' => [['volumeInfo' => [
                    'title' => 'Clean Code',
                    'authors' => ['Robert C. Martin'],
                    'categories' => ['Computers'],
                ]]],
            ]),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=9780132350884')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.name', 'Clean Code')
            ->assertJsonPath('data.brand', 'Robert C. Martin')
            ->assertJsonPath('data.source', 'googlebooks');
    }

    public function test_bir_kaynak_cokse_digerleri_calismaya_devam_eder(): void
    {
        // Paralel sorguda bir kaynagin erisilemez olmasi digerlerini
        // etkilememeli.
        Http::fake([
            'api.upcitemdb.com/*' => fn () => throw new \RuntimeException('ag hatasi'),
            'world.openfoodfacts.org/*' => Http::response($this->bulundu([
                'product_name' => 'Market urunu',
            ])),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000011')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.source', 'openfoodfacts');
    }

    public function test_ucretli_saglayici_anahtar_varsa_once_denenir(): void
    {
        // Kapsami en iyi olan kaynak once sorulmali.
        config(['services.barcode.barcodelookup_key' => 'test-anahtar']);

        Http::fake([
            'api.barcodelookup.com/*' => Http::response([
                'products' => [[
                    'title' => 'Hikvision DS-2CD1043G0 IP Kamera',
                    'brand' => 'Hikvision',
                    'category' => 'Electronics > Security Cameras',
                ]],
            ]),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=6954273663896')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.brand', 'Hikvision')
            ->assertJsonPath('data.source', 'barcodelookup');
    }

    public function test_gunluk_sinir_dolunca_sonraki_kaynak_kullanilir(): void
    {
        // UPCitemdb anahtarsiz ucta 429 donuyor; bu bir ariza degil.
        // Istekler paralel gittigi icin "sonraki" demek, yanitlar
        // okunurken sirada gelen kaynak demek.
        Http::fake([
            'api.upcitemdb.com/*' => Http::response([], 429),
            'world.openfoodfacts.org/*' => Http::response($this->bulundu([
                'product_name' => 'Market urunu',
            ])),
            '*' => Http::response(['status' => 0]),
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000010')
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.source', 'openfoodfacts');
    }

    public function test_giris_yapmadan_sorgulanamaz(): void
    {
        Http::fake();

        $this->getJson('/api/v1/barcode-lookup?barcode=8690000000001')
            ->assertUnauthorized();
    }

    public function test_barkod_zorunlu(): void
    {
        Http::fake();
        $this->girisYap();

        $this->getJson('/api/v1/barcode-lookup')->assertStatus(422);
    }
}
