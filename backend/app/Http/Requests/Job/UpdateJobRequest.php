<?php

declare(strict_types=1);

namespace App\Http\Requests\Job;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateJobRequest extends FormRequest
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
        $companyId = $this->user()->company_id;

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
            'customer_id' => [
                'sometimes', 'uuid',
                Rule::exists('customers', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'job_type_id' => [
                'sometimes', 'nullable', 'uuid',
                Rule::exists('job_types', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'title' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'address' => ['sometimes', 'nullable', 'string'],
            'appointment_date' => ['sometimes', 'nullable', 'date'],
            'start_time' => ['sometimes', 'nullable', 'string', 'max:10'],
            'end_time' => ['sometimes', 'nullable', 'string', 'max:10'],
            'priority' => ['sometimes', 'string', 'in:YUKSEK,NORMAL,DUSUK'],
            'status' => ['sometimes', 'string', 'in:TALEP,PLANLANDI,DEVAM_EDIYOR,BEKLEMEDE,TAMAMLANDI,IPTAL'],
            'estimated_price_minor' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'actual_price_minor' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'notes' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
