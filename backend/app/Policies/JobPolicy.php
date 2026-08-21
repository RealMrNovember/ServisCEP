<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Job;
use App\Models\User;

class JobPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Job $job): bool
    {
        return $user->company_id === $job->company_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, Job $job): bool
    {
        return $user->company_id === $job->company_id;
    }

    // Bilinçli olarak delete() yok — bkz. docs/09 § Veri Silme Prensibi:
    // kritik belgelerde (teklif, proforma, fatura, İŞ dahil) silme yerine
    // İPTAL durumu tercih edilir. Bkz. JobController::update().
}
