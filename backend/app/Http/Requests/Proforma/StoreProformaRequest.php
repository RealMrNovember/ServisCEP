<?php

declare(strict_types=1);

namespace App\Http\Requests\Proforma;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProformaRequest extends FormRequest
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
            'id' => ['sometimes', 'uuid'],
            'code' => ['required', 'string', 'max:50'],
            'customer_id' => [
                'required', 'uuid',
                Rule::exists('customers', 'id')->where(
                    fn ($query) => $query->where('company_id', $this->user()->company_id)
                ),
            ],
            'valid_until' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.id' => ['sometimes', 'uuid'],
            'items.*.description' => ['required', 'string', 'max:255'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit' => ['nullable', 'string', 'max:20'],
            'items.*.unit_price_minor' => ['required', 'integer', 'min:0'],
            'items.*.tax_rate' => ['nullable', 'integer', 'min:0', 'max:100'],
            'items.*.discount_minor' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
