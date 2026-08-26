<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\PaymentRequest;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin PaymentRequest
 */
class PaymentRequestResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'plan' => $this->whenLoaded('plan', fn () => [
                'id' => $this->plan->id,
                'name' => $this->plan->name,
            ]),
            'approved_plan' => $this->whenLoaded('approvedPlan', fn () => $this->approvedPlan ? [
                'id' => $this->approvedPlan->id,
                'name' => $this->approvedPlan->name,
            ] : null),
            'requested_duration' => $this->requested_duration,
            'approved_duration' => $this->approved_duration,
            'claimed_amount_minor' => $this->claimed_amount_minor,
            'customer_note' => $this->customer_note,
            'admin_note' => $this->admin_note,
            'created_at' => $this->created_at,
            'reviewed_at' => $this->reviewed_at,
        ];
    }
}
