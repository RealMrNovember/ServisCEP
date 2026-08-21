<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Company;
use App\Models\SyncConflict;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<SyncConflict>
 */
class SyncConflictFactory extends Factory
{
    protected $model = SyncConflict::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'company_id' => Company::factory(),
            'user_id' => User::factory(),
            'subject_type' => 'customer',
            'subject_id' => fake()->uuid(),
            'base_version' => 1,
            'server_version' => 2,
            'incoming_payload' => ['notes' => 'mobil hali'],
            'server_snapshot' => ['notes' => 'sunucu hali'],
        ];
    }
}
