<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Product;
use App\Models\User;
use App\Support\RolePermissions;

/**
 * Ürün/stok kataloğu yetkisi.
 *
 * NEDEN VAR: politika yokken Filament varsayılan olarak izin veriyordu —
 * VIEWER (salt okunur) rolündeki bir kullanıcı bile `/panel/products`
 * üzerinden katalogu değiştirip silebiliyordu.
 *
 * Yetki seçimi: ürün fiyatı tekliflere kalem olarak giriyor, yani
 * katalogu değiştirmek belge tutarını değiştirmekle aynı kapıya çıkıyor.
 * Bu yüzden yeni bir yetki uydurmak yerine DOCUMENTS_* kullanılıyor:
 * görmek herkese açık (teknisyen sahada parça arıyor), değiştirmek
 * belge yetkisi olanlara.
 */
class ProductPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function view(User $user, Product $product): bool
    {
        return $user->company_id === $product->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_VIEW);
    }

    public function create(User $user): bool
    {
        return $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function update(User $user, Product $product): bool
    {
        return $user->company_id === $product->company_id
            && $user->hasPermission(RolePermissions::DOCUMENTS_MANAGE);
    }

    public function delete(User $user, Product $product): bool
    {
        return $this->update($user, $product);
    }

    public function restore(User $user, Product $product): bool
    {
        return $this->update($user, $product);
    }

    public function forceDelete(User $user, Product $product): bool
    {
        return false;
    }
}
