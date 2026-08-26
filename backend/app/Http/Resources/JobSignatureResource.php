<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\JobSignature;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\URL;

/**
 * @mixin JobSignature
 */
class JobSignatureResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->job_id,
            'signer_name' => $this->signer_name,
            'download_url' => route('api.v1.jobs.signatures.download', ['job' => $this->job_id, 'signature' => $this->id]),
            'signed_url' => URL::temporarySignedRoute(
                'api.v1.files.signatures.show',
                now()->addMinutes(30),
                ['signatureId' => $this->id]
            ),
            'created_at' => $this->created_at,
        ];
    }
}
