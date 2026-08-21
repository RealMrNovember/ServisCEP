<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\Customer;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Customer>
 */
class CustomerFactory extends Factory
{
    protected $model = Customer::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'code' => 'M-'.Str::upper(Str::random(6)),
            'contact_name' => fake()->name(),
            'type' => 'BIREYSEL',
            'phone' => fake()->numerify('5#########'),
            'email' => fake()->safeEmail(),
        ];
    }
}
