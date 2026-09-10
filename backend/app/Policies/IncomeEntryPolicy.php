<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\IncomeEntry;
use App\Models\User;
use App\Support\RolePermissions;

class IncomeEntryPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::FINANCE_VIEW);
    }

    public function view(User $user, IncomeEntry $incomeEntry): bool
    {
        return $user->company_id === $incomeEntry->company_id
            && $user->hasPermission(RolePermissions::FINANCE_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::FINANCE_MANAGE);
    }

    // NEDEN SONRADAN EKLENDI: bu metotlar yokken Filament policy
    // bulamayip VARSAYILAN OLARAK IZIN VERIYORDU. Menude gizli olsa da
    // TECHNICIAN dogrudan /panel/income-entries/{id}/edit adresine
    // giderek sirketin finansal kaydini okuyup degistirebiliyordu —
    // oysa rol matrisinin ilk kurali "teknisyen finansal veriyi
    // GOREMEZ" (bkz. RolePermissions docblock).

    public function update(User $user, IncomeEntry $incomeEntry): bool
    {
        return $user->company_id === $incomeEntry->company_id
            && $user->hasPermission(RolePermissions::FINANCE_MANAGE);
    }

    public function delete(User $user, IncomeEntry $incomeEntry): bool
    {
        return $this->update($user, $incomeEntry);
    }

    public function restore(User $user, IncomeEntry $incomeEntry): bool
    {
        return $this->update($user, $incomeEntry);
    }

    public function forceDelete(User $user, IncomeEntry $incomeEntry): bool
    {
        return false;
    }
}
