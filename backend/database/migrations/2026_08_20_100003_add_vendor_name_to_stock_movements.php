<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            // Aynı ürün (SKU) birden çok tedarikçiden alınabilir — tedarikçi
            // ürüne değil, her stok girişine (hareketine) bağlıdır.
            $table->string('vendor_name')->nullable()->after('type');
        });
    }

    public function down(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropColumn('vendor_name');
        });
    }
};
