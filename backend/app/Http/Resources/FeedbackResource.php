<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FeedbackResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'message' => $this->message,
            'status' => $this->status,
            'status_label' => match ($this->status) {
                'YENI' => 'Alındı',
                'INCELENIYOR' => 'İnceleniyor',
                'YANITLANDI' => 'Yanıtlandı',
                'KAPANDI' => 'Kapandı',
                default => $this->status,
            },
            'reply' => $this->reply,
            'replied_at' => $this->replied_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
