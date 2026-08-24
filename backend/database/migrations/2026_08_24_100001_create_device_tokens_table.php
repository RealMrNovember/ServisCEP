<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Push bildirimi (FCM) cihaz kayıtları — bkz. docs/06 § Push Notification.
 *
 * Bir kullanıcının birden fazla cihazı olabilir; aynı token başka bir
 * kullanıcıya geçebilir (cihaz el değiştirir / farklı hesapla giriş
 * yapılır), bu yüzden token globaldir (unique) ve sahibi güncellenir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('token')->unique();
            $table->string('platform')->default('android');
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('last_seen_at')->nullable();

            $table->index(['company_id']);
            $table->index(['user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
