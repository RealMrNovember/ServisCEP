<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\AdminUser;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Yeni bir süper-admin hesabı açar. Şifre rastgele üretilir ve HİÇBİR
 * yerde gösterilmez — admin, paneldeki "Şifremi unuttum" akışıyla
 * (bkz. AdminPanelProvider ->passwordReset()) kendi şifresini belirler.
 * Böylece şifre ne terminal geçmişinde ne log'da iz bırakır.
 */
class CreateAdminUser extends Command
{
    protected $signature = 'admin:create {email} {full_name}';

    protected $description = 'Süper-admin hesabı oluşturur (şifre e-postadaki sıfırlama akışıyla belirlenir)';

    public function handle(): int
    {
        $email = strtolower(trim((string) $this->argument('email')));
        $fullName = trim((string) $this->argument('full_name'));

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("Geçersiz e-posta adresi: {$email}");

            return self::FAILURE;
        }

        if (AdminUser::query()->where('email', $email)->exists()) {
            $this->error("Bu e-postayla bir admin zaten var: {$email}");

            return self::FAILURE;
        }

        AdminUser::query()->create([
            'full_name' => $fullName,
            'email' => $email,
            'password' => Hash::make(Str::password(48)),
        ]);

        $this->info("Admin oluşturuldu: {$email}");
        $this->line('Giriş için: /admin → "Şifremi unuttum" → e-postadaki bağlantıyla şifre belirleyin.');

        return self::SUCCESS;
    }
}
