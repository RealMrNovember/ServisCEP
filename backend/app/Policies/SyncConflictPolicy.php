<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\SyncConflict;
use App\Models\User;
use App\Support\RolePermissions;

class SyncConflictPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::CONFLICTS_RESOLVE);
    }

    public function resolve(User $user, SyncConflict $syncConflict): bool
    {
        return $user->hasPermission(RolePermissions::CONFLICTS_RESOLVE)
            && $user->company_id === $syncConflict->company_id;
    }
}
