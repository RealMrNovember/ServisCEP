<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Bkz. ROADMAP.md § B10 — bir güncelleme, sunucudaki mevcut sürümle
 * çakıştığında (ör. telefon offline'ken ofis aynı kaydı değiştirmişse)
 * sessizce ezmek yerine burada saklanır; yalnızca OWNER manuel olarak
 * çözer (hangi hali tutacağına karar verir). Kayıtlar immutable'dır —
 * çözüldükten sonra `resolved_at`/`resolution` doldurulur, satır
 * silinmez (audit amaçlı).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_conflicts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('subject_type');
            $table->uuid('subject_id');
            $table->unsignedInteger('base_version');
            $table->unsignedInteger('server_version');
            $table->json('incoming_payload');
            $table->json('server_snapshot');
            // BEKLIYOR / SUNUCU_TUTULDU / MOBIL_TUTULDU
            $table->string('resolution')->default('BEKLIYOR');
            $table->foreignUuid('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['company_id', 'resolution']);
            $table->index(['company_id', 'subject_type', 'subject_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_conflicts');
    }
};
