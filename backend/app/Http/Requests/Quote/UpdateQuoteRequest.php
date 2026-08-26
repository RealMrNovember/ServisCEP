<?php

declare(strict_types=1);

namespace App\Http\Requests\Quote;

use Illuminate\Foundation\Http\FormRequest;

class UpdateQuoteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'intro_text' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'payment_terms' => ['sometimes', 'nullable', 'string', 'max:255'],
            'delivery_time' => ['sometimes', 'nullable', 'string', 'max:255'],
            'warranty_terms' => ['sometimes', 'nullable', 'string', 'max:255'],
            'currency' => ['sometimes', 'string', 'in:TRY,USD,EUR'],
            'vat_mode' => ['sometimes', 'string', 'in:EXCLUDED,INCLUDED'],
            'vat_rate' => ['sometimes', 'integer', 'min:0', 'max:100'],
            'valid_until' => ['sometimes', 'nullable', 'date'],
            'base_version' => ['required', 'integer', 'min:1'],

            // İstemcinin GERÇEKTEN değiştirdiği alanlar. Yük kaydın
            // tamamını taşıdığı için bu bilgi yükten çıkarılamıyor; onsuz
            // her sürüm uyuşmazlığı elle çözülmesi gereken bir çakışma
            // sayılırdı (bkz. DetectsSyncConflicts).
            //
            // `sometimes`: eski uygulama sürümleri bunu göndermiyor ve
            // göndermedikleri sürece eski davranışı görüyorlar.
            'changed_fields' => ['sometimes', 'array'],
            'changed_fields.*' => ['string', 'max:64'],
            'status' => ['sometimes', 'string', 'in:TASLAK,GONDERILDI,BEKLEMEDE,KABUL_EDILDI,REDDEDILDI,SURESI_DOLDU'],
            'notes' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
