<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            // Taranan barkod (EAN-13/UPC-A vb.) — her ürünün olmak zorunda değil.
            $table->string('barcode')->nullable();
            $table->string('sku')->nullable();
            $table->string('name');
            $table->string('brand')->nullable();
            $table->string('model')->nullable();
            $table->string('category')->nullable();
            $table->string('unit')->default('adet');
            $table->bigInteger('purchase_price_minor')->default(0);
            $table->bigInteger('sale_price_minor')->default(0);
            $table->integer('current_stock')->default(0);
            $table->integer('min_stock')->default(0);
            // MANUAL / GLOBAL_LOOKUP — ürün nasıl oluşturuldu (izlenebilirlik).
            $table->string('source')->default('MANUAL');
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('deleted_at')->nullable();

            $table->index(['company_id', 'deleted_at']);
            $table->index(['company_id', 'barcode']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
