<?php

declare(strict_types=1);

namespace Tests\Feature\Panel;

use App\Models\Quote;
use App\Support\DocumentTotal;
use Tests\TestCase;

/**
 * "KDV dahil" bir belgenin panelden düzenlenmesi.
 *
 * NEDEN VAR: panel sayfaları toplamı
 * `DocumentTotal::forItems($items, $data['vat_mode'] ?? 'EXCLUDED')`
 * ile hesaplıyordu ve form `vat_mode` alanını hiç göndermediği için
 * HER ZAMAN 'EXCLUDED'a düşüyordu. Sonuç: KDV dahil bir teklifi açıp
 * tek bir notu değiştirip kaydetmek toplama KDV'yi ikinci kez ekliyor,
 * ₺1.200'lük belge ₺1.440 oluyor ve belge hâlâ "KDV dahil" görünüyordu.
 * Kullanıcı fiyata hiç dokunmuyor.
 *
 * Aynı hata daha önce mobil/sunucu arasında yaşanmıştı; DocumentTotal
 * docblock'unda anlatılıyor. Bu sefer paneldeydi.
 */
class BelgeKdvKipiTest extends TestCase
{
    /** @return array<int, array<string, mixed>> */
    private function kalemler(): array
    {
        return [[
            'quantity' => 1,
            'unit_price_minor' => 120000, // ₺1.200
            'tax_rate' => 20,
        ]];
    }

    public function test_kdv_dahil_belgede_toplam_sismez(): void
    {
        $this->assertSame(
            120000,
            DocumentTotal::forItems($this->kalemler(), 'INCLUDED'),
            'KDV dahil belgede fiyatın içinde KDV zaten var; üstüne eklenmemeli.'
        );
    }

    public function test_kdv_haric_belgede_kdv_eklenir(): void
    {
        $this->assertSame(
            144000,
            DocumentTotal::forItems($this->kalemler(), 'EXCLUDED'),
        );
    }

    public function test_panel_sayfalari_kdv_kipini_kayittan_okur(): void
    {
        // Asıl regresyon bekçisi: sabit 'EXCLUDED' geri gelirse yakalanır.
        foreach ([
            app_path('Filament/App/Resources/Quotes/Pages/EditQuote.php'),
            app_path('Filament/App/Resources/Proformas/Pages/EditProforma.php'),
        ] as $dosya) {
            $icerik = file_get_contents($dosya);

            $this->assertStringNotContainsString(
                "\$data['vat_mode'] ?? 'EXCLUDED'",
                $icerik,
                basename($dosya).' KDV kipini sabit EXCLUDED\'a düşürüyor; '
                .'kayıttan okumalı ($record->vat_mode).'
            );
            $this->assertStringContainsString('$record->vat_mode', $icerik);
        }
    }

    public function test_panel_formu_kdv_kipini_yonetebiliyor(): void
    {
        // Alan formda yoksa kullanıcı KDV kipini panelden hiç
        // değiştiremiyor demektir; hata da bu yüzden görünmez kalmıştı.
        foreach ([
            app_path('Filament/App/Resources/Quotes/Schemas/QuoteForm.php'),
            app_path('Filament/App/Resources/Proformas/Schemas/ProformaForm.php'),
        ] as $dosya) {
            $this->assertStringContainsString(
                'vat_mode',
                file_get_contents($dosya),
                basename($dosya).' KDV kipi alanını içermiyor.'
            );
        }
    }

    public function test_quote_modeli_vat_mode_yazilabilir(): void
    {
        $this->assertContains('vat_mode', (new Quote)->getFillable());
    }
}
