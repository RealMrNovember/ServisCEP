<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\AdminUser;
use App\Models\Company;
use App\Models\DeviceToken;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Bir kullanıcıyı şirketler arasında taşır — süper-admin müdahalesi.
 *
 * Gerçek senaryo: kişi kendi başına kayıt olup kendi şirketini oluşturur
 * ("yanlışlıkla üye oldum"), sonra çalıştığı firma onu ekibe eklemek
 * ister. E-posta global olarak benzersiz olduğu için firma sahibi onu
 * personel olarak EKLEYEMEZ; hesabın taşınması gerekir.
 *
 * Kullanıcıya ait veriler (müşteri, iş, belge) ESKİ şirkette kalır —
 * bunlar kullanıcının değil, şirketin verisidir. Taşınan yalnızca
 * kullanıcı hesabıdır.
 */
class UserTransferService
{
    /**
     * @param  bool  $deleteEmptyOrigin  Kaynak şirket taşımadan sonra
     *                                   kullanıcısız kalırsa silinsin mi?
     *                                   Yalnızca hiç verisi yoksa silinir.
     */
    public function transfer(
        User $user,
        string $targetCompanyId,
        string $role,
        AdminUser $admin,
        bool $deleteEmptyOrigin = false,
    ): User {
        $origin = $user->company;

        if ($origin->id === $targetCompanyId) {
            throw ValidationException::withMessages([
                'company_id' => ['Kullanıcı zaten bu şirkette.'],
            ]);
        }

        if (! in_array($role, RolePermissions::ALL, true)) {
            throw ValidationException::withMessages(['role' => ['Geçersiz rol.']]);
        }

        // Kaynak şirket sahipsiz kalmamalı — BAŞKA kullanıcıları varken
        // son sahibi taşımak o şirketi yönetilemez hâle getirir.
        $isLastOwner = $user->role === RolePermissions::OWNER
            && User::where('company_id', $origin->id)
                ->where('role', RolePermissions::OWNER)
                ->count() <= 1;
        $originHasOthers = User::where('company_id', $origin->id)
            ->where('id', '!=', $user->id)
            ->exists();

        if ($isLastOwner && $originHasOthers) {
            throw ValidationException::withMessages([
                'user' => ['Bu kişi şirketinin tek sahibi ve şirkette başka kullanıcılar var. Önce başka birini sahip yapmalısın.'],
            ]);
        }

        return DB::transaction(function () use ($user, $origin, $targetCompanyId, $role, $admin, $deleteEmptyOrigin) {
            $user->update(['company_id' => $targetCompanyId, 'role' => $role]);

            // Oturumlar ve push kayıtları iptal edilir: kullanıcı artık
            // başka bir şirketin verisine bakacak, eski oturumla devam
            // etmesi yanlış şirketin verisini göstermesine yol açardı.
            $user->tokens()->delete();
            DeviceToken::where('user_id', $user->id)->delete();

            $target = Company::findOrFail($targetCompanyId);

            app(SubscriptionService::class)->recordAdminAudit(
                $target,
                $admin,
                'user.transferred',
                sprintf('%s (%s) "%s" şirketinden taşındı, rol: %s', $user->full_name, $user->email, $origin->name, $role),
                ['user_id' => $user->id, 'from_company_id' => $origin->id],
            );

            if ($deleteEmptyOrigin && $this->isDisposable($origin)) {
                $origin->delete();
            }

            return $user->refresh();
        });
    }

    /**
     * Kaynak şirket güvenle silinebilir mi? Yalnızca kullanıcısı KALMAMIŞ
     * ve hiç iş verisi ÜRETİLMEMİŞ şirketler silinir — "yanlışlıkla açılmış
     * boş kayıt" durumu. Gerçek verisi olan bir şirket asla otomatik
     * silinmez.
     */
    public function isDisposable(Company $company): bool
    {
        if (User::where('company_id', $company->id)->exists()) {
            return false;
        }

        // Company modelinde yalnızca `customers` ilişkisi tanımlı; diğer
        // tablolar company_id ile doğrudan sorgulanır. İlişki eklenmesini
        // beklemek yerine burada açıkça kontrol ediliyor ki yeni bir tablo
        // unutulduğunda "veri var" tarafına düşülsün (güvenli varsayılan).
        if ($company->customers()->withTrashed()->exists()) {
            return false;
        }

        foreach (['jobs', 'quotes', 'proformas', 'payments', 'income_entries', 'expense_entries'] as $table) {
            if (DB::table($table)->where('company_id', $company->id)->exists()) {
                return false;
            }
        }

        return true;
    }
}
