<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\ExpenseEntry;
use App\Models\User;
use App\Support\RolePermissions;

class ExpenseEntryPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::FINANCE_VIEW);
    }

    public function view(User $user, ExpenseEntry $expenseEntry): bool
    {
        return $user->company_id === $expenseEntry->company_id
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

    public function update(User $user, ExpenseEntry $expenseEntry): bool
    {
        return $user->company_id === $expenseEntry->company_id
            && $user->hasPermission(RolePermissions::FINANCE_MANAGE);
    }

    public function delete(User $user, ExpenseEntry $expenseEntry): bool
    {
        return $this->update($user, $expenseEntry);
    }

    public function restore(User $user, ExpenseEntry $expenseEntry): bool
    {
        return $this->update($user, $expenseEntry);
    }

    public function forceDelete(User $user, ExpenseEntry $expenseEntry): bool
    {
        return false;
    }
}
