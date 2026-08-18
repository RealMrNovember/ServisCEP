<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('code');
            // Yetkili adı soyadı ve firma adı ayrı alanlardır — ikisinden en
            // az biri dolu olmalıdır (uygulama katmanında doğrulanır), aynı
            // anda ikisini birden girmek zorunlu değildir.
            $table->string('contact_name')->nullable();
            $table->string('company_name')->nullable();
            $table->string('iban')->nullable();
            // BIREYSEL / FIRMA / APARTMAN / SITE / KAMU / DIGER
            $table->string('type')->default('BIREYSEL');
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->text('address')->nullable();
            $table->string('il')->nullable();
            $table->string('ilce')->nullable();
            $table->string('tax_info')->nullable();
            $table->text('notes')->nullable();
            $table->string('tags')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('deleted_at')->nullable();

            $table->index(['company_id', 'deleted_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
