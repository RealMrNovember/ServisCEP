<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Denetim kaydı — bkz. docs/09 § 5 Audit Log. Kritik işlemler (belge
 * oluşturma, tahsilat, müşteri değişikliği, cari hesap manuel
 * düzeltmesi vb.) burada immutable olarak tutulur; hiçbir zaman
 * güncellenmez veya silinmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action');
            $table->string('subject_type');
            $table->uuid('subject_id')->nullable();
            $table->string('description');
            $table->json('meta')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'created_at']);
            $table->index(['company_id', 'subject_type', 'subject_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
