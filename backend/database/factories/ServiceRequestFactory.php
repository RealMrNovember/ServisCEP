<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\Customer;
use App\Models\ServiceRequest;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<ServiceRequest>
 */
class ServiceRequestFactory extends Factory
{
    protected $model = ServiceRequest::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'code' => 'T-'.Str::upper(Str::random(6)),
            'customer_id' => Customer::factory(),
            'description' => fake()->sentence(),
            'priority' => 'NORMAL',
            'status' => 'BEKLIYOR',
        ];
    }
}
