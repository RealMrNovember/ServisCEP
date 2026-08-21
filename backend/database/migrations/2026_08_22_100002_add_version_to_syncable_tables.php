<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Optimistic concurrency için sürüm sayacı — bkz. ROADMAP.md § B10
 * (Senkronizasyon). Mobil offline'ken yapılan bir güncelleme, sunucuda
 * o sırada (ör. web panelden) değişmiş bir kaydın üzerine SESSİZCE
 * yazamaz: istemci son gördüğü `version`'ı gönderir, sunucudaki
 * `version` değişmişse güncelleme reddedilip bir `sync_conflicts`
 * kaydına düşer (bkz. 2026_08_22_100003_create_sync_conflicts_table).
 *
 * Client saatine değil sunucunun kendi sayacına dayanır — telefonun
 * saati yanlış/kaymış olsa bile çakışma doğru tespit edilir.
 */
return new class extends Migration
{
    private array $tables = ['customers', 'jobs', 'service_requests', 'quotes', 'proformas'];

    public function up(): void
    {
        foreach ($this->tables as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->unsignedInteger('version')->default(1);
            });
        }
    }

    public function down(): void
    {
        foreach ($this->tables as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->dropColumn('version');
            });
        }
    }
};
