<?php

declare(strict_types=1);

namespace App\Http\Requests\Payment;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePaymentRequest extends FormRequest
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
            'job_id' => [
                'nullable', 'uuid',
                Rule::exists('jobs', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'amount_minor' => ['required', 'integer', 'min:1'],
            'method' => ['required', 'string', 'max:50'],
            'date' => ['nullable', 'date'],
            'note' => ['nullable', 'string'],
        ];
    }
}
