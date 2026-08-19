<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Platform genelinde tekil ayarlar (key-value) — ör. ödeme IBAN
        // bilgisi. Admin panelden yönetilir (bkz. Filament "Ödeme Ayarları"
        // sayfası). Değerler kasıtlı olarak koda/seed'e yazılmaz, yalnızca
        // veritabanında tutulur.
        Schema::create('settings', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->text('value')->nullable();
            $table->timestamp('updated_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
    }
};
