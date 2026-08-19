<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_requests', function (Blueprint $table) {
            // Müşterinin ödeme talebinde belirttiği süre niyeti (aylık/yıllık)
            // — approved_duration'dan ayrıdır, admin onayda farklı bir süre
            // seçebilir, ama müşterinin ne istediğini görebilmesi gerekir.
            $table->string('requested_duration')->nullable()->after('claimed_amount_minor');
        });
    }

    public function down(): void
    {
        Schema::table('payment_requests', function (Blueprint $table) {
            $table->dropColumn('requested_duration');
        });
    }
};
