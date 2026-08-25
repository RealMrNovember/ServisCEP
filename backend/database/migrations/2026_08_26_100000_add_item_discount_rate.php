<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Belge kalemlerinde iskontonun YÜZDE olarak girilebilmesi.
 *
 * Şimdiye kadar yalnızca `discount_minor` (hesaplanmış tutar) tutuluyordu.
 * Kullanıcı "%10 iskonto" demek istediğinde tutar hesaplanıp saklanıyor,
 * fakat oranın kendisi kayboluyordu. Bunun iki somut sonucu vardı:
 *
 *  1. Belge yeniden açıldığında kullanıcı "%10" değil "200" görüyordu.
 *  2. Miktar veya birim fiyat sonradan değişince iskonto SABİT kalıyor,
 *     yüzde artık tutmuyordu — sessizce yanlış belge üretiyordu.
 *
 * `discount_rate` null ise iskonto tutar olarak girilmiştir; dolu ise
 * yüzde olarak girilmiştir ve `discount_minor` ondan türetilmiştir.
 * İkisi birlikte saklanır: tutar hesabın kaynağı olmaya devam eder,
 * oran ise kullanıcı niyetini korur.
 */
return new class extends Migration
{
    private const TABLES = ['quote_items', 'proforma_items'];

    public function up(): void
    {
        foreach (self::TABLES as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->unsignedTinyInteger('discount_rate')
                    ->nullable()
                    ->after('discount_minor');
            });
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->dropColumn('discount_rate');
            });
        }
    }
};
