<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kartla yapılan ABONELİK ödemeleri.
 *
 * Adındaki "subscription" öneki bilinçli: `payments` tablosu ve `Payment`
 * modeli ZATEN VAR ve tamamen başka bir şeydir — kullanıcının kendi
 * müşterisinden aldığı tahsilat, cari hesaba işleyen kayıt. Bu tablo
 * TeknikCEP'e yapılan abonelik ödemesidir.
 *
 * `payment_requests` tablosundan da ayrıdır: orası müşterinin "havale
 * yaptım" BEYANI ve admin onayı, burası sağlayıcı tarafından doğrulanmış
 * gerçek tahsilat. İkisi bir arada yaşayacak — havale kipi, sağlayıcı
 * yapılandırılmadığında hâlâ tek seçenek.
 *
 * Tutar SUNUCUDA, seçilen paketten hesaplanır; istemciden gelen tutara
 * asla güvenilmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subscription_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('plan_id')->nullable()->constrained('plans')->nullOnDelete();
            $table->foreignUuid('requested_by_user_id')->nullable()
                ->constrained('users')->nullOnDelete();

            $table->bigInteger('amount_minor');
            $table->string('currency', 3)->default('TRY');

            /** MONTHLY / YEARLY — ödemenin karşılığı olan süre. */
            $table->string('duration', 10);

            $table->string('provider', 20);

            /**
             * Sağlayıcıdaki sipariş kimliği.
             *
             * BENZERSİZ: ödeme sağlayıcıları bildirimi birden fazla kez
             * gönderebiliyor. Tekillik kısıtı olmadan aynı ödeme iki kez
             * işlenip abonelik iki kat uzayabilir.
             */
            $table->string('provider_ref', 100)->unique();

            /** PENDING / PAID / FAILED */
            $table->string('status', 12)->default('PENDING');

            /** Sağlayıcıdan gelen ham bildirim — anlaşmazlıkta tek kanıt. */
            $table->json('provider_payload')->nullable();

            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['company_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('subscription_payments');
    }
};
