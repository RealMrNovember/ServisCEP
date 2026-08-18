<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            $table->foreignUuid('job_id')->nullable()->constrained('jobs')->nullOnDelete();
            $table->bigInteger('amount_minor');
            $table->string('method')->default('Nakit');
            $table->timestamp('date')->useCurrent();
            $table->text('note')->nullable();

            $table->index(['company_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
