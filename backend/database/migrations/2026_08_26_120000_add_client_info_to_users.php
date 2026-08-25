<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kullanıcının en son hangi istemciyle bağlandığı.
 *
 * Destek tarafı "hangi sürümü kullanıyorsunuz" sorusunu kullanıcıya
 * sormadan cevaplayabilsin diye. Bir sorun bildirildiğinde ilk bakılacak
 * şey, kullanıcının eski bir sürümde kalıp kalmadığı.
 *
 * Bu bilgi app_logs tablosunda da tutuluyor ama oraya güvenilemez: günlük
 * kayıtları düzenli olarak budanıyor (bkz. PruneAppLogs), dolayısıyla bir
 * süre sonra sessiz kalan bir kullanıcının sürümü kaybediliyor. Burada
 * son durum kalıcı olarak duruyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('app_version', 30)->nullable()->after('remember_token');
            $table->unsignedInteger('app_build')->nullable()->after('app_version');
            $table->string('client_platform', 20)->nullable()->after('app_build');
            $table->string('device_info', 120)->nullable()->after('client_platform');
            $table->timestamp('last_seen_at')->nullable()->after('device_info');

            // Panelde "eski sürümde kalanlar" filtresi bu sütun üzerinden
            // çalışacak; tarama yerine indeks kullanılsın.
            $table->index('app_build');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['app_build']);
            $table->dropColumn([
                'app_version',
                'app_build',
                'client_platform',
                'device_info',
                'last_seen_at',
            ]);
        });
    }
};
