<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Süper-admin (Cicibyte Teknoloji ekibi) kullanıcıları — tenant
        // "users" tablosundan kasıtlı olarak ayrı: hiçbir company_id'ye
        // bağlı değildir, tüm şirketleri yönetebilir (bkz. Filament /admin
        // paneli). Bu ayrım, tenant kullanıcı modelini kirletmeden ve
        // BelongsToCompany scope mantığını bozmadan süper-admin yetkisini
        // temiz bir şekilde izole eder.
        Schema::create('admin_users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('full_name');
            $table->string('email')->unique();
            $table->string('password');
            $table->rememberToken();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_users');
    }
};
