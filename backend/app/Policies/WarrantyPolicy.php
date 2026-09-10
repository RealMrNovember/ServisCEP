<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\User;
use App\Models\Warranty;
use App\Support\RolePermissions;

/**
 * Garanti kayıtları yetkisi.
 *
 * NEDEN VAR: politika yokken Filament varsayılan olarak izin veriyordu;
 * her rol garanti kaydı oluşturup silebiliyordu.
 *
 * Yetki seçimi: garanti bir işin çıktısı ve sahada teknisyenin
 * sorguladığı şey. Bu yüzden iş yetkileriyle aynı kapıdan geçiyor.
 */
class WarrantyPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function view(User $user, Warranty $warranty): bool
    {
        return $user->company_id === $warranty->company_id
            && $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    public function update(User $user, Warranty $warranty): bool
    {
        return $user->company_id === $warranty->company_id
            && $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    public function delete(User $user, Warranty $warranty): bool
    {
        return $this->update($user, $warranty);
    }

    public function restore(User $user, Warranty $warranty): bool
    {
        return $this->update($user, $warranty);
    }

    public function forceDelete(User $user, Warranty $warranty): bool
    {
        return false;
    }
}
