<?php

declare(strict_types=1);

namespace App\Http\Requests\SyncConflict;

use Illuminate\Foundation\Http\FormRequest;

class ResolveSyncConflictRequest extends FormRequest
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
            'resolution' => ['required', 'string', 'in:SUNUCU_TUTULDU,MOBIL_TUTULDU'],
        ];
    }
}
