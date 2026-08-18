<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quotes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('code');
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            // TASLAK / GONDERILDI / BEKLEMEDE / KABUL_EDILDI / REDDEDILDI / SURESI_DOLDU
            $table->string('status')->default('TASLAK');
            $table->text('notes')->nullable();
            $table->bigInteger('total_minor')->default(0);
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id']);
        });

        Schema::create('quote_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('quote_id')->constrained('quotes')->cascadeOnDelete();
            $table->string('description');
            $table->integer('quantity')->default(1);
            $table->string('unit')->default('adet');
            $table->bigInteger('unit_price_minor')->default(0);
            $table->integer('tax_rate')->default(20);
            $table->bigInteger('discount_minor')->default(0);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quote_items');
        Schema::dropIfExists('quotes');
    }
};
