<?php

declare(strict_types=1);

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Manuel cari hesap düzeltmesi — hassas bir işlem, gerekçe (description)
 * zorunlu (bkz. docs/15 § API).
 */
class StoreLedgerAdjustmentRequest extends FormRequest
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
            'type' => ['required', 'string', 'in:DEBIT,CREDIT'],
            'amount_minor' => ['required', 'integer', 'min:1'],
            'description' => ['required', 'string', 'max:500'],
        ];
    }
}
