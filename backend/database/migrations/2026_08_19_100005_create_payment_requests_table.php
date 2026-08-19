<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Müşteri (tenant) elden/havale ile ödeme yaptığında bildirim
        // olarak gönderir; admin onayladığında ilgili şirketin aboneliği
        // otomatik olarak uzatılır (bkz. PaymentRequestObserver /
        // Filament admin panel "Onayla" aksiyonu).
        Schema::create('payment_requests', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('requested_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('plan_id')->nullable()->constrained('plans')->nullOnDelete();
            // Müşterinin beyan ettiği tutar (kuruş) — doğrulama admin'e
            // aittir, otomatik bir ödeme entegrasyonu yoktur (bkz. docs/13).
            $table->bigInteger('claimed_amount_minor')->nullable();
            $table->text('customer_note')->nullable();
            // PENDING / APPROVED / REJECTED
            $table->string('status')->default('PENDING');
            // Admin onayladığında seçtiği süre: MONTHLY / YEARLY
            $table->string('approved_duration')->nullable();
            $table->text('admin_note')->nullable();
            $table->foreignUuid('reviewed_by_admin_id')->nullable()->constrained('admin_users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_requests');
    }
};
