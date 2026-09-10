<?php

declare(strict_types=1);

namespace Tests\Feature\Product;

use App\Models\Product;
use App\Models\ProductBarcode;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Bir ürüne birden fazla barkod bağlama.
 *
 * NEDEN VAR: `products.barcode` tek kod tutuyordu ve bu, sahadaki en
 * yaygın durumu karşılamıyordu. Güvenlik kamerası gibi ürünlerin
 * kutusunda perakende barkodu (EAN) yerine SERİ NUMARASI oluyor; seri
 * her kutuda farklı. Kullanıcı ilk kamerayı elle tanımlasa bile aynı
 * modelin ikinci kutusu başka bir kod okutuyor ve hiçbir zaman
 * eşleşmiyordu — müşteri "barkod çalışmıyor" diye bildirdi.
 */
class EkBarkodTest extends TestCase
{
    use RefreshDatabase;

    private function sahip(): User
    {
        $user = User::factory()->create();
        User::whereKey($user->id)->update(['role' => RolePermissions::OWNER]);

        return $user->refresh();
    }

    private function urun(User $user, string $ad = 'Kamera'): Product
    {
        return Product::create([
            'id' => (string) Str::uuid(),
            'company_id' => $user->company_id,
            'name' => $ad,
        ]);
    }

    public function test_urune_ek_barkod_baglanabilir(): void
    {
        $user = $this->sahip();
        $urun = $this->urun($user);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $urun->id,
            'barcode' => 'UNW0101024101227',
        ])->assertCreated();

        $this->assertDatabaseHas('product_barcodes', [
            'product_id' => $urun->id,
            'barcode' => 'UNW0101024101227',
        ]);
    }

    public function test_ayni_urune_birden_fazla_kod_baglanir(): void
    {
        // Asıl senaryo: aynı modelden gelen her kutunun serisi farklı.
        $user = $this->sahip();
        $urun = $this->urun($user);
        $this->withToken($user->createToken('test')->plainTextToken);

        foreach (['UNW0101024101227', 'UNW0101024101228', 'UNW0101024101229'] as $kod) {
            $this->postJson('/api/v1/product-barcodes', [
                'product_id' => $urun->id,
                'barcode' => $kod,
            ])->assertCreated();
        }

        $this->assertSame(3, ProductBarcode::where('product_id', $urun->id)->count());
    }

    public function test_ayni_kod_iki_urune_baglanamaz(): void
    {
        // Bağlanabilseydi tarama hangi ürünü açacağını bilemezdi.
        $user = $this->sahip();
        $birinci = $this->urun($user, 'Kamera A');
        $ikinci = $this->urun($user, 'Kamera B');
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $birinci->id,
            'barcode' => 'AYNI-KOD',
        ])->assertCreated();

        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $ikinci->id,
            'barcode' => 'AYNI-KOD',
        ])->assertStatus(422);
    }

    public function test_baska_sirketin_urunune_baglanamaz(): void
    {
        $user = $this->sahip();
        $yabanci = $this->sahip();
        $yabanciUrun = $this->urun($yabanci);

        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $yabanciUrun->id,
            'barcode' => 'KOD-1',
        ])->assertStatus(422);
    }

    public function test_ayni_kod_farkli_sirketlerde_kullanilabilir(): void
    {
        // Benzersizlik ŞİRKET içinde: iki ayrı işletme aynı ürünü
        // stoklayabilir.
        $birinci = $this->sahip();
        $ikinci = $this->sahip();

        $this->withToken($birinci->createToken('t1')->plainTextToken);
        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $this->urun($birinci)->id,
            'barcode' => 'ORTAK-KOD',
        ])->assertCreated();

        // Kanit: fabrikanin her kullaniciya ayri sirket urettigi ve
        // urunun gercekten o sirkete yazildigi. Bu iki sey dogruysa
        // kalan tek degisken dogrulama kuralinin kapsami olur.
        $this->assertNotSame($birinci->company_id, $ikinci->company_id);

        $ikinciUrun = $this->urun($ikinci);
        $this->assertDatabaseHas('products', [
            'id' => $ikinciUrun->id,
            'company_id' => $ikinci->company_id,
        ]);

        $this->withToken($ikinci->createToken('t2')->plainTextToken);
        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $ikinciUrun->id,
            'barcode' => 'ORTAK-KOD',
        ])->assertCreated();
    }

    public function test_teknisyen_barkod_baglayamaz(): void
    {
        $sahip = $this->sahip();
        $urun = $this->urun($sahip);

        $teknisyen = User::factory()->create();
        User::whereKey($teknisyen->id)->update([
            'role' => RolePermissions::TECHNICIAN,
            'company_id' => $sahip->company_id,
        ]);

        $this->withToken($teknisyen->refresh()->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/product-barcodes', [
            'product_id' => $urun->id,
            'barcode' => 'KOD-2',
        ])->assertStatus(403);
    }

    public function test_yeniden_gonderim_mukerrer_satir_yazmaz(): void
    {
        $user = $this->sahip();
        $urun = $this->urun($user);
        $this->withToken($user->createToken('test')->plainTextToken);

        $id = (string) Str::uuid();
        $govde = ['id' => $id, 'product_id' => $urun->id, 'barcode' => 'TEKRAR-KOD'];

        $this->postJson('/api/v1/product-barcodes', $govde)->assertCreated();
        $this->postJson('/api/v1/product-barcodes', $govde)->assertOk();

        $this->assertSame(1, ProductBarcode::where('barcode', 'TEKRAR-KOD')->count());
    }

    public function test_baglanan_kod_silinebilir(): void
    {
        $user = $this->sahip();
        $urun = $this->urun($user);
        $this->withToken($user->createToken('test')->plainTextToken);

        $kayit = ProductBarcode::create([
            'id' => (string) Str::uuid(),
            'company_id' => $user->company_id,
            'product_id' => $urun->id,
            'barcode' => 'SILINECEK',
        ]);

        $this->deleteJson("/api/v1/product-barcodes/{$kayit->id}")->assertNoContent();
        $this->assertDatabaseMissing('product_barcodes', ['id' => $kayit->id]);
    }

    public function test_urun_silinince_kodlari_da_gider(): void
    {
        // Aksi hâlde kod "bağlı" görünür ama ürünü yoktur.
        $user = $this->sahip();
        $urun = $this->urun($user);

        ProductBarcode::create([
            'id' => (string) Str::uuid(),
            'company_id' => $user->company_id,
            'product_id' => $urun->id,
            'barcode' => 'KALINTI',
        ]);

        $urun->forceDelete();

        $this->assertDatabaseMissing('product_barcodes', ['barcode' => 'KALINTI']);
    }
}
