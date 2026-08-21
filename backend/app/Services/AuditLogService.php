<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;

/**
 * Bkz. docs/09 § 5 Audit Log. Audit log gerektiren kritik işlemler:
 * belge oluşturma/silme, tahsilat, müşteri değişikliği, yetki
 * değişikliği, firma ayarı değişikliği.
 */
class AuditLogService
{
    public function record(User $user, string $action, string $subjectType, ?string $subjectId, string $description, array $meta = []): AuditLog
    {
        return AuditLog::create([
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'description' => $description,
            'meta' => $meta,
        ])->refresh();
    }
}
