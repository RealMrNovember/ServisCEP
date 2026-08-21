<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Customer;
use App\Models\User;

/**
 * MVP'de tek rol (OWNER) olduğu için bu politika şimdilik yalnızca
 * `company_id` eşleşmesini doğrular — asıl izolasyon zaten
 * `BelongsToCompany` global scope'u tarafından sorgu seviyesinde
 * uygulanır (bkz. Concerns/BelongsToCompany.php). Politika, V2'de rol
 * bazlı yetkilendirme (bkz. docs/09) genişleyince buraya eklenecek
 * kontroller için hazır bir yer ve ek bir savunma katmanı sağlar.
 */
class CustomerPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id;
    }

    public function delete(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id;
    }

    /**
     * Cari hesap manuel düzeltmesi hassas bir işlemdir — yalnızca OWNER
     * (ileride ACCOUNTING) yapabilir (bkz. docs/15 § API).
     */
    public function recordLedgerAdjustment(User $user, Customer $customer): bool
    {
        return $user->company_id === $customer->company_id && $user->role === 'OWNER';
    }
}
