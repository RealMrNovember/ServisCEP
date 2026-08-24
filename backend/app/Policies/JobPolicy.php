<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Job;
use App\Models\User;
use App\Support\RolePermissions;

class JobPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function view(User $user, Job $job): bool
    {
        return $user->company_id === $job->company_id
            && $user->hasPermission(RolePermissions::JOBS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    public function update(User $user, Job $job): bool
    {
        return $user->company_id === $job->company_id
            && $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    // Bilinçli olarak delete() yok — bkz. docs/09 § Veri Silme Prensibi:
    // kritik belgelerde (teklif, proforma, fatura, İŞ dahil) silme yerine
    // İPTAL durumu tercih edilir. Bkz. JobController::update().
}
