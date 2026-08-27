<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kullanıcı geri bildirimleri.
 *
 * NEDEN AppLog DEĞİL: uygulamanın zaten bir tanılama kanalı var
 * (`app_logs`, SOURCE_MOBILE) ama o KAYIT tutuyor — budanıyor, durumu
 * yok, cevabı yok. Geri bildirim bunların üçünü de gerektiriyor:
 * kullanıcı bir şey soruyor ve cevap bekliyor. Günlüğe yazılan bir soru
 * cevapsız kalır ve bir süre sonra silinir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feedbacks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            // Kullanıcı silinse bile geri bildirim KALIR: içindeki bilgi
            // kullanıcıya değil ürüne ait.
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();

            // ONERI / HATA / SORU / DIGER
            $table->string('type')->default('DIGER');
            $table->text('message');

            // YENI / INCELENIYOR / YANITLANDI / KAPANDI
            $table->string('status')->default('YENI');

            // Yöneticinin cevabı. Kullanıcıya GÖSTERİLİR — panelde kalan
            // bir cevap, cevap değildir.
            $table->text('reply')->nullable();
            $table->timestamp('replied_at')->nullable();

            // İstemci künyesi: "hangi sürümde oldu" sorusunu sormadan
            // cevaplayabilmek için (bkz. ClientHeaders).
            $table->string('app_version')->nullable();
            $table->string('platform')->nullable();
            $table->string('device')->nullable();

            $table->timestamps();

            // Panelde varsayılan görünüm: bekleyenler önce, yeniden eskiye.
            $table->index(['status', 'created_at']);
            $table->index(['company_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feedbacks');
    }
};
