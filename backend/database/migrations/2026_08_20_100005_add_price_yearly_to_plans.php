<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            // price_minor aylık fiyatı temsil eder; yıllık ayrı ve indirimli
            // fiyatlandırılabilir (bkz. ROADMAP.md fiyatlandırma tablosu).
            $table->bigInteger('price_yearly_minor')->default(0)->after('price_minor');
        });
    }

    public function down(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            $table->dropColumn('price_yearly_minor');
        });
    }
};
