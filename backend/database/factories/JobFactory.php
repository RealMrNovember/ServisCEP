<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Job;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Job>
 */
class JobFactory extends Factory
{
    protected $model = Job::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'code' => 'J-'.Str::upper(Str::random(6)),
            'customer_id' => Customer::factory(),
            'title' => fake()->sentence(4),
            'priority' => 'NORMAL',
            'status' => 'TALEP',
        ];
    }
}
