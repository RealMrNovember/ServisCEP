<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\CustomerLedgerEntry;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin CustomerLedgerEntry
 */
class CustomerLedgerEntryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'customer_id' => $this->customer_id,
            'entry_date' => $this->entry_date,
            'type' => $this->type,
            'amount_minor' => $this->amount_minor,
            'reference_type' => $this->reference_type,
            'reference_id' => $this->reference_id,
            'description' => $this->description,
            'created_at' => $this->created_at,
        ];
    }
}
