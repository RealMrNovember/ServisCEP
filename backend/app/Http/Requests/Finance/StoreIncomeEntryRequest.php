<?php

declare(strict_types=1);

namespace App\Http\Requests\Finance;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreIncomeEntryRequest extends FormRequest
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
            'date' => ['nullable', 'date'],
            'description' => ['required', 'string', 'max:255'],
            'customer_id' => [
                'nullable', 'uuid',
                Rule::exists('customers', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'job_id' => [
                'nullable', 'uuid',
                Rule::exists('jobs', 'id')->where(fn ($query) => $query->where('company_id', $companyId)),
            ],
            'category' => ['required', 'string', 'in:Servis,Malzeme,Montaj,Bakım,Danışmanlık,Diğer'],
            'amount_minor' => ['required', 'integer', 'min:1'],
            'method' => ['required', 'string', 'max:50'],
            'note' => ['nullable', 'string'],
        ];
    }
}
