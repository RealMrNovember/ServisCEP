<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Teklif/proforma belgelerinin kurumsal görünümü için gereken alanlar.
 *
 * Belge, işletmenin müşterisine giden yüzüdür: antet için firma iletişim
 * ve vergi bilgileri, karşı taraf için müşteri logosu, fiyatlandırma için
 * para birimi ve KDV kipi gerekiyordu. Bunların hiçbiri veri modelinde
 * yoktu; PDF yalnızca firma adı + IBAN gösterebiliyordu.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            // Belge antedinde görünür.
            $table->string('address')->nullable()->after('iban');
            $table->string('phone', 30)->nullable()->after('address');
            $table->string('email')->nullable()->after('phone');
            // Vergi dairesi + numarası tek alanda (müşteri tarafındaki
            // `tax_info` ile aynı biçim — iki tarafın aynı görünmesi için).
            $table->string('tax_info')->nullable()->after('email');
        });

        Schema::table('customers', function (Blueprint $table) {
            $table->string('logo_path')->nullable()->after('tax_certificate_path');
        });

        foreach (['quotes', 'proformas'] as $documentTable) {
            Schema::table($documentTable, function (Blueprint $table) use ($documentTable) {
                // ISO 4217: TRY / USD / EUR. Tutarlar HER ZAMAN bu para
                // biriminin en küçük biriminde (kuruş/cent) saklanır;
                // burada saklanan yalnızca hangi para birimi olduğudur.
                $table->string('currency', 3)->default('TRY')->after('total_minor');

                // EXCLUDED = "+ KDV" (tutarlara KDV eklenir)
                // INCLUDED = "KDV dahil" (girilen fiyatın içinde)
                $table->string('vat_mode', 10)->default('EXCLUDED')->after('currency');

                // Belge geneli varsayılan KDV oranı; kalemler yine kendi
                // oranını taşır (satır bazında istisna mümkün kalsın).
                $table->unsignedTinyInteger('vat_rate')->default(20)->after('vat_mode');

                if ($documentTable === 'quotes') {
                    // Teklifin geçerlilik tarihi — proformada zaten vardı.
                    $table->date('valid_until')->nullable()->after('vat_rate');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn(['address', 'phone', 'email', 'tax_info']);
        });

        Schema::table('customers', function (Blueprint $table) {
            $table->dropColumn('logo_path');
        });

        Schema::table('quotes', function (Blueprint $table) {
            $table->dropColumn(['currency', 'vat_mode', 'vat_rate', 'valid_until']);
        });

        Schema::table('proformas', function (Blueprint $table) {
            $table->dropColumn(['currency', 'vat_mode', 'vat_rate']);
        });
    }
};
