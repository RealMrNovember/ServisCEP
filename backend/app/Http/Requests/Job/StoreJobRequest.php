<?php

declare(strict_types=1);

namespace App\Http\Requests\Job;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreJobRequest extends FormRequest
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
            'code' => ['required', 'string', 'max:50'],
            'customer_id' => [
                'required', 'uuid',
                Rule::exists('customers', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'job_type_id' => [
                'nullable', 'uuid',
                Rule::exists('job_types', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'address' => ['nullable', 'string'],
            'appointment_date' => ['nullable', 'date'],
            'start_time' => ['nullable', 'string', 'max:10'],
            'end_time' => ['nullable', 'string', 'max:10'],
            'priority' => ['required', 'string', 'in:YUKSEK,NORMAL,DUSUK'],
            'status' => ['required', 'string', 'in:TALEP,PLANLANDI,DEVAM_EDIYOR,BEKLEMEDE,TAMAMLANDI,IPTAL'],
            'estimated_price_minor' => ['nullable', 'integer', 'min:0'],
            'actual_price_minor' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string'],
        ];
    }
}
