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
}
