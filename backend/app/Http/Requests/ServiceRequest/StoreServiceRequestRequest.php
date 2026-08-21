<?php

declare(strict_types=1);

namespace App\Http\Requests\ServiceRequest;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreServiceRequestRequest extends FormRequest
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
            'code' => ['required', 'string', 'max:50'],
            'customer_id' => [
                'required', 'uuid',
                Rule::exists('customers', 'id')->where(
                    fn ($query) => $query->where('company_id', $this->user()->company_id)
                ),
            ],
            'description' => ['required', 'string'],
            'priority' => ['required', 'string', 'in:YUKSEK,NORMAL,DUSUK'],
            'address' => ['nullable', 'string'],
        ];
    }
}
