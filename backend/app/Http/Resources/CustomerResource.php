<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Customer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\URL;

/**
 * @mixin Customer
 */
class CustomerResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'contact_name' => $this->contact_name,
            'company_name' => $this->company_name,
            'display_name' => $this->display_name,
            'type' => $this->type,
            'phone' => $this->phone,
            'email' => $this->email,
            'iban' => $this->iban,
            'address' => $this->address,
            'il' => $this->il,
            'ilce' => $this->ilce,
            'tax_info' => $this->tax_info,
            // Dosya yolu asla ham olarak ifşa edilmez — erişim yalnızca
            // kimlik doğrulamalı indirme veya süreli imzalı link üzerinden
            // (bkz. docs/09 § Dosya Güvenliği, JobPhotoResource ile aynı kalıp).
            'has_tax_certificate' => (bool) $this->tax_certificate_path,
            'tax_certificate_download_url' => $this->when(
                (bool) $this->tax_certificate_path,
                fn () => route('api.v1.customers.tax-certificate.download', ['customer' => $this->id])
            ),
            'tax_certificate_signed_url' => $this->when(
                (bool) $this->tax_certificate_path,
                fn () => URL::temporarySignedRoute(
                    'api.v1.files.tax-certificates.show',
                    now()->addMinutes(30),
                    ['customer' => $this->id]
                )
            ),
            'has_logo' => (bool) $this->logo_path,
            'logo_download_url' => $this->when(
                (bool) $this->logo_path,
                fn () => route('api.v1.customers.logo.show', ['customer' => $this->id])
            ),
            'notes' => $this->notes,
            'tags' => $this->tags,
            'version' => $this->version,
            'created_at' => $this->created_at,
        ];
    }
}
