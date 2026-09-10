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

    // NEDEN SONRADAN EKLENDI: delete() tanimli olmadigi icin Filament
    // policy bulamayip VARSAYILAN OLARAK IZIN VERIYORDU; panelin
    // DeleteAction'i HER role aciktı, VIEWER (salt okunur) dahil.
    //
    // Yukaridaki "bilincli olarak delete() yok" notu yalnizca API icin
    // gecerliydi: orada rota hic tanimli degil, dolayisiyla kural
    // gercekten uygulaniyordu. Panelde ise ayni yoklugun tersi anlama
    // geldigi fark edilmemisti. Silme artik yonetme yetkisi istiyor.

    public function delete(User $user, Job $job): bool
    {
        return $user->company_id === $job->company_id
            && $user->hasPermission(RolePermissions::JOBS_MANAGE);
    }

    public function restore(User $user, Job $job): bool
    {
        return $this->delete($user, $job);
    }

    public function forceDelete(User $user, Job $job): bool
    {
        return false;
    }
}
