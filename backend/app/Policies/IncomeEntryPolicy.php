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
}
