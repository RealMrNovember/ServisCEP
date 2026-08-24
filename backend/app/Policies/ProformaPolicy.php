<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Proforma;
use App\Models\User;
use App\Support\RolePermissions;

class ProformaPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function view(User $user, Proforma $proforma): bool
    {
        return $user->company_id === $proforma->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function update(User $user, Proforma $proforma): bool
    {
        return $user->company_id === $proforma->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }
}
