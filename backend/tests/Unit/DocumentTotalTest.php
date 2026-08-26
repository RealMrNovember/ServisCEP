<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Support\DocumentTotal;
use PHPUnit\Framework\TestCase;

/**
 * Belge toplamı — tek kaynak.
 *
 * Bu hesap daha önce API ve Filament altında iki ayrı dosyada duruyor,
 * elle eşit tutuluyordu. Proje aynı hatayı abonelik süresinde bir kez
 * yaşadı. Buradaki testler formülü kilitliyor.
 */
class DocumentTotalTest extends TestCase
{
    public function test_adds_vat_on_top_when_the_price_excludes_it(): void
    {
        $toplam = DocumentTotal::forItems([
            ['quantity' => 1, 'unit_price_minor' => 100_000, 'tax_rate' => 20],
        ], 'EXCLUDED');

        $this->assertSame(120_000, $toplam);
    }

    /**
     * "KDV dahil" belgede KDV ikinci kez eklenmez.
     *
     * Bu tam olarak yaşanan hataydı: mobil ₺1.000 hesaplıyor, sunucu aynı
     * belgeyi ₺1.200 yapıp senkron sırasında cihazdaki doğru tutarın
     * üzerine yazıyordu.
     */
    public function test_does_not_add_vat_again_when_the_price_already_includes_it(): void
    {
        $toplam = DocumentTotal::forItems([
            ['quantity' => 1, 'unit_price_minor' => 100_000, 'tax_rate' => 20],
        ], 'INCLUDED');

        $this->assertSame(100_000, $toplam);
    }

    public function test_subtracts_the_discount_before_vat(): void
    {
        // (2 × 50.000) − 20.000 = 80.000 → + %20 KDV = 96.000
        $toplam = DocumentTotal::forItems([
            [
                'quantity' => 2,
                'unit_price_minor' => 50_000,
                'tax_rate' => 20,
                'discount_minor' => 20_000,
            ],
        ], 'EXCLUDED');

        $this->assertSame(96_000, $toplam);
    }

    /**
     * Yüzde iskonto hesaba GİRER.
     *
     * `discount_rate` sunucuda kabul edilip saklanıyor ama toplama hiç
     * yansımıyordu. Bugün gönderen istemci olmadığı için görünür bir hata
     * yoktu; mobil tarafı yazan kişi sunucunun bunu hesapladığını varsayar
     * ve tutar sessizce yanlış çıkardı.
     */
    public function test_applies_a_percentage_discount(): void
    {
        // 100.000 − %10 = 90.000 → + %20 KDV = 108.000
        $toplam = DocumentTotal::forItems([
            [
                'quantity' => 1,
                'unit_price_minor' => 100_000,
                'tax_rate' => 20,
                'discount_rate' => 10,
            ],
        ], 'EXCLUDED');

        $this->assertSame(108_000, $toplam);
    }

    public function test_percentage_discount_wins_over_the_amount_when_both_arrive(): void
    {
        // Arayüzde tek seçici var; ikisi birden gelirse yüzde kazanır
        // çünkü yüzde ancak bilinçli seçilerek girilir.
        $toplam = DocumentTotal::forItems([
            [
                'quantity' => 1,
                'unit_price_minor' => 100_000,
                'tax_rate' => 0,
                'discount_rate' => 10,
                'discount_minor' => 90_000,
            ],
        ], 'EXCLUDED');

        $this->assertSame(90_000, $toplam);
    }

    /**
     * İskonto tutarı kalemi aşarsa toplam sıfırlanır, eksiye düşmez.
     * Eksi bir kalem, belgenin geri kalanından para düşerdi.
     */
    public function test_a_discount_larger_than_the_line_never_goes_negative(): void
    {
        $toplam = DocumentTotal::forItems([
            [
                'quantity' => 1,
                'unit_price_minor' => 10_000,
                'tax_rate' => 20,
                'discount_minor' => 99_000,
            ],
        ], 'EXCLUDED');

        $this->assertSame(0, $toplam);
    }

    public function test_an_empty_document_totals_zero(): void
    {
        $this->assertSame(0, DocumentTotal::forItems([], 'EXCLUDED'));
    }
}
