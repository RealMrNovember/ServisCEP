<?php

declare(strict_types=1);

namespace App\Filament\App\Resources\Concerns;

/**
 * Teklif/Proforma kalemlerinden toplam tutarı hesaplar — KDV kalem
 * bazında uygulanır, iskonto KDV'den önce düşülür. API katmanındaki
 * App\Http\Concerns\CalculatesDocumentTotal ile
 * AYNI formülü kullanır (bilinçli olarak ayrı dosya — API ve Filament
 * katmanları birbirine bağlanmaz, ama tutarlar tutarlı kalmalı).
 */
trait CalculatesDocumentTotal
{
    /**
     * @param  array<int, array<string, mixed>>  $items
     * @param  string  $vatMode  EXCLUDED ("+ KDV") veya INCLUDED ("KDV dahil")
     */
    private function calculateItemsTotal(array $items, string $vatMode = 'EXCLUDED'): int
    {
        // KDV DAHİL belgede kalem fiyatının içinde KDV zaten vardır.
        //
        // Bu parametre olmadan, "KDV dahil" bir teklifin toplamına KDV
        // ikinci kez ekleniyordu: mobil ₺1.200 hesaplıyor, sunucu aynı
        // belgeyi ₺1.440 yapıyor ve senkron sonrası cihazdaki doğru tutarın
        // üzerine yazıyordu. Kullanıcı hiçbir şey yapmadan belge tutarı
        // %20 şişiyordu. Mobil taraf (Money.LineAmounts) bu ayrımı zaten
        // yapıyor; sunucu da aynı kuralı uygulamak zorunda.
        $vatIncluded = $vatMode === 'INCLUDED';

        $total = 0;

        foreach ($items as $item) {
            $lineTotal = (float) ($item['quantity'] ?? 0) * (int) ($item['unit_price_minor'] ?? 0);
            $lineTotal = max(0, $lineTotal - (int) ($item['discount_minor'] ?? 0));

            if ($vatIncluded) {
                $total += (int) round($lineTotal);

                continue;
            }

            $taxRate = (float) ($item['tax_rate'] ?? 0);
            $total += (int) round($lineTotal * (1 + $taxRate / 100));
        }

        return $total;
    }
}
