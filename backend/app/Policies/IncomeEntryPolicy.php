<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\IncomeEntry;
use App\Models\User;

class IncomeEntryPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, IncomeEntry $incomeEntry): bool
    {
        return $user->company_id === $incomeEntry->company_id;
    }

    public function create(User $user): bool
    {
        return true;
    }
}
