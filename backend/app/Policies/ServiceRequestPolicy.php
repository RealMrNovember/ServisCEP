<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\ServiceRequest;
use App\Models\User;

class ServiceRequestPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, ServiceRequest $serviceRequest): bool
    {
        return $user->company_id === $serviceRequest->company_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, ServiceRequest $serviceRequest): bool
    {
        return $user->company_id === $serviceRequest->company_id;
    }
}
