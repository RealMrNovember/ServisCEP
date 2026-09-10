<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Bir ürüne bağlanan EK barkodlar.
 *
 * NEDEN: `products.barcode` tek bir kod tutuyor ve bu, sahadaki en yaygın
 * durumu karşılamıyor. Güvenlik kamerası gibi ürünlerin kutusunda
 * perakende barkodu (EAN) yerine SERİ NUMARASI oluyor; seri her kutuda
 * farklı. Kullanıcı ilk kamerayı elle tanımlasa bile aynı modelin ikinci
 * kutusu başka bir kod okutuyor ve hiçbir zaman eşleşmiyordu.
 *
 * Bu tabloyla aynı ürüne istenildiği kadar kod bağlanabiliyor: kurulumcu
 * yeni kutuyu okutup "mevcut ürüne ekle" diyor, stok doğru düşüyor.
 *
 * Kod ŞİRKET içinde benzersiz: aynı barkod iki ayrı ürüne bağlanamaz,
 * yoksa tarama hangi ürünü açacağını bilemez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_barcodes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->string('barcode', 64);
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['company_id', 'barcode']);
            $table->index(['company_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_barcodes');
    }
};
