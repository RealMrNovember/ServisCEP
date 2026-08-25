<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Teklif/proforma belgelerindeki metin alanları: giriş yazısı ve şartlar.
 *
 * Bu alanlar hem şirket düzeyinde (her belgede tekrar yazılmasın diye
 * varsayılan) hem belge düzeyinde (o teklife özel değiştirilebilsin diye)
 * tutulur. Şirket varsayılanı belge oluşturulurken kopyalanır; sonradan
 * şirket ayarı değişse bile geçmiş belgeler değişmez — müşteriye gönderilmiş
 * bir teklifin şartlarının sonradan kendiliğinden değişmesi kabul edilemez.
 */
return new class extends Migration
{
    /** Belge metinleri — hem companies hem quotes/proformas için aynı set. */
    private const TEXT_COLUMNS = [
        'payment_terms',
        'delivery_time',
        'warranty_terms',
    ];

    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->text('intro_text')->nullable()->after('tax_info');

            foreach (self::TEXT_COLUMNS as $column) {
                $table->string($column)->nullable()->after('intro_text');
            }
        });

        foreach (['quotes', 'proformas'] as $documentTable) {
            Schema::table($documentTable, function (Blueprint $table) {
                $table->text('intro_text')->nullable()->after('notes');

                foreach (self::TEXT_COLUMNS as $column) {
                    $table->string($column)->nullable()->after('intro_text');
                }
            });
        }
    }

    public function down(): void
    {
        $columns = array_merge(['intro_text'], self::TEXT_COLUMNS);

        foreach (['companies', 'quotes', 'proformas'] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) use ($columns) {
                $table->dropColumn($columns);
            });
        }
    }
};
