<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\SyncConflict;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin SyncConflict
 */
class SyncConflictResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'subject_type' => $this->subject_type,
            'subject_id' => $this->subject_id,
            'base_version' => $this->base_version,
            'server_version' => $this->server_version,
            'incoming_payload' => $this->incoming_payload,
            'server_snapshot' => $this->server_snapshot,
            'resolution' => $this->resolution,
            'resolved_at' => $this->resolved_at,
            'created_at' => $this->created_at,
        ];
    }
}
