<?php

declare(strict_types=1);

namespace App\Http\Requests\ServiceRequest;

use Illuminate\Foundation\Http\FormRequest;

class UpdateServiceRequestRequest extends FormRequest
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
            'description' => ['sometimes', 'string'],
            'priority' => ['sometimes', 'string', 'in:YUKSEK,NORMAL,DUSUK'],
            'address' => ['sometimes', 'nullable', 'string'],
            // ISE_DONUSTU yalnızca /convert endpoint'i üzerinden, sunucu
            // tarafında set edilir — bkz. docs/02 § Talep → İş Dönüşümü.
            'status' => ['sometimes', 'string', 'in:BEKLIYOR,ISLEME_ALINDI,REDDEDILDI'],
        ];
    }
}
