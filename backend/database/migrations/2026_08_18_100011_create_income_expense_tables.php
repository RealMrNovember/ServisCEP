<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('income_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->timestamp('date')->useCurrent();
            $table->string('description');
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignUuid('job_id')->nullable()->constrained('jobs')->nullOnDelete();
            $table->string('category')->default('Diğer');
            $table->bigInteger('amount_minor');
            $table->string('method')->default('Nakit');
            $table->text('note')->nullable();

            $table->index(['company_id']);
        });

        Schema::create('expense_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->timestamp('date')->useCurrent();
            $table->string('description');
            $table->string('category')->default('Diğer');
            $table->bigInteger('amount_minor');
            $table->string('vendor_name')->nullable();
            $table->string('receipt_photo_path')->nullable();
            $table->string('method')->default('Nakit');
            $table->text('note')->nullable();

            $table->index(['company_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expense_entries');
        Schema::dropIfExists('income_entries');
    }
};
