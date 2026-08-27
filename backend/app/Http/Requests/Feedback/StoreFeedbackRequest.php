<?php

declare(strict_types=1);

namespace App\Http\Requests\Feedback;

use App\Models\Feedback;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFeedbackRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'type' => ['sometimes', 'string', Rule::in(Feedback::TYPES)],
            // Alt sınır 5: tek harflik bir gönderim kimseye bir şey
            // anlatmıyor ve panelde gürültü yaratıyor.
            'message' => ['required', 'string', 'min:5', 'max:2000'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'message.required' => 'Bir şeyler yazmadan gönderemezsiniz.',
            'message.min' => 'Biraz daha ayrıntı yazar mısınız?',
            'message.max' => 'Mesaj çok uzun (en fazla 2000 karakter).',
        ];
    }
}
