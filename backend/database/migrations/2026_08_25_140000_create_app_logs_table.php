<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Merkezî olay günlüğü.
 *
 * Neden dosya logu yetmiyor: bir arıza sırasında `laravel.log`'a ancak
 * sunucuya SSH ile girip bakılabiliyor, mobil taraftaki hatalar ise hiçbir
 * yere ulaşmıyor. Bir cihazda kimlik doğrulama saatlerce çalışmadı ve
 * sebebini görebileceğimiz tek bir kayıt yoktu; istek sunucuya hiç
 * ulaşmadığı için sunucu logu da boştu.
 *
 * Bu tablo üç kaynağı tek yerde toplar:
 *  - `server`  : Laravel'in kendi log kayıtları (Monolog handler üzerinden)
 *  - `request` : API isteklerinin sonucu (yol, durum, süre)
 *  - `mobile`  : Uygulamanın gönderdiği tanılama kayıtları
 *
 * Sorgulanabilir olması şart: seviyeye, şirkete, sürüme, yola göre
 * filtrelenebilmeli. Bu yüzden ilgili kolonlar ayrı alanlarda tutulur,
 * yalnızca serbest ayrıntı `context` JSON'una gider.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // debug / info / warning / error / critical
            $table->string('level', 20)->index();
            $table->string('source', 20)->index();
            $table->string('message');

            // Serbest ayrıntı: istisna sınıfı, yığın izi, Google yanıtı vb.
            $table->json('context')->nullable();

            // Kim / hangi işletme — kullanıcı silinse bile kayıt kalmalı,
            // bu yüzden yabancı anahtar değil düz alan.
            $table->uuid('user_id')->nullable()->index();
            $table->uuid('company_id')->nullable()->index();

            // İstek bilgileri (source = request/server için).
            $table->string('method', 10)->nullable();
            $table->string('path')->nullable()->index();
            $table->unsignedSmallInteger('status')->nullable()->index();
            $table->unsignedInteger('duration_ms')->nullable();

            // İstemci bilgileri — "hangi sürümde patlıyor" sorusu için.
            $table->string('ip', 45)->nullable();
            $table->string('platform', 20)->nullable()->index();
            $table->string('app_version', 30)->nullable()->index();
            $table->string('device', 120)->nullable();

            $table->timestamp('created_at')->index();

            // Panelde varsayılan görünüm "son hatalar" — bu ikili sıralama
            // tam olarak onu karşılar.
            $table->index(['level', 'created_at']);
            $table->index(['source', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_logs');
    }
};
