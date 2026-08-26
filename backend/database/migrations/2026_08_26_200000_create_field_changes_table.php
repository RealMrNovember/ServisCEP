<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Alan bazında değişiklik izi — senkron çakışmalarını OTOMATİK çözebilmek
 * için.
 *
 * Sorun: telefon çevrimdışıyken ofis aynı kaydı değiştirirse sürüm
 * uyuşmuyor ve güncelleme çakışma kaydına düşüyor, birinin elle karar
 * vermesi gerekiyordu. Oysa çakışmaların çoğu gerçek çakışma DEĞİL: ofis
 * telefonu, saha görevlisi notu değiştirmişse kimse kimsenin işini
 * ezmiyor — ikisi de uygulanabilir.
 *
 * Bunu anlayabilmek için sunucunun "ben hangi alanları değiştirdim"
 * sorusunu sürüm bazında cevaplayabilmesi gerekiyor. Kaydın kendisi
 * yalnızca SON hâli tutuyor; denetim kaydı (audit_logs) ise alan bazında
 * eski/yeni değer tutmuyor ve yalnızca kritik işlemleri kapsıyor.
 *
 * Burada her sürüm için yalnızca DEĞİŞEN ALAN ADLARI tutuluyor, değerler
 * değil. Birleştirme kararı için ad yeterli; değer saklamak bu tabloyu
 * kaydın ikinci bir kopyasına çevirirdi.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('field_changes', function (Blueprint $table) {
            $table->id();
            $table->string('subject_type');
            $table->uuid('subject_id');
            // Bu değişikliğin SONUCUNDA oluşan sürüm.
            $table->unsignedInteger('version');
            $table->json('fields');
            $table->timestamp('created_at')->useCurrent();

            // Çakışma çözümünde tek bir sorgu var: "şu kayıt için
            // base_version ile mevcut sürüm arasında hangi alanlar
            // değişti". İndeks tam olarak onu karşılıyor.
            $table->index(['subject_type', 'subject_id', 'version']);

            // Budama bu sütuna bakıyor.
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('field_changes');
    }
};
