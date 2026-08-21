<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\ExpenseEntry
 */
class ExpenseEntryResource extends JsonResource
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
            'category' => $this->category,
            'amount_minor' => $this->amount_minor,
            'vendor_name' => $this->vendor_name,
            'method' => $this->method,
            'note' => $this->note,
        ];
    }
}
