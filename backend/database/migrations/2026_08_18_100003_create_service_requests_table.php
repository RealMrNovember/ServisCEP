<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_requests', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('code');
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            $table->text('description');
            // YUKSEK / NORMAL / DUSUK
            $table->string('priority')->default('NORMAL');
            $table->text('address')->nullable();
            // BEKLIYOR / ISLEME_ALINDI / REDDEDILDI / ISE_DONUSTU
            $table->string('status')->default('BEKLIYOR');
            $table->uuid('converted_job_id')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_requests');
    }
};
