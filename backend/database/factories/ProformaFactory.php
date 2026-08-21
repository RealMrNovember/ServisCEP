<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Proforma;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Proforma>
 */
class ProformaFactory extends Factory
{
    protected $model = Proforma::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'code' => 'PRO-'.Str::upper(Str::random(6)),
            'customer_id' => Customer::factory(),
            'total_minor' => 0,
        ];
    }
}
