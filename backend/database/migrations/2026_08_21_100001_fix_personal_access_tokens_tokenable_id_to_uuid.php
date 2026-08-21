<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * personal_access_tokens.tokenable_id, orijinal migration'da varsayılan
 * morphs() ile bigint olarak oluşturulmuştu — ama tokenable (User) UUID
 * primary key kullanıyor. Bu tip uyuşmazlığı PostgreSQL'de hataya yol
 * açar (sıkı tipleme). SQLite bunu gevşek tiplemesiyle gizlediği için
 * yerel testlerde fark edilmedi. Bu migration zaten production'da
 * çalıştırılmış olan orijinal migration'ı DEĞİŞTİRMEK yerine (bu asla
 * yapılmamalı — bkz. docs/11 § AI Destekli Geliştirme Kuralları),
 * kolonu ayrı bir ALTER ile düzeltir.
 *
 * `->change()` yerine drop+recreate kullanılıyor: PostgreSQL, bigint→uuid
 * için örtük bir cast tanımlamadığından `ALTER COLUMN ... TYPE uuid` boş
 * bir tabloda bile USING ifadesi olmadan reddedilir. Tablo şu an (bu
 * migration yazıldığında) production'da 0 satır içeriyor — bu yüzden
 * veri kaybı riski olmadan kolonu düşürüp yeniden oluşturmak, kırılgan
 * bir tip dönüşümünden daha güvenli.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropIndex(['tokenable_type', 'tokenable_id']);
            $table->dropColumn('tokenable_id');
        });

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->uuid('tokenable_id')->after('tokenable_type');
            $table->index(['tokenable_type', 'tokenable_id']);
        });
    }

    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropIndex(['tokenable_type', 'tokenable_id']);
            $table->dropColumn('tokenable_id');
        });

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->unsignedBigInteger('tokenable_id')->after('tokenable_type');
            $table->index(['tokenable_type', 'tokenable_id']);
        });
    }
};
