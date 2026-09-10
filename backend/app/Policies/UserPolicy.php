<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\AdminUser;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Contracts\Auth\Authenticatable;

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
    /**
     * DİKKAT — tip ipucu `User` DEĞİL, `Authenticatable`.
     *
     * Bu politika İKİ ayrı guard tarafından çağrılıyor: `/panel`'de
     * işletme kullanıcısı (`User`), `/admin`'de bizim yönetici hesabımız
     * (`AdminUser`). Metotlar `User` ile daraltıldığında `/admin`'deki
     * kullanıcı listesi TypeError ile çöküyordu — yönetim paneli
     * tamamen açılmaz hâle geliyordu. CI'da yakalandı; canlıya gitseydi
     * paneli kapatırdı.
     */
    public function viewAny(Authenticatable $user): bool
    {
        // Yönetici paneli listeyi SALT OKUNUR gösterir.
        if ($user instanceof AdminUser) {
            return true;
        }

        return $user instanceof User
            && $user->hasPermission(RolePermissions::PERSONNEL_MANAGE);
    }

    public function view(Authenticatable $user, User $personel): bool
    {
        if ($user instanceof AdminUser) {
            return true;
        }

        return $this->yonetebilir($user, $personel);
    }

    public function create(Authenticatable $user): bool
    {
        // Yönetici, işletmenin personelini onun adına OLUŞTURMAZ.
        return $user instanceof User
            && $user->hasPermission(RolePermissions::PERSONNEL_MANAGE);
    }

    public function update(Authenticatable $user, User $personel): bool
    {
        return $this->yonetebilir($user, $personel);
    }

    public function delete(Authenticatable $user, User $personel): bool
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

    public function restore(Authenticatable $user, User $personel): bool
    {
        return $this->yonetebilir($user, $personel);
    }

    public function forceDelete(Authenticatable $user, User $personel): bool
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
    public function changeRole(Authenticatable $user, User $personel): bool
    {
        if (! $this->yonetebilir($user, $personel)) {
            return false;
        }

        if ($user->id === $personel->id) {
            return false;
        }

        return ! $this->sonSahip($personel);
    }

    private function yonetebilir(Authenticatable $user, User $personel): bool
    {
        // Yönetici (AdminUser) buradan GEÇEMEZ: şirketin personelini
        // düzenlemek ya da silmek onun işi değil.
        return $user instanceof User
            && $user->company_id !== null
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
