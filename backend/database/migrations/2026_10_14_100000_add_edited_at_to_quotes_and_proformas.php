<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Belgenin OLUŞTURULDUKTAN SONRA düzenlendiğini işaretleyen alan.
 *
 * NEDEN AYRI BİR SÜTUN: iki belgede de `$timestamps = false`, yani
 * `updated_at` yok. Olsaydı bile kullanılamazdı — teklifin DURUMU
 * değiştiğinde ("Gönderildi" işaretlemek) de güncellenirdi ve hiç
 * düzenlenmemiş bir teklif listede "Düzenlendi" görünürdü. Rozet ancak
 * doğru olduğu sürece işe yarar.
 *
 * NULL = belge oluşturulduğu gibi duruyor. Mevcut bütün kayıtlar NULL
 * kalıyor: geçmişte panelden düzenlenmiş belgeler olabilir ama bunu
 * bilmiyoruz, bilmediğimiz şeyi biliyormuş gibi göstermiyoruz.
 *
 * Değeri İSTEMCİ gönderir. Uygulama offline düzenleyip günler sonra
 * senkron olabiliyor; sunucunun kendi saatini yazması, düzenlemenin
 * gerçekte ne zaman yapıldığını kaybettirirdi. Gelmezse sunucu saati
 * yedek olarak kullanılır.
 */
return new class extends Migration
{
    public function up(): void
    {
        foreach (['quotes', 'proformas'] as $tablo) {
            Schema::table($tablo, function (Blueprint $table): void {
                $table->timestamp('edited_at')->nullable();
            });
        }
    }

    public function down(): void
    {
        foreach (['quotes', 'proformas'] as $tablo) {
            Schema::table($tablo, function (Blueprint $table): void {
                $table->dropColumn('edited_at');
            });
        }
    }
};
