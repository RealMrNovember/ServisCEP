<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_requests', function (Blueprint $table) {
            // Müşterinin talep ettiği paket (plan_id) ile admin'in fiilen
            // onayladığı paket ayrı tutulur — müşteri yüksek paket seçip
            // düşük paket bedeli gönderirse, admin burada düzeltip onaylar.
            // plan_id her zaman "talep edilen", approved_plan_id "onaylanan"
            // paketi temsil eder — ikisi de audit amaçlı korunur.
            $table->foreignUuid('approved_plan_id')->nullable()->after('plan_id')
                ->constrained('plans')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('payment_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('approved_plan_id');
        });
    }
};
