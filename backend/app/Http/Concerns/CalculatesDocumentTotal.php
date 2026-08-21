<?php

declare(strict_types=1);

namespace App\Http\Concerns;

/**
 * Teklif/Proforma kalemlerinden toplam tutarı hesaplar — KDV kalem
 * bazında uygulanır, iskonto KDV'den önce düşülür. Web panelindeki
 * App\Filament\App\Resources\Concerns\CalculatesDocumentTotal ile
 * AYNI formülü kullanır (bilinçli olarak ayrı dosya — API ve Filament
 * katmanları birbirine bağlanmaz, ama tutarlar tutarlı kalmalı).
 */
trait CalculatesDocumentTotal
{
    private function calculateItemsTotal(array $items): int
    {
        $total = 0;

        foreach ($items as $item) {
            $lineTotal = (float) ($item['quantity'] ?? 0) * (int) ($item['unit_price_minor'] ?? 0);
            $lineTotal = max(0, $lineTotal - (int) ($item['discount_minor'] ?? 0));
            $taxRate = (float) ($item['tax_rate'] ?? 0);
            $total += (int) round($lineTotal * (1 + $taxRate / 100));
        }

        return $total;
    }
}
