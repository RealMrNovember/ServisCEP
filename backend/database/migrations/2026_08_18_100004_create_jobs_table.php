<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Not: "jobs" burada domain servis/iş kaydını temsil eder; Laravel'in
        // kuyruk tablosu bilinçli olarak "queue_jobs" adına taşınmıştır
        // (bkz. 0001_01_01_000002_create_queue_jobs_table.php).
        Schema::create('jobs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('code');
            $table->foreignUuid('customer_id')->constrained('customers')->restrictOnDelete();
            $table->uuid('job_type_id')->nullable();
            $table->string('title');
            $table->text('description')->nullable();
            $table->text('address')->nullable();
            $table->timestamp('appointment_date')->nullable();
            $table->string('start_time')->nullable();
            $table->string('end_time')->nullable();
            // YUKSEK / NORMAL / DUSUK
            $table->string('priority')->default('NORMAL');
            // TALEP / PLANLANDI / DEVAM_EDIYOR / BEKLEMEDE / TAMAMLANDI / IPTAL
            $table->string('status')->default('TALEP');
            $table->uuid('technician_user_id')->nullable();
            $table->bigInteger('estimated_price_minor')->nullable();
            $table->bigInteger('actual_price_minor')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('deleted_at')->nullable();

            $table->index(['company_id', 'deleted_at']);
            $table->index(['company_id', 'appointment_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jobs');
    }
};
