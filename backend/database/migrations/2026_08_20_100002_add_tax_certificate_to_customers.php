<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            // Vergi levhası (PDF/görsel) — private disk'te saklanır, imzalı
            // URL ile erişilir (bkz. docs/09 § Dosya Güvenliği).
            $table->string('tax_certificate_path')->nullable()->after('tax_info');
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->dropColumn('tax_certificate_path');
        });
    }
};
