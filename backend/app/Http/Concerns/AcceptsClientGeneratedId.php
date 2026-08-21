<?php

declare(strict_types=1);

namespace App\Http\Concerns;

use Illuminate\Database\Eloquent\Model;

/**
 * Mobil, offline oluşturduğu kayıtları senkronize ederken kendi
 * ürettiği UUID'yi korumalıdır — aksi halde ilişkili kayıtlar (ör.
 * job.customer_id) sunucuda farklı bir ID'ye referans vermiş olur ve
 * senkron sonrası ilişkiler kopar. Aynı ID ile tekrar gelen bir
 * create isteği (ör. ağ kesintisi sonrası retry) hataya değil, var
 * olan kaydı döndürerek (idempotent) karşılanır. Bkz. ROADMAP.md § B10.
 */
trait AcceptsClientGeneratedId
{
    private function findExistingByClientId(string $modelClass, ?string $id): ?Model
    {
        if (blank($id)) {
            return null;
        }

        return $modelClass::find($id);
    }
}
