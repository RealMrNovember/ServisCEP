<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\SyncConflict;
use App\Models\User;

class SyncConflictPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->role === 'OWNER';
    }

    public function resolve(User $user, SyncConflict $syncConflict): bool
    {
        return $user->role === 'OWNER' && $user->company_id === $syncConflict->company_id;
    }
}
