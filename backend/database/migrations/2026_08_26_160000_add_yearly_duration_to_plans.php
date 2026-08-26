<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Yıllık alımın kaç gün sürdüğü.
 *
 * Şimdiye kadar planda tek bir `duration_days` alanı vardı ama iki satış
 * seçeneği var (aylık / yıllık). Yıllık alımın süresi hiçbir yerde
 * tanımlı değildi ve kod onu tamamen yok sayıp sabit "12 ay" ekliyordu.
 * Panelde 90 gün yazan bir pakete yıllık ödeme yapıldığında ne olacağının
 * cevabı yoktu.
 *
 * Süreyi `duration_days * 12` diye hesaplamak da yanlış olurdu: 30 günlük
 * bir pakette yıllık alım 360 gün ederdi ve müşteri sessizce 5 gün
 * kaybederdi. İki alan ayrı tutuluyor, aritmetik sürpriz yok.
 *
 * Mevcut kayıtlar için varsayılan 365 gün — bugüne kadarki davranış
 * (12 ay eklemek) ile pratikte aynı.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            $table->integer('duration_days_yearly')
                ->nullable()
                ->after('duration_days');
        });

        // Mevcut ücretli paketler için makul varsayılan.
        DB::table('plans')
            ->whereNull('duration_days_yearly')
            ->update(['duration_days_yearly' => 365]);
    }

    public function down(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            $table->dropColumn('duration_days_yearly');
        });
    }
};
