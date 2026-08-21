<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\IncomeEntry
 */
class IncomeEntryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'date' => $this->date,
            'description' => $this->description,
            'customer_id' => $this->customer_id,
            'job_id' => $this->job_id,
            'category' => $this->category,
            'amount_minor' => $this->amount_minor,
            'method' => $this->method,
            'note' => $this->note,
        ];
    }
}
