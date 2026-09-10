<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Quote;
use App\Models\User;
use App\Support\RolePermissions;

class QuotePolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function view(User $user, Quote $quote): bool
    {
        return $user->company_id === $quote->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function update(User $user, Quote $quote): bool
    {
        return $user->company_id === $quote->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    // NEDEN SONRADAN EKLENDI: delete() tanimli olmadigi icin Filament
    // policy bulamayip VARSAYILAN OLARAK IZIN VERIYORDU; panelin
    // DeleteAction'i HER role aciktı, VIEWER (salt okunur) dahil.
    //
    // Yukaridaki "bilincli olarak delete() yok" notu yalnizca API icin
    // gecerliydi: orada rota hic tanimli degil, dolayisiyla kural
    // gercekten uygulaniyordu. Panelde ise ayni yoklugun tersi anlama
    // geldigi fark edilmemisti. Silme artik yonetme yetkisi istiyor.

    public function delete(User $user, Quote $quote): bool
    {
        return $user->company_id === $quote->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function restore(User $user, Quote $quote): bool
    {
        return $this->delete($user, $quote);
    }

    public function forceDelete(User $user, Quote $quote): bool
    {
        return false;
    }
}
