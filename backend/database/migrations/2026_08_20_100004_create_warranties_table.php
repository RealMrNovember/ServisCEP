<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Müşteriye monte edilen ürünler için garanti takibi — bkz.
        // ROADMAP.md § Ek Gereksinimler.
        Schema::create('warranties', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->foreignUuid('job_id')->nullable()->constrained('jobs')->nullOnDelete();
            $table->string('item_description');
            $table->string('serial_number')->nullable();
            $table->date('install_date');
            $table->unsignedInteger('warranty_months')->default(12);
            $table->date('warranty_expires_at');
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'warranty_expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warranties');
    }
};
