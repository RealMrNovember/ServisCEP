<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\ServiceRequest;
use App\Models\User;
use App\Support\RolePermissions;

class ServiceRequestPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function view(User $user, ServiceRequest $serviceRequest): bool
    {
        return $user->company_id === $serviceRequest->company_id
            && $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    public function update(User $user, ServiceRequest $serviceRequest): bool
    {
        return $user->company_id === $serviceRequest->company_id
            && $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }
}
