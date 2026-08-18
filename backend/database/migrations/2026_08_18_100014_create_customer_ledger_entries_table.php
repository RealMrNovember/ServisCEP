<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Cari hesap hareketleri — bkz. docs/15-cari-hesap.md. Bakiye her
        // zaman SUM(DEBIT)-SUM(CREDIT) olarak türetilir, ayrıca cache'lenmez.
        Schema::create('customer_ledger_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            $table->timestamp('entry_date')->useCurrent();
            // DEBIT (borç) / CREDIT (alacak)
            $table->string('type');
            $table->bigInteger('amount_minor');
            // job / payment / manual_adjustment / opening_balance
            $table->string('reference_type');
            $table->uuid('reference_id')->nullable();
            $table->string('description');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_ledger_entries');
    }
};
