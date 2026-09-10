<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\User;
use App\Support\RolePermissions;

/**
 * Personel yönetimi yetkisi.
 *
 * NEDEN VAR: `/panel`'deki PersonnelResource'un modeli `User` ve bu
 * politika yokken Filament, policy bulunamadığında VARSAYILAN OLARAK
 * İZİN VERİYORDU. Sonuç, şirket içinde tam yetki yükseltmesiydi:
 * TECHNICIAN rolündeki bir personel `/panel/personel/create` ile kendine
 * OWNER hesabı açabiliyor, işletme sahibinin kaydını düzenleyip
 * PAROLASINI DEĞİŞTİREBİLİYOR ve son sahibi silip şirketi sahipsiz
 * bırakabiliyordu. Aynı kurallar API tarafında (PersonnelController)
 * baştan beri vardı; eksik olan yalnızca panel tarafıydı.
 *
 * Kurallar burada TEK yerde: PersonnelController ile aynı davranış.
 */
class UserPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::PERSONNEL_MANAGE);
    }

    public function view(User $user, User $personel): bool
    {
        return $this->yonetebilir($user, $personel);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::PERSONNEL_MANAGE);
    }

    public function update(User $user, User $personel): bool
    {
        return $this->yonetebilir($user, $personel);
    }

    public function delete(User $user, User $personel): bool
    {
        if (! $this->yonetebilir($user, $personel)) {
            return false;
        }

        // Kendini silme — PersonnelController::destroy ile aynı kural.
        if ($user->id === $personel->id) {
            return false;
        }

        // Son işletme sahibi silinemez: şirket sahipsiz kalırsa kimse
        // personel yönetemez ve hesap kurtarılamaz hâle gelir.
        return ! $this->sonSahip($personel);
    }

    public function restore(User $user, User $personel): bool
    {
        return $this->yonetebilir($user, $personel);
    }

    public function forceDelete(User $user, User $personel): bool
    {
        return false;
    }

    /**
     * Rol değiştirme, silmeden ayrı ele alınır.
     *
     * PersonnelController::update iki şeyi engelliyor: kişinin kendi
     * rolünü değiştirmesi (yetki yükseltmenin en kısa yolu) ve son
     * sahibin rolünün düşürülmesi.
     */
    public function changeRole(User $user, User $personel): bool
    {
        if (! $this->yonetebilir($user, $personel)) {
            return false;
        }

        if ($user->id === $personel->id) {
            return false;
        }

        return ! $this->sonSahip($personel);
    }

    private function yonetebilir(User $user, User $personel): bool
    {
        return $user->company_id !== null
            && $user->company_id === $personel->company_id
            && $user->hasPermission(RolePermissions::PERSONNEL_MANAGE);
    }

    private function sonSahip(User $personel): bool
    {
        if ($personel->role !== RolePermissions::OWNER) {
            return false;
        }

        return User::query()
            ->where('company_id', $personel->company_id)
            ->where('role', RolePermissions::OWNER)
            ->count() <= 1;
    }
}
