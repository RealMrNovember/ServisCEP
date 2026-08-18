<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_photos', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('job_id')->constrained('jobs')->cascadeOnDelete();
            // ONCESI / ARIZA / MONTAJ / SONRASI / MALZEME / DIGER
            $table->string('category')->default('DIGER');
            // private/company/{company_id}/... altında saklanan göreli yol
            // (bkz. docs/09 § Dosya Güvenliği) — doğrudan public erişim yok.
            $table->string('file_path');
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_photos');
    }
};
