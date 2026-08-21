<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Proforma;
use App\Models\User;

class ProformaPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Proforma $proforma): bool
    {
        return $user->company_id === $proforma->company_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, Proforma $proforma): bool
    {
        return $user->company_id === $proforma->company_id;
    }
}
