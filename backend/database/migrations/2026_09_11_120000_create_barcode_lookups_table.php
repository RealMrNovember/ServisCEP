<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Küresel barkod sorgusu ÖNBELLEĞİ.
 *
 * NEDEN: sorgu dış servislere gidiyor. Önbelleksiz her tarama yeniden
 * dışarı çıkardı — yavaş, ücretsiz servislerin günlük sınırını yakar ve
 * servis düştüğünde daha önce bulunmuş ürün de bulunamaz hâle gelirdi.
 *
 * BULUNAMAYAN kodlar da yazılıyor (`found = false`). Sahadaki gerçek
 * kullanım büyük ölçüde bulunamayan kodlardan oluşuyor (seri numaraları,
 * yerel tedarikçi etiketleri); bunları önbelleklemezsek aynı kod her
 * okutulduğunda tekrar dışarı çıkılır.
 *
 * Şirkete AİT DEĞİL: barkod evrensel, "1 numaralı şirketin bulduğu ürün"
 * diye bir şey yok. Kiracı verisi değil, ortak bir sözlük.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('barcode_lookups', function (Blueprint $table): void {
            $table->string('barcode', 64)->primary();
            $table->boolean('found')->default(false);
            $table->string('name')->nullable();
            $table->string('brand')->nullable();
            $table->string('category')->nullable();
            // Hangi kaynaktan geldi — bir sağlayıcı kötü veri döndürürse
            // hangi kayıtların temizleneceği bilinsin.
            $table->string('source', 40)->nullable();
            $table->timestamp('checked_at')->useCurrent();

            $table->index('checked_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('barcode_lookups');
    }
};
