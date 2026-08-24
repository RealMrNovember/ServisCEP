<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Customer;
use App\Models\User;
use App\Support\RolePermissions;

/**
 * İki katmanlı savunma: şirket izolasyonu (`company_id`) + rol yetkisi.
 *
 * Şirket izolasyonu zaten `BelongsToCompany` global scope'u tarafından
 * sorgu seviyesinde uygulanır; buradaki kontrol ikinci katmandır.
 * Rol yetkileri tek kaynaktan gelir: RolePermissions (bkz. docs/09 § 1).
 */
class CustomerPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::CUSTOMERS_VIEW);
    }

    public function view(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id
            && $user->hasPermission(RolePermissions::CUSTOMERS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::CUSTOMERS_MANAGE);
    }

    public function update(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id
            && $user->hasPermission(RolePermissions::CUSTOMERS_MANAGE);
    }

    public function delete(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id
            && $user->hasPermission(RolePermissions::CUSTOMERS_DELETE);
    }

    /**
     * Cari hesap manuel düzeltmesi hassas bir işlemdir — yalnızca OWNER
     * (ileride ACCOUNTING) yapabilir (bkz. docs/15 § API).
     */
    public function recordLedgerAdjustment(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id
            && $user->hasPermission(RolePermissions::LEDGER_ADJUST);
    }
}
