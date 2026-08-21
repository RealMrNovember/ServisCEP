<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\URL;

/**
 * Dosyanın kendisi asla doğrudan public bir yoldan (`file_path`) ifşa
 * edilmez — bkz. docs/09 § Dosya Güvenliği. Erişim ya kimliği
 * doğrulanmış `download_url` üzerinden (Sanctum) ya da süreli,
 * imzalı `signed_url` üzerinden sağlanır.
 *
 * @mixin \App\Models\JobPhoto
 */
class JobPhotoResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->job_id,
            'category' => $this->category,
            'download_url' => route('api.v1.jobs.photos.download', ['job' => $this->job_id, 'photo' => $this->id]),
            'signed_url' => URL::temporarySignedRoute(
                'api.v1.files.photos.show',
                now()->addMinutes(30),
                ['photo' => $this->id]
            ),
            'created_at' => $this->created_at,
        ];
    }
}
