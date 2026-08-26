<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Teklif/Proforma kalemlerinden toplam tutar.
 *
 * TEK KAYNAK. Bu hesap daha önce iki ayrı dosyada duruyordu (API ve
 * Filament) ve "katmanlar birbirine bağlanmasın" gerekçesiyle elle eşit
 * tutuluyordu. Bu proje aynı hatayı abonelik süresinde bir kez yaşadı:
 * iki yerde yazılan hesap birbirinden saptı. Toplam tutar bir katman
 * meselesi değil, bir iş kuralı — bir tane olmalı.
 *
 * Mobil taraftaki karşılığı LineAmounts.compute (lib/core/utils/money.dart).
 * İkisi AYNI sonucu vermek zorunda: sunucu senkron sırasında cihazdaki
 * tutarın üzerine yazıyor, yani sapma sessizce kullanıcının belgesini
 * bozar.
 */
final class DocumentTotal
{
    private function __construct() {}

    /**
     * @param  array<int, array<string, mixed>>  $items
     * @param  string  $vatMode  EXCLUDED ("+ KDV") veya INCLUDED ("KDV dahil")
     */
    public static function forItems(array $items, string $vatMode = 'EXCLUDED'): int
    {
        // KDV DAHİL belgede kalem fiyatının içinde KDV zaten vardır.
        //
        // Bu ayrım olmadan "KDV dahil" bir teklifin toplamına KDV ikinci
        // kez ekleniyordu: mobil ₺1.200 hesaplıyor, sunucu aynı belgeyi
        // ₺1.440 yapıyor ve senkron sonrası cihazdaki doğru tutarın üzerine
        // yazıyordu. Kullanıcı hiçbir şey yapmadan belge tutarı %20
        // şişiyordu.
        $kdvDahil = $vatMode === 'INCLUDED';

        $toplam = 0;

        foreach ($items as $item) {
            $satir = (float) ($item['quantity'] ?? 0) * (int) ($item['unit_price_minor'] ?? 0);
            $satir = max(0.0, $satir - self::indirim($item, $satir));

            if ($kdvDahil) {
                $toplam += (int) round($satir);

                continue;
            }

            $kdvOrani = (float) ($item['tax_rate'] ?? 0);
            $toplam += (int) round($satir * (1 + $kdvOrani / 100));
        }

        return $toplam;
    }

    /**
     * Kalem iskontosu — yüzde ya da tutar, ikisi birden değil.
     *
     * Arayüzde tek bir seçici var (₺ / $ / € / %), yani kullanıcı ikisini
     * aynı anda giremiyor. Yine de ikisi birden gelirse yüzde kazanır:
     * yüzde ancak bilinçli seçilerek girilebilir, tutar alanı ise eski bir
     * kayıttan taşınmış olabilir.
     *
     * `discount_rate` sunucuda kabul edilip SAKLANIYOR ama hesaba
     * girmiyordu. Bugün hiçbir istemci göndermediği için görünür bir hata
     * yoktu; mobil tarafı yazan kişi sunucunun bunu hesapladığını varsayar
     * ve tutar sessizce yanlış çıkardı.
     *
     * @param  array<string, mixed>  $item
     */
    private static function indirim(array $item, float $satirTutari): float
    {
        $oran = (int) ($item['discount_rate'] ?? 0);

        if ($oran > 0) {
            return round($satirTutari * min($oran, 100) / 100);
        }

        return (float) (int) ($item['discount_minor'] ?? 0);
    }
}
