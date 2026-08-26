<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\JobNote;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin JobNote
 */
class JobNoteResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->job_id,
            'note' => $this->note,
            'created_at' => $this->created_at,
        ];
    }
}
