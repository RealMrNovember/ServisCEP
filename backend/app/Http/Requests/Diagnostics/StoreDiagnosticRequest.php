<?php

declare(strict_types=1);

namespace App\Http\Requests\Diagnostics;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Mobil tanılama kaydının doğrulaması.
 *
 * Uç kimlik doğrulaması istemediği için sınırlar burada dar tutulur:
 * her alanın uzunluğu sabit, seviye kapalı bir listeden. Amaç, bu ucun
 * serbest bir veri deposuna dönüşmesini engellemek.
 */
class StoreDiagnosticRequest extends FormRequest
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
            'level' => ['sometimes', 'string', 'in:info,warning,error,critical'],
            'message' => ['required', 'string', 'max:250'],
            // Yığın izi / istisna ayrıntısı.
            'detail' => ['sometimes', 'nullable', 'string', 'max:4000'],
            'screen' => ['sometimes', 'nullable', 'string', 'max:100'],
            'platform' => ['sometimes', 'string', 'max:20'],
            'app_version' => ['sometimes', 'nullable', 'string', 'max:30'],
            'os_version' => ['sometimes', 'nullable', 'string', 'max:60'],
            'device' => ['sometimes', 'nullable', 'string', 'max:120'],
            // 'wifi' / 'mobile' / 'none' — "internet yok mu gerçekten"
            // sorusunun cevabı bu alanda.
            'connectivity' => ['sometimes', 'nullable', 'string', 'max:20'],
            'occurred_at' => ['sometimes', 'nullable', 'date'],
        ];
    }
}
