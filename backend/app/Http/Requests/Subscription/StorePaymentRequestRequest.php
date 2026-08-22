<?php

declare(strict_types=1);

namespace App\Http\Requests\Subscription;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePaymentRequestRequest extends FormRequest
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
            'plan_id' => [
                'required', 'uuid',
                Rule::exists('plans', 'id')->where('is_active', true),
            ],
            'billing_period' => ['required', 'string', 'in:MONTHLY,YEARLY'],
            'claimed_amount_minor' => ['nullable', 'integer', 'min:0'],
            'customer_note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
