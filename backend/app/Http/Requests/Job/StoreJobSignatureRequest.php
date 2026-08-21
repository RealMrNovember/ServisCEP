<?php

declare(strict_types=1);

namespace App\Http\Requests\Job;

use Illuminate\Foundation\Http\FormRequest;

class StoreJobSignatureRequest extends FormRequest
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
            'signer_name' => ['required', 'string', 'max:255'],
            'file' => ['required', 'file', 'image', 'mimes:png,jpg,jpeg', 'max:2048'],
        ];
    }
}
