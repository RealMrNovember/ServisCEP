<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Job;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Job
 */
class JobResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'customer_id' => $this->customer_id,
            'job_type_id' => $this->job_type_id,
            'title' => $this->title,
            'description' => $this->description,
            'address' => $this->address,
            'appointment_date' => $this->appointment_date,
            'start_time' => $this->start_time,
            'end_time' => $this->end_time,
            'priority' => $this->priority,
            'status' => $this->status,
            'technician_user_id' => $this->technician_user_id,
            'estimated_price_minor' => $this->estimated_price_minor,
            'actual_price_minor' => $this->actual_price_minor,
            'notes' => $this->notes,
            'version' => $this->version,
            'created_at' => $this->created_at,
        ];
    }
}
