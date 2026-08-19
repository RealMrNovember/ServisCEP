<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->uuid('plan_id')->nullable()->after('id');
            $table->timestamp('subscription_expires_at')->nullable()->after('plan_id');
            // Admin panelden manuel olarak da askıya alınabilir — süre
            // dolmamış olsa bile is_active=false ise erişim engellenir.
            $table->boolean('is_active')->default(true)->after('subscription_expires_at');
            $table->text('admin_note')->nullable()->after('is_active');

            $table->foreign('plan_id')->references('id')->on('plans')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropForeign(['plan_id']);
            $table->dropColumn(['plan_id', 'subscription_expires_at', 'is_active', 'admin_note']);
        });
    }
};
