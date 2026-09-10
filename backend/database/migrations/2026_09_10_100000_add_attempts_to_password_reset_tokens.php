<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Parola sıfırlama kodu için deneme sayacı.
 *
 * NEDEN: kod 6 haneli ve yanlış girildiğinde satır olduğu gibi kalıyordu.
 * 15 dakikalık pencere boyunca aynı e-posta için sınırsız deneme
 * yapılabiliyordu; tek engel IP başına hız sınırıydı ve o da tek başına
 * yeterli bir savunma değil (birden fazla IP, pencereyi bekleyip yeniden
 * deneme). Kodu bulan, parolayı değiştirip tüm oturumları kapatabiliyor —
 * yani doğrudan hesap devri.
 *
 * Sayaç e-posta başına: saldırganın IP'si değişse de deneme hakkı bitiyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('password_reset_tokens', function (Blueprint $table): void {
            $table->unsignedSmallInteger('attempts')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('password_reset_tokens', function (Blueprint $table): void {
            $table->dropColumn('attempts');
        });
    }
};
