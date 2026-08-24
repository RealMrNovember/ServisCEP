<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\User;
use App\Support\RolePermissions;

class AuditLogPolicy
{
    public function viewAuditLogs(User $user): bool
    {
        return $user->hasPermission(RolePermissions::AUDIT_VIEW);
    }
}
