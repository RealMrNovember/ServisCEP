<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Quote;
use App\Models\User;
use App\Support\RolePermissions;

class QuotePolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function view(User $user, Quote $quote): bool
    {
        return $user->company_id === $quote->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function update(User $user, Quote $quote): bool
    {
        return $user->company_id === $quote->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }
}
