<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Karşılığı olmayan ödeme bildirimleri de KAYIT ALTINA alınabilsin.
 *
 * Doğrulanmış bir bildirim geldiğinde bizde ona ait bir kayıt olmayabilir:
 * sağlayıcı panelinden elle üretilmiş bir ödeme bağlantısı, silinmiş bir
 * kayıt ya da uygulamada kart akışı henüz yokken yapılmış bir ödeme.
 *
 * Bu durumlar şimdiye kadar yalnızca günlüğe düşüyordu. Günlükler
 * budanıyor; para hareketi budanmamalı. Yapılmış bir tahsilatın hiçbir
 * koşulda kayıttan düşmemesi gerekiyor — sonradan hangi şirkete ait
 * olduğu belirlenip elle bağlanabilsin diye.
 *
 * Bu yüzden şirket, plan ve süre alanları boş bırakılabilir hale geliyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscription_payments', function (Blueprint $table) {
            $table->uuid('company_id')->nullable()->change();
            $table->string('duration', 10)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('subscription_payments', function (Blueprint $table) {
            $table->uuid('company_id')->nullable(false)->change();
            $table->string('duration', 10)->nullable(false)->change();
        });
    }
};
