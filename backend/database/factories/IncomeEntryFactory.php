<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\IncomeEntry;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<IncomeEntry>
 */
class IncomeEntryFactory extends Factory
{
    protected $model = IncomeEntry::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'description' => fake()->sentence(3),
            'category' => 'Servis',
            'amount_minor' => fake()->numberBetween(1000, 500000),
            'method' => 'Nakit',
        ];
    }
}
