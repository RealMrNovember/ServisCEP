<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\SyncConflict;
use App\Models\User;

class SyncConflictService
{
    /**
     * @param  array<string, mixed>  $incomingPayload
     * @param  array<string, mixed>  $serverSnapshot
     */
    public function record(
        User $user,
        string $subjectType,
        string $subjectId,
        int $baseVersion,
        int $serverVersion,
        array $incomingPayload,
        array $serverSnapshot,
    ): SyncConflict {
        return SyncConflict::create([
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'base_version' => $baseVersion,
            'server_version' => $serverVersion,
            'incoming_payload' => $incomingPayload,
            'server_snapshot' => $serverSnapshot,
        ])->refresh();
    }
}
