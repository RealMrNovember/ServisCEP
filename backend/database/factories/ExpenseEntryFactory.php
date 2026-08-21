<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\ExpenseEntry;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ExpenseEntry>
 */
class ExpenseEntryFactory extends Factory
{
    protected $model = ExpenseEntry::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'description' => fake()->sentence(3),
            'category' => 'Malzeme',
            'amount_minor' => fake()->numberBetween(1000, 500000),
            'method' => 'Nakit',
        ];
    }
}
